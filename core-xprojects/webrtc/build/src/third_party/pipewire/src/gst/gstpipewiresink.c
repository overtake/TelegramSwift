/* GStreamer
 *
 * Copyright © 2018 Wim Taymans
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/**
 * SECTION:element-pipewiresink
 *
 * <refsect2>
 * <title>Example launch line</title>
 * |[
 * gst-launch -v videotestsrc ! pipewiresink
 * ]| Sends a test video source to PipeWire
 * </refsect2>
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "gstpipewiresink.h"

#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>

#include <spa/pod/builder.h>
#include <spa/utils/result.h>

#include <gst/video/video.h>

#include "gstpipewireformat.h"

GST_DEBUG_CATEGORY_STATIC (pipewire_sink_debug);
#define GST_CAT_DEFAULT pipewire_sink_debug

#define DEFAULT_PROP_MODE GST_PIPEWIRE_SINK_MODE_DEFAULT

#define MIN_BUFFERS     8u

enum
{
  PROP_0,
  PROP_PATH,
  PROP_CLIENT_NAME,
  PROP_STREAM_PROPERTIES,
  PROP_MODE,
  PROP_FD
};

GType
gst_pipewire_sink_mode_get_type (void)
{
  static gsize mode_type = 0;
  static const GEnumValue mode[] = {
    {GST_PIPEWIRE_SINK_MODE_DEFAULT, "GST_PIPEWIRE_SINK_MODE_DEFAULT", "default"},
    {GST_PIPEWIRE_SINK_MODE_RENDER, "GST_PIPEWIRE_SINK_MODE_RENDER", "render"},
    {GST_PIPEWIRE_SINK_MODE_PROVIDE, "GST_PIPEWIRE_SINK_MODE_PROVIDE", "provide"},
    {0, NULL, NULL},
  };

  if (g_once_init_enter (&mode_type)) {
    GType tmp =
        g_enum_register_static ("GstPipeWireSinkMode", mode);
    g_once_init_leave (&mode_type, tmp);
  }

  return (GType) mode_type;
}


static GstStaticPadTemplate gst_pipewire_sink_template =
GST_STATIC_PAD_TEMPLATE ("sink",
    GST_PAD_SINK,
    GST_PAD_ALWAYS,
    GST_STATIC_CAPS_ANY
    );

#define gst_pipewire_sink_parent_class parent_class
G_DEFINE_TYPE (GstPipeWireSink, gst_pipewire_sink, GST_TYPE_BASE_SINK);

static void gst_pipewire_sink_set_property (GObject * object, guint prop_id,
    const GValue * value, GParamSpec * pspec);
static void gst_pipewire_sink_get_property (GObject * object, guint prop_id,
    GValue * value, GParamSpec * pspec);

static GstStateChangeReturn
gst_pipewire_sink_change_state (GstElement * element, GstStateChange transition);

static gboolean gst_pipewire_sink_setcaps (GstBaseSink * bsink, GstCaps * caps);
static GstCaps *gst_pipewire_sink_sink_fixate (GstBaseSink * bsink,
    GstCaps * caps);

static GstFlowReturn gst_pipewire_sink_render (GstBaseSink * psink,
    GstBuffer * buffer);
static gboolean gst_pipewire_sink_start (GstBaseSink * basesink);
static gboolean gst_pipewire_sink_stop (GstBaseSink * basesink);

static void
gst_pipewire_sink_finalize (GObject * object)
{
  GstPipeWireSink *pwsink = GST_PIPEWIRE_SINK (object);

  g_object_unref (pwsink->pool);

  if (pwsink->properties)
    gst_structure_free (pwsink->properties);
  g_free (pwsink->path);
  g_free (pwsink->client_name);

  G_OBJECT_CLASS (parent_class)->finalize (object);
}

static gboolean
gst_pipewire_sink_propose_allocation (GstBaseSink * bsink, GstQuery * query)
{
  GstPipeWireSink *pwsink = GST_PIPEWIRE_SINK (bsink);

  gst_query_add_allocation_pool (query, GST_BUFFER_POOL_CAST (pwsink->pool), 0, 0, 0);
  return TRUE;
}

static void
gst_pipewire_sink_class_init (GstPipeWireSinkClass * klass)
{
  GObjectClass *gobject_class;
  GstElementClass *gstelement_class;
  GstBaseSinkClass *gstbasesink_class;

  gobject_class = (GObjectClass *) klass;
  gstelement_class = (GstElementClass *) klass;
  gstbasesink_class = (GstBaseSinkClass *) klass;

  gobject_class->finalize = gst_pipewire_sink_finalize;
  gobject_class->set_property = gst_pipewire_sink_set_property;
  gobject_class->get_property = gst_pipewire_sink_get_property;

  g_object_class_install_property (gobject_class,
                                   PROP_PATH,
                                   g_param_spec_string ("path",
                                                        "Path",
                                                        "The sink path to connect to (NULL = default)",
                                                        NULL,
                                                        G_PARAM_READWRITE |
                                                        G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (gobject_class,
                                   PROP_CLIENT_NAME,
                                   g_param_spec_string ("client-name",
                                                        "Client Name",
                                                        "The client name to use (NULL = default)",
                                                        NULL,
                                                        G_PARAM_READWRITE |
                                                        G_PARAM_STATIC_STRINGS));

   g_object_class_install_property (gobject_class,
                                    PROP_STREAM_PROPERTIES,
                                    g_param_spec_boxed ("stream-properties",
                                                        "Stream properties",
                                                        "List of PipeWire stream properties",
                                                        GST_TYPE_STRUCTURE,
                                                        G_PARAM_READWRITE |
                                                        G_PARAM_STATIC_STRINGS));

   g_object_class_install_property (gobject_class,
                                    PROP_MODE,
                                    g_param_spec_enum ("mode",
                                                       "Mode",
                                                       "The mode to operate in",
                                                        GST_TYPE_PIPEWIRE_SINK_MODE,
                                                        DEFAULT_PROP_MODE,
                                                        G_PARAM_READWRITE |
                                                        G_PARAM_STATIC_STRINGS));

   g_object_class_install_property (gobject_class,
                                    PROP_FD,
                                    g_param_spec_int ("fd",
                                                      "Fd",
                                                      "The fd to connect with",
                                                      -1, G_MAXINT, -1,
                                                      G_PARAM_READWRITE |
                                                      G_PARAM_STATIC_STRINGS));

  gstelement_class->change_state = gst_pipewire_sink_change_state;

  gst_element_class_set_static_metadata (gstelement_class,
      "PipeWire sink", "Sink/Video",
      "Send video to PipeWire", "Wim Taymans <wim.taymans@gmail.com>");

  gst_element_class_add_pad_template (gstelement_class,
      gst_static_pad_template_get (&gst_pipewire_sink_template));

  gstbasesink_class->set_caps = gst_pipewire_sink_setcaps;
  gstbasesink_class->fixate = gst_pipewire_sink_sink_fixate;
  gstbasesink_class->propose_allocation = gst_pipewire_sink_propose_allocation;
  gstbasesink_class->start = gst_pipewire_sink_start;
  gstbasesink_class->stop = gst_pipewire_sink_stop;
  gstbasesink_class->render = gst_pipewire_sink_render;

  GST_DEBUG_CATEGORY_INIT (pipewire_sink_debug, "pipewiresink", 0,
      "PipeWire Sink");
}

static void
pool_activated (GstPipeWirePool *pool, GstPipeWireSink *sink)
{
  GstStructure *config;
  GstCaps *caps;
  guint size;
  guint min_buffers;
  guint max_buffers;
  const struct spa_pod *port_params[3];
  struct spa_pod_builder b = { NULL };
  uint8_t buffer[1024];
  struct spa_pod_frame f;

  config = gst_buffer_pool_get_config (GST_BUFFER_POOL (pool));
  gst_buffer_pool_config_get_params (config, &caps, &size, &min_buffers, &max_buffers);

  spa_pod_builder_init (&b, buffer, sizeof (buffer));
  spa_pod_builder_push_object (&b, &f, SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers);
  if (size == 0)
    spa_pod_builder_add (&b,
        SPA_PARAM_BUFFERS_size, SPA_POD_CHOICE_RANGE_Int(0, 0, INT32_MAX),
        0);
  else
    spa_pod_builder_add (&b,
        SPA_PARAM_BUFFERS_size, SPA_POD_CHOICE_RANGE_Int(size, size, INT32_MAX),
        0);

  spa_pod_builder_add (&b,
      SPA_PARAM_BUFFERS_stride,  SPA_POD_CHOICE_RANGE_Int(0, 0, INT32_MAX),
      SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(
	      SPA_MAX(MIN_BUFFERS, min_buffers),
	      SPA_MAX(MIN_BUFFERS, min_buffers),
	      max_buffers ? max_buffers : INT32_MAX),
      SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16),
      SPA_PARAM_BUFFERS_dataType, SPA_POD_CHOICE_FLAGS_Int(
						(1<<SPA_DATA_DmaBuf) |
						(1<<SPA_DATA_MemFd) |
						(1<<SPA_DATA_MemPtr)),
      0);
  port_params[0] = spa_pod_builder_pop (&b, &f);

  port_params[1] = spa_pod_builder_add_object (&b,
      SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
      SPA_PARAM_META_type, SPA_POD_Int(SPA_META_Header),
      SPA_PARAM_META_size, SPA_POD_Int(sizeof (struct spa_meta_header)));

  port_params[2] = spa_pod_builder_add_object (&b,
      SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
      SPA_PARAM_META_type, SPA_POD_Int(SPA_META_VideoCrop),
      SPA_PARAM_META_size, SPA_POD_Int(sizeof (struct spa_meta_region)));

  pw_thread_loop_lock (sink->core->loop);
  pw_stream_update_params (sink->stream, port_params, 3);
  pw_thread_loop_unlock (sink->core->loop);
}

static void
gst_pipewire_sink_init (GstPipeWireSink * sink)
{
  sink->pool =  gst_pipewire_pool_new ();
  sink->client_name = g_strdup(pw_get_client_name());
  sink->mode = DEFAULT_PROP_MODE;
  sink->fd = -1;

  g_signal_connect (sink->pool, "activated", G_CALLBACK (pool_activated), sink);
}

static GstCaps *
gst_pipewire_sink_sink_fixate (GstBaseSink * bsink, GstCaps * caps)
{
  GstStructure *structure;

  caps = gst_caps_make_writable (caps);

  structure = gst_caps_get_structure (caps, 0);

  if (gst_structure_has_name (structure, "video/x-raw")) {
    gst_structure_fixate_field_nearest_int (structure, "width", 320);
    gst_structure_fixate_field_nearest_int (structure, "height", 240);
    gst_structure_fixate_field_nearest_fraction (structure, "framerate", 30, 1);

    if (gst_structure_has_field (structure, "pixel-aspect-ratio"))
      gst_structure_fixate_field_nearest_fraction (structure,
          "pixel-aspect-ratio", 1, 1);
    else
      gst_structure_set (structure, "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1,
          NULL);

    if (gst_structure_has_field (structure, "colorimetry"))
      gst_structure_fixate_field_string (structure, "colorimetry", "bt601");
    if (gst_structure_has_field (structure, "chroma-site"))
      gst_structure_fixate_field_string (structure, "chroma-site", "mpeg2");

    if (gst_structure_has_field (structure, "interlace-mode"))
      gst_structure_fixate_field_string (structure, "interlace-mode",
          "progressive");
    else
      gst_structure_set (structure, "interlace-mode", G_TYPE_STRING,
          "progressive", NULL);
  } else if (gst_structure_has_name (structure, "audio/x-raw")) {
    gst_structure_fixate_field_string (structure, "format", "S16LE");
    gst_structure_fixate_field_nearest_int (structure, "channels", 2);
    gst_structure_fixate_field_nearest_int (structure, "rate", 44100);
  }

  caps = GST_BASE_SINK_CLASS (parent_class)->fixate (bsink, caps);

  return caps;
}

static void
gst_pipewire_sink_set_property (GObject * object, guint prop_id,
    const GValue * value, GParamSpec * pspec)
{
  GstPipeWireSink *pwsink = GST_PIPEWIRE_SINK (object);

  switch (prop_id) {
    case PROP_PATH:
      g_free (pwsink->path);
      pwsink->path = g_value_dup_string (value);
      break;

    case PROP_CLIENT_NAME:
      g_free (pwsink->client_name);
      pwsink->client_name = g_value_dup_string (value);
      break;

    case PROP_STREAM_PROPERTIES:
      if (pwsink->properties)
        gst_structure_free (pwsink->properties);
      pwsink->properties =
          gst_structure_copy (gst_value_get_structure (value));
      break;

    case PROP_MODE:
      pwsink->mode = g_value_get_enum (value);
      break;

    case PROP_FD:
      pwsink->fd = g_value_get_int (value);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_pipewire_sink_get_property (GObject * object, guint prop_id,
    GValue * value, GParamSpec * pspec)
{
  GstPipeWireSink *pwsink = GST_PIPEWIRE_SINK (object);

  switch (prop_id) {
    case PROP_PATH:
      g_value_set_string (value, pwsink->path);
      break;

    case PROP_CLIENT_NAME:
      g_value_set_string (value, pwsink->client_name);
      break;

    case PROP_STREAM_PROPERTIES:
      gst_value_set_structure (value, pwsink->properties);
      break;

    case PROP_MODE:
      g_value_set_enum (value, pwsink->mode);
      break;

    case PROP_FD:
      g_value_set_int (value, pwsink->fd);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
on_add_buffer (void *_data, struct pw_buffer *b)
{
  GstPipeWireSink *pwsink = _data;
  gst_pipewire_pool_wrap_buffer (pwsink->pool, b);
}

static void
on_remove_buffer (void *_data, struct pw_buffer *b)
{
  GstPipeWireSink *pwsink = _data;
  GstPipeWirePoolData *data = b->user_data;

  GST_LOG_OBJECT (pwsink, "remove buffer");

  gst_buffer_unref (data->buf);
}

static void
do_send_buffer (GstPipeWireSink *pwsink, GstBuffer *buffer)
{
  GstPipeWirePoolData *data;
  gboolean res;
  guint i;
  struct spa_buffer *b;

  data = gst_pipewire_pool_get_data(buffer);

  b = data->b->buffer;

  if (data->header) {
    data->header->seq = GST_BUFFER_OFFSET (buffer);
    data->header->pts = GST_BUFFER_PTS (buffer);
    data->header->dts_offset = GST_BUFFER_DTS (buffer);
  }
  if (data->crop) {
    GstVideoCropMeta *meta = gst_buffer_get_video_crop_meta (buffer);
    if (meta) {
      data->crop->region.position.x = meta->x;
      data->crop->region.position.y = meta->y;
      data->crop->region.size.width = meta->width;
      data->crop->region.size.height = meta->width;
    }
  }
  for (i = 0; i < b->n_datas; i++) {
    struct spa_data *d = &b->datas[i];
    GstMemory *mem = gst_buffer_peek_memory (buffer, i);
    d->chunk->offset = mem->offset - data->offset;
    d->chunk->size = mem->size;
  }

  if ((res = pw_stream_queue_buffer (pwsink->stream, data->b)) < 0) {
    g_warning ("can't send buffer %s", spa_strerror(res));
  }
}


static void
on_process (void *data)
{
  GstPipeWireSink *pwsink = data;
  GST_DEBUG ("signal");
  g_cond_signal (&pwsink->pool->cond);
}

static void
on_state_changed (void *data, enum pw_stream_state old, enum pw_stream_state state, const char *error)
{
  GstPipeWireSink *pwsink = data;

  GST_DEBUG ("got stream state %d", state);

  switch (state) {
    case PW_STREAM_STATE_UNCONNECTED:
    case PW_STREAM_STATE_CONNECTING:
    case PW_STREAM_STATE_PAUSED:
    case PW_STREAM_STATE_STREAMING:
      break;
    case PW_STREAM_STATE_ERROR:
      GST_ELEMENT_ERROR (pwsink, RESOURCE, FAILED,
          ("stream error: %s", error), (NULL));
      break;
  }
  pw_thread_loop_signal (pwsink->core->loop, FALSE);
}

static void
on_param_changed (void *data, uint32_t id, const struct spa_pod *param)
{
  GstPipeWireSink *pwsink = data;

  if (param == NULL || id != SPA_PARAM_Format)
          return;

  if (gst_buffer_pool_is_active (GST_BUFFER_POOL_CAST (pwsink->pool)))
    pool_activated (pwsink->pool, pwsink);
}

static gboolean
gst_pipewire_sink_setcaps (GstBaseSink * bsink, GstCaps * caps)
{
  GstPipeWireSink *pwsink;
  GPtrArray *possible;
  enum pw_stream_state state;
  const char *error = NULL;
  gboolean res = FALSE;
  GstStructure *config;
  guint size;
  guint min_buffers;
  guint max_buffers;

  pwsink = GST_PIPEWIRE_SINK (bsink);

  possible = gst_caps_to_format_all (caps, SPA_PARAM_EnumFormat);

  pw_thread_loop_lock (pwsink->core->loop);
  state = pw_stream_get_state (pwsink->stream, &error);

  if (state == PW_STREAM_STATE_ERROR)
    goto start_error;

  if (state == PW_STREAM_STATE_UNCONNECTED) {
    enum pw_stream_flags flags = 0;

    if (pwsink->mode != GST_PIPEWIRE_SINK_MODE_PROVIDE)
      flags |= PW_STREAM_FLAG_AUTOCONNECT;
    else
      flags |= PW_STREAM_FLAG_DRIVER;

    pw_stream_connect (pwsink->stream,
                          PW_DIRECTION_OUTPUT,
                          pwsink->path ? (uint32_t)atoi(pwsink->path) : PW_ID_ANY,
                          flags,
                          (const struct spa_pod **) possible->pdata,
                          possible->len);

    while (TRUE) {
      state = pw_stream_get_state (pwsink->stream, &error);

      if (state == PW_STREAM_STATE_PAUSED)
        break;

      if (state == PW_STREAM_STATE_ERROR)
        goto start_error;

      pw_thread_loop_wait (pwsink->core->loop);
    }
  }
  res = TRUE;

  config = gst_buffer_pool_get_config (GST_BUFFER_POOL_CAST (pwsink->pool));
  gst_buffer_pool_config_get_params (config, NULL, &size, &min_buffers, &max_buffers);
  gst_buffer_pool_config_set_params (config, caps, size, min_buffers, max_buffers);
  gst_buffer_pool_set_config (GST_BUFFER_POOL_CAST (pwsink->pool), config);

  pw_thread_loop_unlock (pwsink->core->loop);

  pwsink->negotiated = res;

  return res;

start_error:
  {
    GST_ERROR ("could not start stream: %s", error);
    pw_thread_loop_unlock (pwsink->core->loop);
    g_ptr_array_unref (possible);
    return FALSE;
  }
}

static GstFlowReturn
gst_pipewire_sink_render (GstBaseSink * bsink, GstBuffer * buffer)
{
  GstPipeWireSink *pwsink;
  GstFlowReturn res = GST_FLOW_OK;
  const char *error = NULL;

  pwsink = GST_PIPEWIRE_SINK (bsink);

  if (!pwsink->negotiated)
    goto not_negotiated;

  if (buffer->pool != GST_BUFFER_POOL_CAST (pwsink->pool) &&
      !gst_buffer_pool_is_active (GST_BUFFER_POOL_CAST (pwsink->pool))) {
    GstStructure *config;
    GstCaps *caps;
    guint size, min_buffers, max_buffers;

    config = gst_buffer_pool_get_config (GST_BUFFER_POOL_CAST (pwsink->pool));
    gst_buffer_pool_config_get_params (config, &caps, &size, &min_buffers, &max_buffers);

    size = (size == 0) ? gst_buffer_get_size (buffer) : size;

    gst_buffer_pool_config_set_params (config, caps, size, min_buffers, max_buffers);
    gst_buffer_pool_set_config (GST_BUFFER_POOL_CAST (pwsink->pool), config);

    gst_buffer_pool_set_active (GST_BUFFER_POOL_CAST (pwsink->pool), TRUE);
  }

  pw_thread_loop_lock (pwsink->core->loop);
  if (pw_stream_get_state (pwsink->stream, &error) != PW_STREAM_STATE_STREAMING)
    goto done_unlock;

  if (buffer->pool != GST_BUFFER_POOL_CAST (pwsink->pool)) {
    GstBuffer *b = NULL;
    GstMapInfo info = { 0, };
    GstBufferPoolAcquireParams params = { 0, };

    pw_thread_loop_unlock (pwsink->core->loop);

    if ((res = gst_buffer_pool_acquire_buffer (GST_BUFFER_POOL_CAST (pwsink->pool), &b, &params)) != GST_FLOW_OK)
      goto done;

    gst_buffer_map (b, &info, GST_MAP_WRITE);
    gst_buffer_extract (buffer, 0, info.data, info.size);
    gst_buffer_unmap (b, &info);
    gst_buffer_resize (b, 0, gst_buffer_get_size (buffer));
    buffer = b;

    pw_thread_loop_lock (pwsink->core->loop);
    if (pw_stream_get_state (pwsink->stream, &error) != PW_STREAM_STATE_STREAMING)
      goto done_unlock;
  }

  GST_DEBUG ("push buffer");
  do_send_buffer (pwsink, buffer);

done_unlock:
  pw_thread_loop_unlock (pwsink->core->loop);
done:
  return res;

not_negotiated:
  {
    return GST_FLOW_NOT_NEGOTIATED;
  }
}

static gboolean
copy_properties (GQuark field_id,
                 const GValue *value,
                 gpointer user_data)
{
  struct pw_properties *properties = user_data;
  GValue dst = { 0 };

  if (g_value_type_transformable (G_VALUE_TYPE(value), G_TYPE_STRING)) {
    g_value_init(&dst, G_TYPE_STRING);
    if (g_value_transform(value, &dst)) {
      pw_properties_set (properties,
                         g_quark_to_string (field_id),
                         g_value_get_string (&dst));
    }
    g_value_unset(&dst);
  }
  return TRUE;
}

static const struct pw_stream_events stream_events = {
        PW_VERSION_STREAM_EVENTS,
        .state_changed = on_state_changed,
        .param_changed = on_param_changed,
        .add_buffer = on_add_buffer,
        .remove_buffer = on_remove_buffer,
        .process = on_process,
};

static gboolean
gst_pipewire_sink_start (GstBaseSink * basesink)
{
  GstPipeWireSink *pwsink = GST_PIPEWIRE_SINK (basesink);
  struct pw_properties *props;

  pwsink->negotiated = FALSE;

  props = pw_properties_new (NULL, NULL);
  if (pwsink->client_name) {
    pw_properties_set (props, PW_KEY_NODE_NAME, pwsink->client_name);
    pw_properties_set (props, PW_KEY_NODE_DESCRIPTION, pwsink->client_name);
  }
  if (pwsink->properties) {
    gst_structure_foreach (pwsink->properties, copy_properties, props);
  }

  pw_thread_loop_lock (pwsink->core->loop);
  if ((pwsink->stream = pw_stream_new (pwsink->core->core, pwsink->client_name, props)) == NULL)
    goto no_stream;

  pwsink->pool->stream = pwsink->stream;

  pw_stream_add_listener(pwsink->stream,
                         &pwsink->stream_listener,
                         &stream_events,
                         pwsink);

  pw_thread_loop_unlock (pwsink->core->loop);

  return TRUE;

no_stream:
  {
    GST_ELEMENT_ERROR (pwsink, RESOURCE, FAILED, ("can't create stream"), (NULL));
    pw_thread_loop_unlock (pwsink->core->loop);
    return FALSE;
  }
}

static gboolean
gst_pipewire_sink_stop (GstBaseSink * basesink)
{
  GstPipeWireSink *pwsink = GST_PIPEWIRE_SINK (basesink);

  pw_thread_loop_lock (pwsink->core->loop);
  if (pwsink->stream) {
    pw_stream_destroy (pwsink->stream);
    pwsink->stream = NULL;
    pwsink->pool->stream = NULL;
  }
  pw_thread_loop_unlock (pwsink->core->loop);

  pwsink->negotiated = FALSE;

  return TRUE;
}

static gboolean
gst_pipewire_sink_open (GstPipeWireSink * pwsink)
{
  pwsink->core = gst_pipewire_core_get(pwsink->fd);
  if (pwsink->core == NULL)
      goto connect_error;

  return TRUE;

  /* ERRORS */
