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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <string.h>

#include <spa/utils/result.h>

#include <gst/gst.h>

#include "gstpipewireformat.h"
#include "gstpipewiredeviceprovider.h"
#include "gstpipewiresrc.h"
#include "gstpipewiresink.h"

GST_DEBUG_CATEGORY_EXTERN (pipewire_debug);
#define GST_CAT_DEFAULT pipewire_debug

G_DEFINE_TYPE (GstPipeWireDevice, gst_pipewire_device, GST_TYPE_DEVICE);

enum
{
  PROP_ID = 1,
};

static GstElement *
gst_pipewire_device_create_element (GstDevice * device, const gchar * name)
{
  GstPipeWireDevice *pipewire_dev = GST_PIPEWIRE_DEVICE (device);
  GstElement *elem;
  gchar *str;

  elem = gst_element_factory_make (pipewire_dev->element, name);
  str = g_strdup_printf ("%u", pipewire_dev->id);
  g_object_set (elem, "path", str, NULL);
  g_free (str);

  return elem;
}

static gboolean
gst_pipewire_device_reconfigure_element (GstDevice * device, GstElement * element)
{
  GstPipeWireDevice *pipewire_dev = GST_PIPEWIRE_DEVICE (device);
  gchar *str;

  if (!strcmp (pipewire_dev->element, "pipewiresrc")) {
    if (!GST_IS_PIPEWIRE_SRC (element))
      return FALSE;
  } else if (!strcmp (pipewire_dev->element, "pipewiresink")) {
    if (!GST_IS_PIPEWIRE_SINK (element))
      return FALSE;
  } else {
    g_assert_not_reached ();
  }

  str = g_strdup_printf ("%u", pipewire_dev->id);
  g_object_set (element, "path", str, NULL);
  g_free (str);

  return TRUE;
}


