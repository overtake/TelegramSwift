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
 * SECTION:element-pipewiresrc
 *
 * <refsect2>
 * <title>Example launch line</title>
 * |[
 * gst-launch -v pipewiresrc ! videoconvert ! ximagesink
 * ]| Shows pipewire output in an X window.
 * </refsect2>
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "gstpipewiresrc.h"
#include "gstpipewireformat.h"

#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <spa/pod/builder.h>

#include <gst/net/gstnetclientclock.h>
#include <gst/allocators/gstfdmemory.h>
#include <gst/allocators/gstdmabuf.h>
#include <gst/video/video.h>

#include "gstpipewireclock.h"

static GQuark process_mem_data_quark;

GST_DEBUG_CATEGORY_STATIC (pipewire_src_debug);
#define GST_CAT_DEFAULT pipewire_src_debug

#define DEFAULT_ALWAYS_COPY     false
#define DEFAULT_MIN_BUFFERS     8
#define DEFAULT_MAX_BUFFERS     INT32_MAX
#define DEFAULT_RESEND_LAST     false
#define DEFAULT_KEEPALIVE_TIME  0

enum
{
  PROP_0,
  PROP_PATH,
  PROP_CLIENT_NAME,
  PROP_STREAM_PROPERTIES,
  PROP_ALWAYS_COPY,
  PROP_MIN_BUFFERS,
  PROP_MAX_BUFFERS,
  PROP_FD,
  PROP_RESEND_LAST,
  PROP_KEEPALIVE_TIME,
};


static GstStaticPadTemplate gst_pipewire_src_template =
GST_STATIC_PAD_TEMPLATE ("src",
    GST_PAD_SRC,
    GST_PAD_ALWAYS,
    GST_STATIC_CAPS_ANY
    );

#define gst_pipewire_src_parent_class parent_class
G_DEFINE_TYPE (GstPipeWireSrc, gst_pipewire_src, GST_TYPE_PUSH_SRC);

static GstStateChangeReturn
gst_pipewire_src_change_state (GstElement * element, GstStateChange transition);

static gboolean gst_pipewire_src_send_event (GstElement * elem, GstEvent * event);

static gboolean gst_pipewire_src_negotiate (GstBaseSrc * basesrc);

static GstFlowReturn gst_pipewire_src_create (GstPushSrc * psrc,
    GstBuffer ** buffer);
static gboolean gst_pipewire_src_unlock (GstBaseSrc * basesrc);
static gboolean gst_pipewire_src_unlock_stop (GstBaseSrc * basesrc);
static gboolean gst_pipewire_src_start (GstBaseSrc * basesrc);
static gboolean gst_pipewire_src_stop (GstBaseSrc * basesrc);
static gboolean gst_pipewire_src_event (GstBaseSrc * src, GstEvent * event);
static gboolean gst_pipewire_src_query (GstBaseSrc * src, GstQuery * query);

static void
gst_pipewire_src_set_property (GObject * object, guint prop_id,
    const GValue * value, GParamSpec * pspec)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (object);

  switch (prop_id) {
    case PROP_PATH:
      g_free (pwsrc->path);
      pwsrc->path = g_value_dup_string (value);
      break;

    case PROP_CLIENT_NAME:
      g_free (pwsrc->client_name);
      pwsrc->client_name = g_value_dup_string (value);
      break;

    case PROP_STREAM_PROPERTIES:
      if (pwsrc->properties)
        gst_structure_free (pwsrc->properties);
      pwsrc->properties =
          gst_structure_copy (gst_value_get_structure (value));
      break;

    case PROP_ALWAYS_COPY:
      pwsrc->always_copy = g_value_get_boolean (value);
      break;

    case PROP_MIN_BUFFERS:
      pwsrc->min_buffers = g_value_get_int (value);
      break;

    case PROP_MAX_BUFFERS:
      pwsrc->max_buffers = g_value_get_int (value);
      break;

    case PROP_FD:
      pwsrc->fd = g_value_get_int (value);
      break;

    case PROP_RESEND_LAST:
      pwsrc->resend_last = g_value_get_boolean (value);
      break;

    case PROP_KEEPALIVE_TIME:
      pwsrc->keepalive_time = g_value_get_int (value);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_pipewire_src_get_property (GObject * object, guint prop_id,
    GValue * value, GParamSpec * pspec)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (object);

  switch (prop_id) {
    case PROP_PATH:
      g_value_set_string (value, pwsrc->path);
      break;

    case PROP_CLIENT_NAME:
      g_value_set_string (value, pwsrc->client_name);
      break;

    case PROP_STREAM_PROPERTIES:
      gst_value_set_structure (value, pwsrc->properties);
      break;

    case PROP_ALWAYS_COPY:
      g_value_set_boolean (value, pwsrc->always_copy);
      break;

    case PROP_MIN_BUFFERS:
      g_value_set_int (value, pwsrc->min_buffers);
      break;

    case PROP_MAX_BUFFERS:
      g_value_set_int (value, pwsrc->max_buffers);
      break;

    case PROP_FD:
      g_value_set_int (value, pwsrc->fd);
      break;

    case PROP_RESEND_LAST:
      g_value_set_boolean (value, pwsrc->resend_last);
      break;

    case PROP_KEEPALIVE_TIME:
      g_value_set_int (value, pwsrc->keepalive_time);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static GstClock *
gst_pipewire_src_provide_clock (GstElement * elem)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (elem);
  GstClock *clock;

  GST_OBJECT_LOCK (pwsrc);
  if (!GST_OBJECT_FLAG_IS_SET (pwsrc, GST_ELEMENT_FLAG_PROVIDE_CLOCK))
    goto clock_disabled;

  if (pwsrc->clock && pwsrc->is_live)
    clock = GST_CLOCK_CAST (gst_object_ref (pwsrc->clock));
  else
    clock = NULL;
  GST_OBJECT_UNLOCK (pwsrc);

  return clock;

  /* ERRORS */
clock_disabled:
  {
    GST_DEBUG_OBJECT (pwsrc, "clock provide disabled");
    GST_OBJECT_UNLOCK (pwsrc);
    return NULL;
  }
}

static void
gst_pipewire_src_finalize (GObject * object)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (object);

  if (pwsrc->properties)
    gst_structure_free (pwsrc->properties);
  if (pwsrc->clock)
    gst_object_unref (pwsrc->clock);
  g_free (pwsrc->path);
  g_free (pwsrc->client_name);
  g_object_unref(pwsrc->pool);

  G_OBJECT_CLASS (parent_class)->finalize (object);
}

