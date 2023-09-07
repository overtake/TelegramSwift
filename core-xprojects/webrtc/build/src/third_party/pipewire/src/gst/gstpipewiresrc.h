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

#ifndef __GST_PIPEWIRE_SRC_H__
#define __GST_PIPEWIRE_SRC_H__

#include <gst/gst.h>
#include <gst/base/gstpushsrc.h>

#include <pipewire/pipewire.h>
#include <gst/gstpipewirepool.h>
#include <gst/gstpipewirecore.h>

G_BEGIN_DECLS

#define GST_TYPE_PIPEWIRE_SRC \
  (gst_pipewire_src_get_type())
#define GST_PIPEWIRE_SRC(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_PIPEWIRE_SRC,GstPipeWireSrc))
#define GST_PIPEWIRE_SRC_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass),GST_TYPE_PIPEWIRE_SRC,GstPipeWireSrcClass))
#define GST_IS_PIPEWIRE_SRC(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_PIPEWIRE_SRC))
#define GST_IS_PIPEWIRE_SRC_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass),GST_TYPE_PIPEWIRE_SRC))
#define GST_PIPEWIRE_SRC_CAST(obj) \
  ((GstPipeWireSrc *) (obj))

typedef struct _GstPipeWireSrc GstPipeWireSrc;
typedef struct _GstPipeWireSrcClass GstPipeWireSrcClass;

/**
 * GstPipeWireSrc:
 *
 * Opaque data structure.
 */
struct _GstPipeWireSrc {
  GstPushSrc element;

  /*< private >*/
  gchar *path;
  gchar *client_name;
  gboolean always_copy;
  gint min_buffers;
  gint max_buffers;
  int fd;
  gboolean resend_last;
  gint keepalive_time;

  GstCaps *caps;

  gboolean negotiated;
  gboolean flushing;
  gboolean started;
  gboolean eos;

  gboolean is_live;
  GstClockTime min_latency;
  GstClockTime max_latency;

  GstPipeWireCore *core;
  struct spa_hook core_listener;
  int last_seq;
  int pending_seq;

  struct pw_stream *stream;
  struct spa_hook stream_listener;

  GstBuffer *last_buffer;
  GstStructure *properties;

  GstPipeWirePool *pool;
  GstClock *clock;
  GstClockTime last_time;
};

struct _GstPipeWireSrcClass {
  GstPushSrcClass parent_class;
};

GType gst_pipewire_src_get_type (void);

G_END_DECLS

#endif /* __GST_PIPEWIRE_SRC_H__ */
