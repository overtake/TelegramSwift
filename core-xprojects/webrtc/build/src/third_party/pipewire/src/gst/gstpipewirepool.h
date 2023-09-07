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

#ifndef __GST_PIPEWIRE_POOL_H__
#define __GST_PIPEWIRE_POOL_H__

#include <gst/gst.h>

#include <pipewire/pipewire.h>

G_BEGIN_DECLS

#define GST_TYPE_PIPEWIRE_POOL \
  (gst_pipewire_pool_get_type())
#define GST_PIPEWIRE_POOL(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_PIPEWIRE_POOL,GstPipeWirePool))
#define GST_PIPEWIRE_POOL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass),GST_TYPE_PIPEWIRE_POOL,GstPipeWirePoolClass))
#define GST_IS_PIPEWIRE_POOL(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_PIPEWIRE_POOL))
#define GST_IS_PIPEWIRE_POOL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass),GST_TYPE_PIPEWIRE_POOL))
#define GST_PIPEWIRE_POOL_GET_CLASS(klass) \
  (G_TYPE_INSTANCE_GET_CLASS ((klass), GST_TYPE_PIPEWIRE_POOL, GstPipeWirePoolClass))

typedef struct _GstPipeWirePoolData GstPipeWirePoolData;
typedef struct _GstPipeWirePool GstPipeWirePool;
typedef struct _GstPipeWirePoolClass GstPipeWirePoolClass;

struct _GstPipeWirePoolData {
  GstPipeWirePool *pool;
  void *owner;
  struct spa_meta_header *header;
  guint flags;
  goffset offset;
  struct pw_buffer *b;
  GstBuffer *buf;
  gboolean queued;
  struct spa_meta_region *crop;
};

struct _GstPipeWirePool {
  GstBufferPool parent;

  struct pw_stream *stream;
  struct pw_type *t;

  GstAllocator *fd_allocator;
  GstAllocator *dmabuf_allocator;

  GCond cond;
};

struct _GstPipeWirePoolClass {
  GstBufferPoolClass parent_class;
};

GType gst_pipewire_pool_get_type (void);

GstPipeWirePool *  gst_pipewire_pool_new           (void);

void gst_pipewire_pool_wrap_buffer (GstPipeWirePool *pool, struct pw_buffer *buffer);

GstPipeWirePoolData *gst_pipewire_pool_get_data (GstBuffer *buffer);

//gboolean        gst_pipewire_pool_add_buffer    (GstPipeWirePool *pool, GstBuffer *buffer);
//gboolean        gst_pipewire_pool_remove_buffer (GstPipeWirePool *pool, GstBuffer *buffer);

G_END_DECLS

#endif /* __GST_PIPEWIRE_POOL_H__ */