static void
gst_pipewire_src_class_init (GstPipeWireSrcClass * klass)
{
  GObjectClass *gobject_class;
  GstElementClass *gstelement_class;
  GstBaseSrcClass *gstbasesrc_class;
  GstPushSrcClass *gstpushsrc_class;

  gobject_class = (GObjectClass *) klass;
  gstelement_class = (GstElementClass *) klass;
  gstbasesrc_class = (GstBaseSrcClass *) klass;
  gstpushsrc_class = (GstPushSrcClass *) klass;

  gobject_class->finalize = gst_pipewire_src_finalize;
  gobject_class->set_property = gst_pipewire_src_set_property;
  gobject_class->get_property = gst_pipewire_src_get_property;

  g_object_class_install_property (gobject_class,
                                   PROP_PATH,
                                   g_param_spec_string ("path",
                                                        "Path",
                                                        "The source path to connect to (NULL = default)",
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
                                                       "stream properties",
                                                       "list of PipeWire stream properties",
                                                       GST_TYPE_STRUCTURE,
                                                       G_PARAM_READWRITE |
                                                       G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (gobject_class,
                                   PROP_ALWAYS_COPY,
                                   g_param_spec_boolean ("always-copy",
                                                         "Always copy",
                                                         "Always copy the buffer and data",
                                                         DEFAULT_ALWAYS_COPY,
                                                         G_PARAM_READWRITE |
                                                         G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (gobject_class,
                                   PROP_MIN_BUFFERS,
                                   g_param_spec_int ("min-buffers",
                                                     "Min Buffers",
                                                     "Minimum number of buffers to negotiate with PipeWire",
                                                     1, G_MAXINT, DEFAULT_MIN_BUFFERS,
                                                     G_PARAM_READWRITE |
                                                     G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (gobject_class,
                                   PROP_MAX_BUFFERS,
                                   g_param_spec_int ("max-buffers",
                                                     "Max Buffers",
                                                     "Maximum number of buffers to negotiate with PipeWire",
                                                     1, G_MAXINT, DEFAULT_MAX_BUFFERS,
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

  g_object_class_install_property (gobject_class,
                                   PROP_RESEND_LAST,
                                   g_param_spec_boolean ("resend-last",
                                                         "Resend last",
                                                         "Resend last buffer on EOS",
                                                         DEFAULT_RESEND_LAST,
                                                         G_PARAM_READWRITE |
                                                         G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (gobject_class,
                                   PROP_KEEPALIVE_TIME,
                                   g_param_spec_int ("keepalive-time",
                                                     "Keepalive Time",
                                                     "Periodically send last buffer (in milliseconds, 0 = disabled)",
                                                     0, G_MAXINT, DEFAULT_KEEPALIVE_TIME,
                                                     G_PARAM_READWRITE |
                                                     G_PARAM_STATIC_STRINGS));

  gstelement_class->provide_clock = gst_pipewire_src_provide_clock;
  gstelement_class->change_state = gst_pipewire_src_change_state;
  gstelement_class->send_event = gst_pipewire_src_send_event;

  gst_element_class_set_static_metadata (gstelement_class,
      "PipeWire source", "Source/Video",
      "Uses PipeWire to create video", "Wim Taymans <wim.taymans@gmail.com>");

  gst_element_class_add_pad_template (gstelement_class,
      gst_static_pad_template_get (&gst_pipewire_src_template));

  gstbasesrc_class->negotiate = gst_pipewire_src_negotiate;
  gstbasesrc_class->unlock = gst_pipewire_src_unlock;
  gstbasesrc_class->unlock_stop = gst_pipewire_src_unlock_stop;
  gstbasesrc_class->start = gst_pipewire_src_start;
  gstbasesrc_class->stop = gst_pipewire_src_stop;
  gstbasesrc_class->event = gst_pipewire_src_event;
  gstbasesrc_class->query = gst_pipewire_src_query;
  gstpushsrc_class->create = gst_pipewire_src_create;

  GST_DEBUG_CATEGORY_INIT (pipewire_src_debug, "pipewiresrc", 0,
      "PipeWire Source");

  process_mem_data_quark = g_quark_from_static_string ("GstPipeWireSrcProcessMemQuark");
}

static void
gst_pipewire_src_init (GstPipeWireSrc * src)
{
  /* we operate in time */
  gst_base_src_set_format (GST_BASE_SRC (src), GST_FORMAT_TIME);

  GST_OBJECT_FLAG_SET (src, GST_ELEMENT_FLAG_PROVIDE_CLOCK);

  src->always_copy = DEFAULT_ALWAYS_COPY;
  src->min_buffers = DEFAULT_MIN_BUFFERS;
  src->max_buffers = DEFAULT_MAX_BUFFERS;
  src->fd = -1;
  src->resend_last = DEFAULT_RESEND_LAST;
  src->keepalive_time = DEFAULT_KEEPALIVE_TIME;

  src->client_name = g_strdup(pw_get_client_name ());

  src->pool =  gst_pipewire_pool_new ();
}

static gboolean
buffer_recycle (GstMiniObject *obj)
{
  GstPipeWireSrc *src;
  GstPipeWirePoolData *data;

  gst_mini_object_ref (obj);
  data = gst_pipewire_pool_get_data (GST_BUFFER_CAST(obj));

  GST_BUFFER_FLAGS (obj) = data->flags;
  src = data->owner;
  data->queued = TRUE;

  GST_LOG_OBJECT (obj, "recycle buffer");
  pw_thread_loop_lock (src->core->loop);
  if (src->stream)
    pw_stream_queue_buffer (src->stream, data->b);
  pw_thread_loop_unlock (src->core->loop);

  return FALSE;
}

static void
on_add_buffer (void *_data, struct pw_buffer *b)
{
  GstPipeWireSrc *pwsrc = _data;
  GstPipeWirePoolData *data;

  GST_DEBUG_OBJECT (pwsrc, "add buffer");
  gst_pipewire_pool_wrap_buffer (pwsrc->pool, b);
  data = b->user_data;
  data->owner = pwsrc;
  data->queued = TRUE;
  GST_MINI_OBJECT_CAST (data->buf)->dispose = buffer_recycle;
}

static void
on_remove_buffer (void *_data, struct pw_buffer *b)
{
  GstPipeWireSrc *pwsrc = _data;
  GstPipeWirePoolData *data = b->user_data;
  GstBuffer *buf = data->buf;

  GST_DEBUG_OBJECT (pwsrc, "remove buffer %p", buf);

  GST_MINI_OBJECT_CAST (buf)->dispose = NULL;

  gst_buffer_unref (buf);
}

static GstBuffer *dequeue_buffer(GstPipeWireSrc *pwsrc)
{
  struct pw_buffer *b;
  GstBuffer *buf;
  GstPipeWirePoolData *data;
  struct spa_meta_header *h;
  struct spa_meta_region *crop;
  guint i;

  b = pw_stream_dequeue_buffer (pwsrc->stream);
  if (b == NULL)
          return NULL;

  data = b->user_data;
  buf = data->buf;

  GST_LOG_OBJECT (pwsrc, "got new buffer %p", buf);

  if (!data->queued) {
    GST_WARNING_OBJECT (pwsrc, "buffer %p was not recycled", buf);
    gst_buffer_ref (buf);
  }
  data->queued = FALSE;
  GST_BUFFER_PTS (buf) = GST_CLOCK_TIME_NONE;
  GST_BUFFER_DTS (buf) = GST_CLOCK_TIME_NONE;

  h = data->header;
  if (h) {
    GST_LOG_OBJECT (pwsrc, "pts %" G_GUINT64_FORMAT ", dts_offset %" G_GUINT64_FORMAT, h->pts, h->dts_offset);

    if (GST_CLOCK_TIME_IS_VALID (h->pts)) {
      GST_BUFFER_PTS (buf) = h->pts + GST_PIPEWIRE_CLOCK (pwsrc->clock)->time_offset;
      if (GST_BUFFER_PTS (buf) + h->dts_offset > 0)
        GST_BUFFER_DTS (buf) = GST_BUFFER_PTS (buf) + h->dts_offset;
    }
    GST_BUFFER_OFFSET (buf) = h->seq;
  }
  crop = data->crop;
  if (crop) {
    GstVideoCropMeta *meta = gst_buffer_get_video_crop_meta(buf);
    if (meta) {
      meta->x = crop->region.position.x;
      meta->y = crop->region.position.y;
      meta->width = crop->region.size.width;
      meta->height = crop->region.size.height;
    }
  }
  for (i = 0; i < b->buffer->n_datas; i++) {
    struct spa_data *d = &b->buffer->datas[i];
    GstMemory *mem = gst_buffer_peek_memory (buf, i);
    mem->offset = SPA_MIN(d->chunk->offset, d->maxsize);
    mem->size = SPA_MIN(d->chunk->size, d->maxsize - mem->offset);
    mem->offset += data->offset;
    if (d->chunk->flags & SPA_CHUNK_FLAG_CORRUPTED)
      GST_BUFFER_FLAG_SET (buf, GST_BUFFER_FLAG_CORRUPTED);
  }
  return buf;
}

static void
on_process (void *_data)
{
  GstPipeWireSrc *pwsrc = _data;
  pw_thread_loop_signal (pwsrc->core->loop, FALSE);
}

static void
on_state_changed (void *data,
                  enum pw_stream_state old,
                  enum pw_stream_state state, const char *error)
{
  GstPipeWireSrc *pwsrc = data;

  GST_DEBUG ("got stream state %s", pw_stream_state_as_string (state));

  switch (state) {
    case PW_STREAM_STATE_UNCONNECTED:
    case PW_STREAM_STATE_CONNECTING:
    case PW_STREAM_STATE_PAUSED:
    case PW_STREAM_STATE_STREAMING:
      break;
    case PW_STREAM_STATE_ERROR:
      GST_ELEMENT_ERROR (pwsrc, RESOURCE, FAILED,
          ("stream error: %s", error), (NULL));
      break;
  }
  pw_thread_loop_signal (pwsrc->core->loop, FALSE);
}

static void
parse_stream_properties (GstPipeWireSrc *pwsrc, const struct pw_properties *props)
{
  const gchar *var;
  gboolean is_live;

  GST_OBJECT_LOCK (pwsrc);
  var = pw_properties_get (props, PW_KEY_STREAM_IS_LIVE);
  is_live = pwsrc->is_live = var ? pw_properties_parse_bool(var) : FALSE;

  var = pw_properties_get (props, PW_KEY_STREAM_LATENCY_MIN);
  pwsrc->min_latency = var ? (GstClockTime) atoi (var) : 0;

  var = pw_properties_get (props, PW_KEY_STREAM_LATENCY_MAX);
  pwsrc->max_latency = var ? (GstClockTime) atoi (var) : GST_CLOCK_TIME_NONE;
  GST_OBJECT_UNLOCK (pwsrc);

  GST_DEBUG_OBJECT (pwsrc, "live %d", is_live);

  gst_base_src_set_live (GST_BASE_SRC (pwsrc), is_live);
}

static gboolean
gst_pipewire_src_stream_start (GstPipeWireSrc *pwsrc)
{
  const char *error = NULL;

  pw_thread_loop_lock (pwsrc->core->loop);
  GST_DEBUG_OBJECT (pwsrc, "doing stream start");
  while (TRUE) {
    enum pw_stream_state state = pw_stream_get_state (pwsrc->stream, &error);

    GST_DEBUG_OBJECT (pwsrc, "waiting for STREAMING, now %s", pw_stream_state_as_string (state));
    if (state == PW_STREAM_STATE_STREAMING)
      break;

    if (state == PW_STREAM_STATE_ERROR)
      goto start_error;

    pw_thread_loop_wait (pwsrc->core->loop);
  }

  parse_stream_properties (pwsrc, pw_stream_get_properties (pwsrc->stream));
  GST_DEBUG_OBJECT (pwsrc, "signal started");
  pwsrc->started = TRUE;
  pw_thread_loop_signal (pwsrc->core->loop, FALSE);
  pw_thread_loop_unlock (pwsrc->core->loop);

  return TRUE;

start_error:
  {
    GST_DEBUG_OBJECT (pwsrc, "error starting stream: %s", error);
    pw_thread_loop_unlock (pwsrc->core->loop);
    return FALSE;
  }
}

static enum pw_stream_state
wait_started (GstPipeWireSrc *this)
{
  enum pw_stream_state state;
  const char *error = NULL;

  pw_thread_loop_lock (this->core->loop);
  while (TRUE) {
    state = pw_stream_get_state (this->stream, &error);

    GST_DEBUG_OBJECT (this, "waiting for started signal, state now %s",
        pw_stream_state_as_string (state));

    if (state == PW_STREAM_STATE_ERROR)
      break;

    if (this->started)
      break;

    pw_thread_loop_wait (this->core->loop);
  }
  GST_DEBUG_OBJECT (this, "got started signal");
  pw_thread_loop_unlock (this->core->loop);

  return state;
}

static gboolean
gst_pipewire_src_negotiate (GstBaseSrc * basesrc)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (basesrc);
  GstCaps *thiscaps;
  GstCaps *caps = NULL;
  GstCaps *peercaps = NULL;
  gboolean result = FALSE;
  GPtrArray *possible;
  const char *error = NULL;

  /* first see what is possible on our source pad */
  thiscaps = gst_pad_query_caps (GST_BASE_SRC_PAD (basesrc), NULL);
  GST_DEBUG_OBJECT (basesrc, "caps of src: %" GST_PTR_FORMAT, thiscaps);
  /* nothing or anything is allowed, we're done */
  if (thiscaps == NULL)
    goto no_nego_needed;

  if (G_UNLIKELY (gst_caps_is_empty (thiscaps)))
    goto no_caps;

  /* get the peer caps */
  peercaps = gst_pad_peer_query_caps (GST_BASE_SRC_PAD (basesrc), thiscaps);
  GST_DEBUG_OBJECT (basesrc, "caps of peer: %" GST_PTR_FORMAT, peercaps);
  if (peercaps) {
    /* The result is already a subset of our caps */
    caps = peercaps;
    gst_caps_unref (thiscaps);
  } else {
    /* no peer, work with our own caps then */
    caps = thiscaps;
  }
  if (caps == NULL || gst_caps_is_empty (caps))
    goto no_common_caps;

  GST_DEBUG_OBJECT (basesrc, "have common caps: %" GST_PTR_FORMAT, caps);

  /* open a connection with these caps */
  possible = gst_caps_to_format_all (caps, SPA_PARAM_EnumFormat);
  gst_caps_unref (caps);

  /* first disconnect */
  pw_thread_loop_lock (pwsrc->core->loop);
  if (pw_stream_get_state(pwsrc->stream, &error) != PW_STREAM_STATE_UNCONNECTED) {
    GST_DEBUG_OBJECT (basesrc, "disconnect capture");
    pw_stream_disconnect (pwsrc->stream);
    while (TRUE) {
      enum pw_stream_state state = pw_stream_get_state (pwsrc->stream, &error);

      GST_DEBUG_OBJECT (basesrc, "waiting for UNCONNECTED, now %s", pw_stream_state_as_string (state));
      if (state == PW_STREAM_STATE_UNCONNECTED)
        break;

      if (state == PW_STREAM_STATE_ERROR) {
        g_ptr_array_unref (possible);
        goto connect_error;
      }

      pw_thread_loop_wait (pwsrc->core->loop);
    }
  }

  GST_DEBUG_OBJECT (basesrc, "connect capture with path %s", pwsrc->path);
  pwsrc->negotiated = FALSE;
  pw_stream_connect (pwsrc->stream,
                     PW_DIRECTION_INPUT,
                     pwsrc->path ? (uint32_t)atoi(pwsrc->path) : PW_ID_ANY,
                     PW_STREAM_FLAG_AUTOCONNECT,
                     (const struct spa_pod **)possible->pdata,
                     possible->len);
  g_ptr_array_free (possible, TRUE);

  while (TRUE) {
    enum pw_stream_state state = pw_stream_get_state (pwsrc->stream, &error);

    GST_DEBUG_OBJECT (basesrc, "waiting for NEGOTIATED, now %s", pw_stream_state_as_string (state));
    if (state == PW_STREAM_STATE_ERROR)
      goto connect_error;

    if (pwsrc->negotiated)
      break;

    pw_thread_loop_wait (pwsrc->core->loop);
  }
  caps = pwsrc->caps;
  pwsrc->caps = NULL;
  pw_thread_loop_unlock (pwsrc->core->loop);

  if (caps == NULL)
    goto no_caps;

  gst_pipewire_clock_reset (GST_PIPEWIRE_CLOCK (pwsrc->clock), 0);

  GST_DEBUG_OBJECT (pwsrc, "set format %" GST_PTR_FORMAT, caps);
  result = gst_base_src_set_caps (GST_BASE_SRC (pwsrc), caps);
  gst_caps_unref (caps);

  result = gst_pipewire_src_stream_start (pwsrc);

  pwsrc->started = result;

  return result;

no_nego_needed:
  {
    GST_DEBUG_OBJECT (basesrc, "no negotiation needed");
    if (thiscaps)
      gst_caps_unref (thiscaps);
    return TRUE;
  }
no_caps:
  {
    GST_ELEMENT_ERROR (basesrc, STREAM, FORMAT,
        ("No supported formats found"),
        ("This element did not produce valid caps"));
    if (thiscaps)
      gst_caps_unref (thiscaps);
    return FALSE;
  }
no_common_caps:
  {
    GST_ELEMENT_ERROR (basesrc, STREAM, FORMAT,
        ("No supported formats found"),
        ("This element does not have formats in common with the peer"));
    if (caps)
      gst_caps_unref (caps);
    return FALSE;
  }
connect_error:
  {
    pw_thread_loop_unlock (pwsrc->core->loop);
    return FALSE;
  }
}

static void
on_param_changed (void *data, uint32_t id,
                   const struct spa_pod *param)
{
  GstPipeWireSrc *pwsrc = data;

  if (param == NULL || id != SPA_PARAM_Format) {
    GST_DEBUG_OBJECT (pwsrc, "clear format");
    return;
  }
  if (pwsrc->caps)
	  gst_caps_unref(pwsrc->caps);
  pwsrc->caps = gst_caps_from_format (param);
  GST_DEBUG_OBJECT (pwsrc, "we got format %" GST_PTR_FORMAT, pwsrc->caps);

  pwsrc->negotiated = pwsrc->caps != NULL;

  if (pwsrc->negotiated) {
    const struct spa_pod *params[3];
    struct spa_pod_builder b = { NULL };
    uint8_t buffer[512];
    uint32_t buffers = CLAMP (16, pwsrc->min_buffers, pwsrc->max_buffers);

    spa_pod_builder_init (&b, buffer, sizeof (buffer));
    params[0] = spa_pod_builder_add_object (&b,
        SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
        SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(buffers,
                                                            pwsrc->min_buffers,
                                                            pwsrc->max_buffers),
        SPA_PARAM_BUFFERS_blocks,  SPA_POD_CHOICE_RANGE_Int(0, 1, INT32_MAX),
        SPA_PARAM_BUFFERS_size,    SPA_POD_CHOICE_RANGE_Int(0, 0, INT32_MAX),
        SPA_PARAM_BUFFERS_stride,  SPA_POD_CHOICE_RANGE_Int(0, 0, INT32_MAX),
        SPA_PARAM_BUFFERS_align,   SPA_POD_Int(16),
        SPA_PARAM_BUFFERS_dataType, SPA_POD_CHOICE_FLAGS_Int(
						(1<<SPA_DATA_DmaBuf) |
						(1<<SPA_DATA_MemFd) |
						(1<<SPA_DATA_MemPtr)));

    params[1] = spa_pod_builder_add_object (&b,
        SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
        SPA_PARAM_META_size, SPA_POD_Int(sizeof (struct spa_meta_header)));
    params[2] = spa_pod_builder_add_object (&b,
        SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_VideoCrop),
        SPA_PARAM_META_size, SPA_POD_Int(sizeof (struct spa_meta_region)));

    GST_DEBUG_OBJECT (pwsrc, "doing finish format");
    pw_stream_update_params (pwsrc->stream, params, 3);
  } else {
    GST_WARNING_OBJECT (pwsrc, "finish format with error");
    pw_stream_set_error (pwsrc->stream, -EINVAL, "unhandled format");
  }
  pw_thread_loop_signal (pwsrc->core->loop, FALSE);
}

static gboolean
gst_pipewire_src_unlock (GstBaseSrc * basesrc)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (basesrc);

  pw_thread_loop_lock (pwsrc->core->loop);
  GST_DEBUG_OBJECT (pwsrc, "setting flushing");
  pwsrc->flushing = TRUE;
  pw_thread_loop_signal (pwsrc->core->loop, FALSE);
  pw_thread_loop_unlock (pwsrc->core->loop);

  return TRUE;
}

static gboolean
gst_pipewire_src_unlock_stop (GstBaseSrc * basesrc)
{
  GstPipeWireSrc *pwsrc = GST_PIPEWIRE_SRC (basesrc);

  pw_thread_loop_lock (pwsrc->core->loop);
  GST_DEBUG_OBJECT (pwsrc, "unsetting flushing");
  pwsrc->flushing = FALSE;
  pw_thread_loop_unlock (pwsrc->core->loop);

  return TRUE;
}

static gboolean
gst_pipewire_src_event (GstBaseSrc * src, GstEvent * event)
{
  gboolean res = FALSE;

  switch (GST_EVENT_TYPE (event)) {
    case GST_EVENT_CUSTOM_UPSTREAM:
      if (gst_video_event_is_force_key_unit (event)) {
        GstClockTime running_time;
        gboolean all_headers;
        guint count;

        gst_video_event_parse_upstream_force_key_unit (event,
                &running_time, &all_headers, &count);

        res = TRUE;
      } else {
        res = GST_BASE_SRC_CLASS (parent_class)->event (src, event);
      }
      break;
    default:
      res = GST_BASE_SRC_CLASS (parent_class)->event (src, event);
      break;
  }
  return res;
}

static gboolean
gst_pipewire_src_query (GstBaseSrc * src, GstQuery * query)
{
  gboolean res = FALSE;
  GstPipeWireSrc *pwsrc;

  pwsrc = GST_PIPEWIRE_SRC (src);

  switch (GST_QUERY_TYPE (query)) {
    case GST_QUERY_LATENCY:
      GST_OBJECT_LOCK (pwsrc);
      pwsrc->min_latency = 10000000;
      pwsrc->max_latency = GST_CLOCK_TIME_NONE;
      gst_query_set_latency (query, pwsrc->is_live, pwsrc->min_latency, pwsrc->max_latency);
      GST_OBJECT_UNLOCK (pwsrc);
      res = TRUE;
      break;
    default:
      res = GST_BASE_SRC_CLASS (parent_class)->query (src, query);
      break;
  }
  return res;
}

static GstFlowReturn
gst_pipewire_src_create (GstPushSrc * psrc, GstBuffer ** buffer)
{
  GstPipeWireSrc *pwsrc;
  GstClockTime pts, dts, base_time;
  const char *error = NULL;
  GstBuffer *buf;
  gboolean update_time = FALSE, timeout = FALSE;

  pwsrc = GST_PIPEWIRE_SRC (psrc);

  if (!pwsrc->negotiated)
    goto not_negotiated;

  pw_thread_loop_lock (pwsrc->core->loop);
  while (TRUE) {
    enum pw_stream_state state;

    if (pwsrc->flushing)
      goto streaming_stopped;

    if (pwsrc->stream == NULL)
      goto streaming_error;

    state = pw_stream_get_state (pwsrc->stream, &error);
    if (state == PW_STREAM_STATE_ERROR)
      goto streaming_error;

    if (state != PW_STREAM_STATE_STREAMING)
      goto streaming_stopped;

    if (pwsrc->eos) {
      if (pwsrc->last_buffer == NULL)
        goto streaming_eos;
      buf = pwsrc->last_buffer;
      pwsrc->last_buffer = NULL;
      update_time = TRUE;
      GST_LOG_OBJECT (pwsrc, "EOS, send last buffer");
      break;
    } else if (timeout) {
      if (pwsrc->last_buffer != NULL) {
        update_time = TRUE;
        buf = gst_buffer_ref(pwsrc->last_buffer);
        GST_LOG_OBJECT (pwsrc, "timeout, send keepalive buffer");
        break;
      }
    } else {
      buf = dequeue_buffer (pwsrc);
      GST_LOG_OBJECT (pwsrc, "popped buffer %p", buf);
      if (buf != NULL) {
	if (pwsrc->resend_last || pwsrc->keepalive_time > 0)
          gst_buffer_replace (&pwsrc->last_buffer, buf);
        break;
      }
    }
    timeout = FALSE;
    if (pwsrc->keepalive_time > 0) {
      struct timespec abstime;
      pw_thread_loop_get_time(pwsrc->core->loop, &abstime,
		      pwsrc->keepalive_time * SPA_NSEC_PER_MSEC);
      if (pw_thread_loop_timed_wait_full (pwsrc->core->loop, &abstime) == -ETIMEDOUT)
        timeout = TRUE;
    } else {
      pw_thread_loop_wait (pwsrc->core->loop);
    }
  }
  pw_thread_loop_unlock (pwsrc->core->loop);

  if (pwsrc->always_copy) {
    *buffer = gst_buffer_copy_deep (buf);
    gst_buffer_unref (buf);
  }
  else
    *buffer = buf;

  if (pwsrc->is_live)
    base_time = GST_ELEMENT_CAST (psrc)->base_time;
  else
    base_time = 0;

  if (update_time) {
    GstClock *clock = gst_element_get_clock (GST_ELEMENT_CAST (pwsrc));
    if (clock != NULL) {
      pts = dts = gst_clock_get_time (clock);
      gst_object_unref (clock);
    } else {
      pts = dts = GST_CLOCK_TIME_NONE;
    }
  } else {
    pts = GST_BUFFER_PTS (*buffer);
    dts = GST_BUFFER_DTS (*buffer);
  }

  if (GST_CLOCK_TIME_IS_VALID (pts))
    pts = (pts >= base_time ? pts - base_time : 0);
  if (GST_CLOCK_TIME_IS_VALID (dts))
    dts = (dts >= base_time ? dts - base_time : 0);

  GST_LOG_OBJECT (pwsrc,
      "pts %" G_GUINT64_FORMAT ", dts %" G_GUINT64_FORMAT
      ", base-time %" GST_TIME_FORMAT " -> %" GST_TIME_FORMAT ", %" GST_TIME_FORMAT,
      GST_BUFFER_PTS (*buffer), GST_BUFFER_DTS (*buffer), GST_TIME_ARGS (base_time),
      GST_TIME_ARGS (pts), GST_TIME_ARGS (dts));

  GST_BUFFER_PTS (*buffer) = pts;
  GST_BUFFER_DTS (*buffer) = dts;

  return GST_FLOW_OK;

not_negotiated:
  {
    return GST_FLOW_NOT_NEGOTIATED;
  }
streaming_eos:
  {
    pw_thread_loop_unlock (pwsrc->core->loop);
    return GST_FLOW_EOS;
  }
streaming_error:
  {
    pw_thread_loop_unlock (pwsrc->core->loop);
    return GST_FLOW_ERROR;
  }
streaming_stopped:
  {
    pw_thread_loop_unlock (pwsrc->core->loop);
    return GST_FLOW_FLUSHING;
  }
}

static gboolean
gst_pipewire_src_start (GstBaseSrc * basesrc)
{
  return TRUE;
}

static gboolean
gst_pipewire_src_stop (GstBaseSrc * basesrc)
{
  GstPipeWireSrc *pwsrc;

  pwsrc = GST_PIPEWIRE_SRC (basesrc);

  pw_thread_loop_lock (pwsrc->core->loop);
  pwsrc->eos = false;
  gst_buffer_replace (&pwsrc->last_buffer, NULL);
  gst_caps_replace(&pwsrc->caps, NULL);
  pw_thread_loop_unlock (pwsrc->core->loop);

  return TRUE;
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
gst_pipewire_src_open (GstPipeWireSrc * pwsrc)
{
  struct pw_properties *props;

  pwsrc->core = gst_pipewire_core_get(pwsrc->fd);
  if (pwsrc->core == NULL)
      goto connect_error;

  pw_thread_loop_lock (pwsrc->core->loop);

  props = pw_properties_new (NULL, NULL);
  if (pwsrc->client_name) {
    pw_properties_set (props, PW_KEY_NODE_NAME, pwsrc->client_name);
    pw_properties_set (props, PW_KEY_NODE_DESCRIPTION, pwsrc->client_name);
  }
  if (pwsrc->properties) {
    gst_structure_foreach (pwsrc->properties, copy_properties, props);
  }

  if ((pwsrc->stream = pw_stream_new (pwsrc->core->core,
                                  pwsrc->client_name, props)) == NULL)
    goto no_stream;


  pw_stream_add_listener(pwsrc->stream,
                         &pwsrc->stream_listener,
                         &stream_events,
                         pwsrc);

  pwsrc->clock = gst_pipewire_clock_new (pwsrc->stream, pwsrc->last_time);
  pw_thread_loop_unlock (pwsrc->core->loop);

  return TRUE;

  /* ERRORS */
connect_error:
  {
    GST_ELEMENT_ERROR (pwsrc, RESOURCE, FAILED, ("can't connect"), (NULL));
    return FALSE;
  }
no_stream:
  {
    GST_ELEMENT_ERROR (pwsrc, RESOURCE, FAILED, ("can't create stream"), (NULL));
    pw_thread_loop_unlock (pwsrc->core->loop);
    gst_pipewire_core_release (pwsrc->core);
    pwsrc->core = NULL;
    return FALSE;
  }
}

static void
gst_pipewire_src_close (GstPipeWireSrc * pwsrc)
{
  pwsrc->last_time = gst_clock_get_time (pwsrc->clock);

  gst_element_post_message (GST_ELEMENT (pwsrc),
    gst_message_new_clock_lost (GST_OBJECT_CAST (pwsrc), pwsrc->clock));

  GST_OBJECT_LOCK (pwsrc);
  GST_PIPEWIRE_CLOCK (pwsrc->clock)->stream = NULL;
  g_clear_object (&pwsrc->clock);
  GST_OBJECT_UNLOCK (pwsrc);

  pw_thread_loop_lock (pwsrc->core->loop);
  if (pwsrc->stream) {
    pw_stream_destroy (pwsrc->stream);
    pwsrc->stream = NULL;
  }
  pw_thread_loop_unlock (pwsrc->core->loop);

  if (pwsrc->core) {
    gst_pipewire_core_release (pwsrc->core);
    pwsrc->core = NULL;
  }
}

static gboolean
gst_pipewire_src_send_event (GstElement * elem, GstEvent * event)
{
  GstPipeWireSrc *this = GST_PIPEWIRE_SRC_CAST (elem);
  gboolean ret;

  switch (GST_EVENT_TYPE (event)) {
    case GST_EVENT_EOS:
      GST_DEBUG_OBJECT (this, "got EOS");
      pw_thread_loop_lock (this->core->loop);
      this->eos = true;
      pw_thread_loop_signal (this->core->loop, FALSE);
      pw_thread_loop_unlock (this->core->loop);
      ret = TRUE;
      break;
    default:
      ret = GST_ELEMENT_CLASS (parent_class)->send_event (elem, event);
      break;
  }
  return ret;
}

static GstStateChangeReturn
gst_pipewire_src_change_state (GstElement * element, GstStateChange transition)
{
  GstStateChangeReturn ret;
  GstPipeWireSrc *this = GST_PIPEWIRE_SRC_CAST (element);

  switch (transition) {
    case GST_STATE_CHANGE_NULL_TO_READY:
      if (!gst_pipewire_src_open (this))
        goto open_failed;
      break;
    case GST_STATE_CHANGE_READY_TO_PAUSED:
      break;
    case GST_STATE_CHANGE_PAUSED_TO_PLAYING:
      /* uncork and start recording */
      pw_thread_loop_lock (this->core->loop);
      pw_stream_set_active(this->stream, true);
      pw_thread_loop_unlock (this->core->loop);
      break;
    case GST_STATE_CHANGE_PLAYING_TO_PAUSED:
      /* stop recording ASAP by corking */
      pw_thread_loop_lock (this->core->loop);
      pw_stream_set_active(this->stream, false);
      pw_thread_loop_unlock (this->core->loop);
      break;
    default:
      break;
  }

  ret = GST_ELEMENT_CLASS (parent_class)->change_state (element, transition);

  switch (transition) {
    case GST_STATE_CHANGE_READY_TO_PAUSED:
      if (wait_started (this) == PW_STREAM_STATE_ERROR)
        goto open_failed;

      if (gst_base_src_is_live (GST_BASE_SRC (element)))
        ret = GST_STATE_CHANGE_NO_PREROLL;
      break;
    case GST_STATE_CHANGE_PLAYING_TO_PAUSED:
      break;
    case GST_STATE_CHANGE_PAUSED_TO_READY:
      this->negotiated = FALSE;
      break;
    case GST_STATE_CHANGE_READY_TO_NULL:
      gst_pipewire_src_close (this);
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