connect_error:
  {
    GST_ELEMENT_ERROR (pwsink, RESOURCE, FAILED,
        ("Failed to connect"), (NULL));
    return FALSE;
  }
}

static gboolean
gst_pipewire_sink_close (GstPipeWireSink * pwsink)
{
  pw_thread_loop_lock (pwsink->core->loop);
  if (pwsink->stream) {
    pw_stream_destroy (pwsink->stream);
    pwsink->stream = NULL;
  }
  pw_thread_loop_unlock (pwsink->core->loop);

  if (pwsink->core) {
    gst_pipewire_core_release (pwsink->core);
    pwsink->core = NULL;
  }
  return TRUE;
}

static GstStateChangeReturn
gst_pipewire_sink_change_state (GstElement * element, GstStateChange transition)
{
  GstStateChangeReturn ret;
  GstPipeWireSink *this = GST_PIPEWIRE_SINK_CAST (element);

  switch (transition) {
    case GST_STATE_CHANGE_NULL_TO_READY:
      if (!gst_pipewire_sink_open (this))
        goto open_failed;
      break;
    case GST_STATE_CHANGE_READY_TO_PAUSED:
      break;
    case GST_STATE_CHANGE_PAUSED_TO_PLAYING:
      /* uncork and start play */
      pw_thread_loop_lock (this->core->loop);
      pw_stream_set_active(this->stream, true);
      pw_thread_loop_unlock (this->core->loop);
      gst_buffer_pool_set_flushing(GST_BUFFER_POOL_CAST(this->pool), FALSE);
      break;
    case GST_STATE_CHANGE_PLAYING_TO_PAUSED:
      /* stop play ASAP by corking */
      pw_thread_loop_lock (this->core->loop);
      pw_stream_set_active(this->stream, false);
      pw_thread_loop_unlock (this->core->loop);
      gst_buffer_pool_set_flushing(GST_BUFFER_POOL_CAST(this->pool), TRUE);
      break;
    default:
      break;
  }

  ret = GST_ELEMENT_CLASS (parent_class)->change_state (element, transition);

  switch (transition) {
    case GST_STATE_CHANGE_PLAYING_TO_PAUSED:
      break;
    case GST_STATE_CHANGE_PAUSED_TO_READY:
      gst_buffer_pool_set_active(GST_BUFFER_POOL_CAST(this->pool), FALSE);
      break;
    case GST_STATE_CHANGE_READY_TO_NULL:
      gst_pipewire_sink_close (this);
      break;
    default:
      break;
  }
  return ret;

  /* ERRORS */
open_failed:
  {
    return GST_STATE_CHANGE_FAILURE;
  }
}