static void
gst_pipewire_device_get_property (GObject * object, guint prop_id,
    GValue * value, GParamSpec * pspec)
{
  GstPipeWireDevice *device;

  device = GST_PIPEWIRE_DEVICE_CAST (object);

  switch (prop_id) {
    case PROP_ID:
      g_value_set_uint (value, device->id);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_pipewire_device_set_property (GObject * object, guint prop_id,
    const GValue * value, GParamSpec * pspec)
{
  GstPipeWireDevice *device;

  device = GST_PIPEWIRE_DEVICE_CAST (object);

  switch (prop_id) {
    case PROP_ID:
      device->id = g_value_get_uint (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_pipewire_device_finalize (GObject * object)
{
  G_OBJECT_CLASS (gst_pipewire_device_parent_class)->finalize (object);
}

static void
gst_pipewire_device_class_init (GstPipeWireDeviceClass * klass)
{
  GstDeviceClass *dev_class = GST_DEVICE_CLASS (klass);
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  dev_class->create_element = gst_pipewire_device_create_element;
  dev_class->reconfigure_element = gst_pipewire_device_reconfigure_element;

  object_class->get_property = gst_pipewire_device_get_property;
  object_class->set_property = gst_pipewire_device_set_property;
  object_class->finalize = gst_pipewire_device_finalize;

  g_object_class_install_property (object_class, PROP_ID,
      g_param_spec_uint ("id", "Id",
          "The internal id of the PipeWire device", 0, G_MAXUINT32, SPA_ID_INVALID,
          G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));
}

static void
gst_pipewire_device_init (GstPipeWireDevice * device)
{
}

G_DEFINE_TYPE (GstPipeWireDeviceProvider, gst_pipewire_device_provider,
    GST_TYPE_DEVICE_PROVIDER);

enum
{
  PROP_0,
  PROP_CLIENT_NAME,
  PROP_LAST
};

struct core_data {
  int seq;
  GstPipeWireDeviceProvider *self;
  struct spa_hook core_listener;
  struct pw_registry *registry;
  struct spa_hook registry_listener;
  struct spa_list nodes;
};

struct node_data {
  struct spa_list link;
  GstPipeWireDeviceProvider *self;
  struct pw_node *proxy;
  struct spa_hook proxy_listener;
  uint32_t id;
  struct spa_hook node_listener;
  struct pw_node_info *info;
  GstCaps *caps;
  GstDevice *dev;
};

struct port_data {
  struct node_data *node_data;
  struct pw_port *proxy;
  struct spa_hook proxy_listener;
  uint32_t id;
  struct spa_hook port_listener;
};

static struct node_data *find_node_data(struct core_data *rd, uint32_t id)
{
  struct node_data *n;
  spa_list_for_each(n, &rd->nodes, link) {
    if (n->id == id)
      return n;
  }
  return NULL;
}

static GstDevice *
new_node (GstPipeWireDeviceProvider *self, struct node_data *data)
{
  GstStructure *props;
  const gchar *klass = NULL, *name = NULL;
  GstPipeWireDeviceType type;
  const struct pw_node_info *info = data->info;
  const gchar *element = NULL;
  GstPipeWireDevice *gstdev;

  if (info->max_input_ports > 0 && info->max_output_ports == 0) {
    type = GST_PIPEWIRE_DEVICE_TYPE_SINK;
    element = "pipewiresink";
  } else if (info->max_output_ports > 0 && info->max_input_ports == 0) {
    type = GST_PIPEWIRE_DEVICE_TYPE_SOURCE;
    element = "pipewiresrc";
  } else {
    return NULL;
  }

  props = gst_structure_new_empty ("pipewire-proplist");
  if (info->props) {
    const struct spa_dict_item *item;
    spa_dict_for_each (item, info->props)
      gst_structure_set (props, item->key, G_TYPE_STRING, item->value, NULL);

    klass = spa_dict_lookup (info->props, PW_KEY_MEDIA_CLASS);
    name = spa_dict_lookup (info->props, PW_KEY_NODE_DESCRIPTION);
  }
  if (klass == NULL)
    klass = "unknown/unknown";
  if (name == NULL)
    name = "unknown";

  gstdev = g_object_new (GST_TYPE_PIPEWIRE_DEVICE,
      "display-name", name, "caps", data->caps, "device-class", klass,
      "id", data->id, "properties", props, NULL);

  gstdev->id = data->id;
  gstdev->type = type;
  gstdev->element = element;
  if (props)
    gst_structure_free (props);

  return GST_DEVICE (gstdev);
}

static void do_add_nodes(struct core_data *rd)
{
  GstPipeWireDeviceProvider *self = rd->self;
  struct node_data *nd;

  spa_list_for_each(nd, &rd->nodes, link) {
    if (nd->dev != NULL)
	    continue;
    pw_log_info("add node %d", nd->id);
    nd->dev = new_node (self, nd);
    if (nd->dev) {
      if(self->list_only)
        self->devices = g_list_prepend (self->devices, gst_object_ref_sink (nd->dev));
      else
        gst_device_provider_device_add (GST_DEVICE_PROVIDER (self), nd->dev);
    }
  }
}

static void resync(GstPipeWireDeviceProvider *self)
{
  self->seq = pw_core_sync(self->core, PW_ID_CORE, self->seq);
  pw_log_debug("resync %d", self->seq);
}

static void
on_core_done (void *data, uint32_t id, int seq)
{
  struct core_data *rd = data;
  GstPipeWireDeviceProvider *self = rd->self;

  pw_log_debug("check %d %d", seq, self->seq);
  if (id == PW_ID_CORE && seq == self->seq) {
    do_add_nodes(rd);
    self->end = true;
    if (self->loop)
      pw_thread_loop_signal (self->loop, FALSE);
  }
}


static void
on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
  struct core_data *rd = data;
  GstPipeWireDeviceProvider *self = rd->self;

  pw_log_warn("error id:%u seq:%d res:%d (%s): %s",
          id, seq, res, spa_strerror(res), message);

  if (id == PW_ID_CORE) {
    self->error = res;
  }
  pw_thread_loop_signal(self->loop, FALSE);
}

static const struct pw_core_events core_events = {
  PW_VERSION_CORE_EVENTS,
  .done = on_core_done,
  .error = on_core_error,
};

static void port_event_info(void *data, const struct pw_port_info *info)
{
  struct port_data *port_data = data;
  struct node_data *node_data = port_data->node_data;
  uint32_t i;

  pw_log_debug("%p", port_data);

  if (info->change_mask & PW_PORT_CHANGE_MASK_PARAMS) {
    for (i = 0; i < info->n_params; i++) {
      uint32_t id = info->params[i].id;

      if (id == SPA_PARAM_EnumFormat &&
          info->params[i].flags & SPA_PARAM_INFO_READ &&
	  node_data->caps == NULL) {
        node_data->caps = gst_caps_new_empty ();
        pw_port_enum_params(port_data->proxy, 0, id, 0, UINT32_MAX, NULL);
        resync(node_data->self);
      }
    }
  }
}

static void port_event_param(void *data, int seq, uint32_t id,
                uint32_t index, uint32_t next, const struct spa_pod *param)
{
  struct port_data *port_data = data;
  struct node_data *node_data = port_data->node_data;
  GstCaps *c1;

  c1 = gst_caps_from_format (param);
  if (c1 && node_data->caps)
      gst_caps_append (node_data->caps, c1);
}

static const struct pw_port_events port_events = {
  PW_VERSION_PORT_EVENTS,
  .info = port_event_info,
  .param = port_event_param
};

static void node_event_info(void *data, const struct pw_node_info *info)
{
  struct node_data *node_data = data;
  uint32_t i;

  pw_log_debug("%p", node_data->proxy);

  info = node_data->info = pw_node_info_update(node_data->info, info);

  if (info->change_mask & PW_NODE_CHANGE_MASK_PARAMS) {
    for (i = 0; i < info->n_params; i++) {
      uint32_t id = info->params[i].id;

      if (id == SPA_PARAM_EnumFormat &&
          info->params[i].flags & SPA_PARAM_INFO_READ &&
	  node_data->caps == NULL) {
        node_data->caps = gst_caps_new_empty ();
        pw_node_enum_params(node_data->proxy, 0, id, 0, UINT32_MAX, NULL);
        resync(node_data->self);
      }
    }
  }
}

static void node_event_param(void *data, int seq, uint32_t id,
                uint32_t index, uint32_t next, const struct spa_pod *param)
{
  struct node_data *node_data = data;
  GstCaps *c1;

  c1 = gst_caps_from_format (param);
  if (c1 && node_data->caps)
      gst_caps_append (node_data->caps, c1);
}

static const struct pw_node_events node_events = {
  PW_VERSION_NODE_EVENTS,
  .info = node_event_info,
  .param = node_event_param
};

static void
removed_node (void *data)
{
  struct node_data *nd = data;
  pw_proxy_destroy((struct pw_proxy*)nd->proxy);
}

static void
destroy_node (void *data)
{
  struct node_data *nd = data;
  GstPipeWireDeviceProvider *self = nd->self;
  GstDeviceProvider *provider = GST_DEVICE_PROVIDER (self);

  pw_log_debug("destroy %p", nd);

  if (nd->dev != NULL) {
    gst_device_provider_device_remove (provider, GST_DEVICE (nd->dev));
  }
  if (nd->caps)
    gst_caps_unref(nd->caps);
  if (nd->info)
    pw_node_info_free(nd->info);

  spa_list_remove(&nd->link);
}

static const struct pw_proxy_events proxy_node_events = {
  PW_VERSION_PROXY_EVENTS,
  .removed = removed_node,
  .destroy = destroy_node,
};

static void
removed_port (void *data)
{
  struct port_data *pd = data;
  pw_proxy_destroy((struct pw_proxy*)pd->proxy);
}

static void
destroy_port (void *data)
{
  struct port_data *pd = data;
  pw_log_debug("destroy %p", pd);
}

static const struct pw_proxy_events proxy_port_events = {
  PW_VERSION_PROXY_EVENTS,
  .removed = removed_port,
  .destroy = destroy_port,
};

static void registry_event_global(void *data, uint32_t id, uint32_t permissions,
                                const char *type, uint32_t version,
                                const struct spa_dict *props)
{
  struct core_data *rd = data;
  GstPipeWireDeviceProvider *self = rd->self;
  GstDeviceProvider *provider = (GstDeviceProvider*)self;
  struct node_data *nd;
  const char *str;

  if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
    struct pw_node *node;

    node = pw_registry_bind(rd->registry,
                    id, type, PW_VERSION_NODE, sizeof(*nd));
    if (node == NULL)
      goto no_mem;

    if (props != NULL) {
      str = spa_dict_lookup(props, PW_KEY_OBJECT_PATH);
      if (str != NULL) {
	if (g_str_has_prefix(str, "alsa:"))
          gst_device_provider_hide_provider (provider, "pulsedeviceprovider");
	else if (g_str_has_prefix(str, "v4l2:"))
          gst_device_provider_hide_provider (provider, "v4l2deviceprovider");
      }
    }

    nd = pw_proxy_get_user_data((struct pw_proxy*)node);
    nd->self = self;
    nd->proxy = node;
    nd->id = id;
    spa_list_append(&rd->nodes, &nd->link);
    pw_node_add_listener(node, &nd->node_listener, &node_events, nd);
    pw_proxy_add_listener((struct pw_proxy*)node, &nd->proxy_listener, &proxy_node_events, nd);
    resync(self);
  }
  else if (strcmp(type, PW_TYPE_INTERFACE_Port) == 0) {
    struct pw_port *port;
    struct port_data *pd;

    if ((str = spa_dict_lookup(props, PW_KEY_NODE_ID)) == NULL)
      return;

    if ((nd = find_node_data(rd, atoi(str))) == NULL)
      return;

    port = pw_registry_bind(rd->registry,
                    id, type, PW_VERSION_PORT, sizeof(*pd));
    if (port == NULL)
      goto no_mem;

    pd = pw_proxy_get_user_data((struct pw_proxy*)port);
    pd->node_data = nd;
    pd->proxy = port;
    pd->id = id;
    pw_port_add_listener(port, &pd->port_listener, &port_events, pd);
    pw_proxy_add_listener((struct pw_proxy*)port, &pd->proxy_listener, &proxy_port_events, pd);
    resync(self);
  }

  return;

no_mem:
  GST_ERROR_OBJECT(self, "failed to create proxy");
  return;
}

static void registry_event_global_remove(void *data, uint32_t id)
{
}

static const struct pw_registry_events registry_events = {
  PW_VERSION_REGISTRY_EVENTS,
  .global = registry_event_global,
  .global_remove = registry_event_global_remove,
};

static GList *
gst_pipewire_device_provider_probe (GstDeviceProvider * provider)
{
  GstPipeWireDeviceProvider *self = GST_PIPEWIRE_DEVICE_PROVIDER (provider);
  struct pw_loop *l = NULL;
  struct pw_context *c = NULL;
  struct core_data *data;

  GST_DEBUG_OBJECT (self, "starting probe");

  if (!(l = pw_loop_new (NULL)))
    return NULL;

  if (!(c = pw_context_new (l, NULL, sizeof(*data))))
    return NULL;

  data = pw_context_get_user_data(c);
  data->self = self;
  spa_list_init(&data->nodes);

  spa_list_init(&self->pending);
  self->core = pw_context_connect (c, NULL, 0);
  if (self->core == NULL)
    goto failed;

  GST_DEBUG_OBJECT (self, "connected");
  pw_core_add_listener(self->core, &data->core_listener, &core_events, data);

  self->end = FALSE;
  self->list_only = TRUE;
  self->devices = NULL;

  data->registry = pw_core_get_registry(self->core, PW_VERSION_REGISTRY, 0);
  pw_registry_add_listener(data->registry, &data->registry_listener, &registry_events, data);

  resync(self);

  for (;;) {
    if (self->error < 0)
      break;
    if (self->end)
      break;
    pw_loop_iterate (l, -1);
  }

  GST_DEBUG_OBJECT (self, "disconnect");
  pw_proxy_destroy ((struct pw_proxy*)data->registry);
  pw_core_disconnect (self->core);
  self->core = NULL;
  pw_context_destroy (c);
  pw_loop_destroy (l);

  return self->devices;

failed:
  pw_loop_destroy (l);
  return NULL;
}

static gboolean
gst_pipewire_device_provider_start (GstDeviceProvider * provider)
{
  GstPipeWireDeviceProvider *self = GST_PIPEWIRE_DEVICE_PROVIDER (provider);
  struct core_data *data;

  GST_DEBUG_OBJECT (self, "starting provider");

  self->list_only = FALSE;
  spa_list_init(&self->pending);

  if (!(self->loop = pw_thread_loop_new ("pipewire-device-monitor", NULL))) {
    GST_ERROR_OBJECT (self, "Could not create PipeWire mainloop");
    goto failed_loop;
  }

  if (!(self->context = pw_context_new (pw_thread_loop_get_loop(self->loop), NULL, sizeof(*data)))) {
    GST_ERROR_OBJECT (self, "Could not create PipeWire context");
    goto failed_context;
  }

  if (pw_thread_loop_start (self->loop) < 0) {
    GST_ERROR_OBJECT (self, "Could not start PipeWire mainloop");
    goto failed_start;
  }

  pw_thread_loop_lock (self->loop);

  if ((self->core = pw_context_connect (self->context, NULL, 0)) == NULL) {
    GST_ERROR_OBJECT (self, "Failed to connect");
    goto failed_connect;
  }

  GST_DEBUG_OBJECT (self, "connected");

  data = pw_context_get_user_data(self->context);
  data->self = self;
  spa_list_init(&data->nodes);

  pw_core_add_listener(self->core, &data->core_listener, &core_events, data);

  self->registry = pw_core_get_registry(self->core, PW_VERSION_REGISTRY, 0);
  data->registry = self->registry;
  pw_registry_add_listener(self->registry, &data->registry_listener, &registry_events, data);

  resync(self);

  for (;;) {
    if (self->error < 0)
      break;
    if (self->end)
      break;
    pw_thread_loop_wait (self->loop);
  }

  GST_DEBUG_OBJECT (self, "started");

  pw_thread_loop_unlock (self->loop);

  return TRUE;

failed_connect:
  pw_thread_loop_unlock (self->loop);
failed_start:
  pw_context_destroy (self->context);
  self->context = NULL;
failed_context:
  pw_thread_loop_destroy (self->loop);
  self->loop = NULL;
failed_loop:
  return TRUE;
}

static void
gst_pipewire_device_provider_stop (GstDeviceProvider * provider)
{
  GstPipeWireDeviceProvider *self = GST_PIPEWIRE_DEVICE_PROVIDER (provider);

  GST_DEBUG_OBJECT (self, "stopping provider");
  if (self->loop)
    pw_thread_loop_stop (self->loop);

  if (self->registry) {
    pw_proxy_destroy ((struct pw_proxy*)self->registry);
    self->registry = NULL;
  }
  if (self->core) {
    pw_core_disconnect (self->core);
    self->core = NULL;
  }
  if (self->context) {
    pw_context_destroy (self->context);
    self->context = NULL;
  }
  if (self->loop) {
    pw_thread_loop_destroy (self->loop);
    self->loop = NULL;
  }
}

static void
gst_pipewire_device_provider_set_property (GObject * object,
    guint prop_id, const GValue * value, GParamSpec * pspec)
{
  GstPipeWireDeviceProvider *self = GST_PIPEWIRE_DEVICE_PROVIDER (object);

  switch (prop_id) {
    case PROP_CLIENT_NAME:
      g_free (self->client_name);
      if (!g_value_get_string (value)) {
        GST_WARNING_OBJECT (self,
            "Empty PipeWire client name not allowed. "
            "Resetting to default value");
        self->client_name = g_strdup(pw_get_client_name ());
      } else
        self->client_name = g_value_dup_string (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_pipewire_device_provider_get_property (GObject * object,
    guint prop_id, GValue * value, GParamSpec * pspec)
{
  GstPipeWireDeviceProvider *self = GST_PIPEWIRE_DEVICE_PROVIDER (object);

  switch (prop_id) {
    case PROP_CLIENT_NAME:
      g_value_set_string (value, self->client_name);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
}

static void
gst_pipewire_device_provider_finalize (GObject * object)
{
  GstPipeWireDeviceProvider *self = GST_PIPEWIRE_DEVICE_PROVIDER (object);

  g_free (self->client_name);

  G_OBJECT_CLASS (gst_pipewire_device_provider_parent_class)->finalize (object);
}

static void
gst_pipewire_device_provider_class_init (GstPipeWireDeviceProviderClass * klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);
  GstDeviceProviderClass *dm_class = GST_DEVICE_PROVIDER_CLASS (klass);

  gobject_class->set_property = gst_pipewire_device_provider_set_property;
  gobject_class->get_property = gst_pipewire_device_provider_get_property;
  gobject_class->finalize = gst_pipewire_device_provider_finalize;

  dm_class->probe = gst_pipewire_device_provider_probe;
  dm_class->start = gst_pipewire_device_provider_start;
  dm_class->stop = gst_pipewire_device_provider_stop;

  g_object_class_install_property (gobject_class,
      PROP_CLIENT_NAME,
      g_param_spec_string ("client-name", "Client Name",
          "The PipeWire client_name_to_use", pw_get_client_name (),
          G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS |
          GST_PARAM_MUTABLE_READY));

  gst_device_provider_class_set_static_metadata (dm_class,
      "PipeWire Device Provider", "Sink/Source/Audio/Video",
      "List and provide PipeWire source and sink devices",
      "Wim Taymans <wim.taymans@gmail.com>");
}

static void
gst_pipewire_device_provider_init (GstPipeWireDeviceProvider * self)
{
  self->client_name = g_strdup(pw_get_client_name ());
}
