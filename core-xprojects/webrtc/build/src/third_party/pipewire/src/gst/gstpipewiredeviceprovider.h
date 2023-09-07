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


#ifndef __GST_PIPEWIRE_DEVICE_PROVIDER_H__
#define __GST_PIPEWIRE_DEVICE_PROVIDER_H__

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <pipewire/pipewire.h>

#include <gst/gst.h>

G_BEGIN_DECLS

typedef struct _GstPipeWireDevice GstPipeWireDevice;
typedef struct _GstPipeWireDeviceClass GstPipeWireDeviceClass;

#define GST_TYPE_PIPEWIRE_DEVICE                 (gst_pipewire_device_get_type())
#define GST_IS_PIPEWIRE_DEVICE(obj)              (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GST_TYPE_PIPEWIRE_DEVICE))
#define GST_IS_PIPEWIRE_DEVICE_CLASS(klass)      (G_TYPE_CHECK_CLASS_TYPE ((klass), GST_TYPE_PIPEWIRE_DEVICE))
#define GST_PIPEWIRE_DEVICE_GET_CLASS(obj)       (G_TYPE_INSTANCE_GET_CLASS ((obj), GST_TYPE_PIPEWIRE_DEVICE, GstPipeWireDeviceClass))
#define GST_PIPEWIRE_DEVICE(obj)                 (G_TYPE_CHECK_INSTANCE_CAST ((obj), GST_TYPE_PIPEWIRE_DEVICE, GstPipeWireDevice))
#define GST_PIPEWIRE_DEVICE_CLASS(klass)         (G_TYPE_CHECK_CLASS_CAST ((klass), GST_TYPE_DEVICE, GstPipeWireDeviceClass))
#define GST_PIPEWIRE_DEVICE_CAST(obj)            ((GstPipeWireDevice *)(obj))

typedef enum {
  GST_PIPEWIRE_DEVICE_TYPE_UNKNOWN,
  GST_PIPEWIRE_DEVICE_TYPE_SOURCE,
  GST_PIPEWIRE_DEVICE_TYPE_SINK,
} GstPipeWireDeviceType;

struct _GstPipeWireDevice {
  GstDevice           parent;

  GstPipeWireDeviceType  type;
  uint32_t            id;
  const gchar        *element;
};

struct _GstPipeWireDeviceClass {
  GstDeviceClass    parent_class;
};

GType        gst_pipewire_device_get_type (void);

typedef struct _GstPipeWireDeviceProvider GstPipeWireDeviceProvider;
typedef struct _GstPipeWireDeviceProviderClass GstPipeWireDeviceProviderClass;

#define GST_TYPE_PIPEWIRE_DEVICE_PROVIDER                 (gst_pipewire_device_provider_get_type())
#define GST_IS_PIPEWIRE_DEVICE_PROVIDER(obj)              (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GST_TYPE_PIPEWIRE_DEVICE_PROVIDER))
#define GST_IS_PIPEWIRE_DEVICE_PROVIDER_CLASS(klass)      (G_TYPE_CHECK_CLASS_TYPE ((klass), GST_TYPE_PIPEWIRE_DEVICE_PROVIDER))
#define GST_PIPEWIRE_DEVICE_PROVIDER_GET_CLASS(obj)       (G_TYPE_INSTANCE_GET_CLASS ((obj), GST_TYPE_PIPEWIRE_DEVICE_PROVIDER, GstPipeWireDeviceProviderClass))
#define GST_PIPEWIRE_DEVICE_PROVIDER(obj)                 (G_TYPE_CHECK_INSTANCE_CAST ((obj), GST_TYPE_PIPEWIRE_DEVICE_PROVIDER, GstPipeWireDeviceProvider))
#define GST_PIPEWIRE_DEVICE_PROVIDER_CLASS(klass)         (G_TYPE_CHECK_CLASS_CAST ((klass), GST_TYPE_DEVICE_PROVIDER, GstPipeWireDeviceProviderClass))
#define GST_PIPEWIRE_DEVICE_PROVIDER_CAST(obj)            ((GstPipeWireDeviceProvider *)(obj))

struct _GstPipeWireDeviceProvider {
  GstDeviceProvider         parent;

  gchar *client_name;

  struct pw_thread_loop *loop;

  struct pw_context *context;

  struct pw_core *core;
  struct spa_list pending;
  int seq;

  struct pw_registry *registry;

  int error;
  gboolean end;
  gboolean list_only;
  GList *devices;
};

struct _GstPipeWireDeviceProviderClass {
  GstDeviceProviderClass    parent_class;
};

GType        gst_pipewire_device_provider_get_type (void);

G_END_DECLS

#endif /* __GST_PIPEWIRE_DEVICE_PROVIDER_H__ */
