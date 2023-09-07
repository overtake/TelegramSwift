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

#ifndef __GST_PIPEWIRE_SINK_H__
#define __GST_PIPEWIRE_SINK_H__

#include <gst/gst.h>
#include <gst/base/gstbasesink.h>

#include <pipewire/pipewire.h>
#include <gst/gstpipewirepool.h>
#include <gst/gstpipewirecore.h>

G_BEGIN_DECLS

#define GST_TYPE_PIPEWIRE_SINK \
  (gst_pipewire_sink_get_type())
#define GST_PIPEWIRE_SINK(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_PIPEWIRE_SINK,GstPipeWireSink))
#define GST_PIPEWIRE_SINK_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass),GST_TYPE_PIPEWIRE_SINK,GstPipeWireSinkClass))
#define GST_IS_PIPEWIRE_SINK(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_PIPEWIRE_SINK))
#define GST_IS_PIPEWIRE_SINK_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass),GST_TYPE_PIPEWIRE_SINK))
#define GST_PIPEWIRE_SINK_CAST(obj) \
  ((GstPipeWireSink *) (obj))

typedef struct _GstPipeWireSink GstPipeWireSink;
typedef struct _GstPipeWireSinkClass GstPipeWireSinkClass;


/**
 * GstPipeWireSinkMode:
 * @GST_PIPEWIRE_SINK_MODE_DEFAULT: the default mode as configured in the server
 * @GST_PIPEWIRE_SINK_MODE_RENDER: try to render the media
 * @GST_PIPEWIRE_SINK_MODE_PROVIDE: provide the media
 *
 * Different modes of operation.
 */
typedef enum
{
  GST_PIPEWIRE_SINK_MODE_DEFAULT,
  GST_PIPEWIRE_SINK_MODE_RENDER,
  GST_PIPEWIRE_SINK_MODE_PROVIDE,
} GstPipeWireSinkMode;

#define GST_TYPE_PIPEWIRE_SINK_MODE (gst_pipewire_sink_mode_get_type ())

/**
 * GstPipeWireSink:
 *
 * Opaque data structure.
 */
struct _GstPipeWireSink {
  GstBaseSink element;

  /*< private >*/
  gchar *path;
  gchar *client_name;
  int fd;

  /* video state */
  gboolean negotiated;

  GstPipeWireCore *core;
  struct spa_hook core_listener;

  struct pw_stream *stream;
  struct spa_hook stream_listener;

  GstStructure *properties;
  GstPipeWireSinkMode mode;

  GstPipeWirePool *pool;
};

struct _GstPipeWireSinkClass {
  GstBaseSinkClass parent_class;
};

GType gst_pipewire_sink_get_type (void);
GType gst_pipewire_sink_mode_get_type (void);

G_END_DECLS

#endif /* __GST_PIPEWIRE_SINK_H__ */
