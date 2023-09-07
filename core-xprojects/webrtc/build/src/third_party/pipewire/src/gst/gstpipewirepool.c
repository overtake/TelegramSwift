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

#include <unistd.h>

#include <gst/gst.h>

#include <gst/allocators/gstfdmemory.h>
#include <gst/allocators/gstdmabuf.h>

#include <gst/video/gstvideometa.h>

#include "gstpipewirepool.h"

GST_DEBUG_CATEGORY_STATIC (gst_pipewire_pool_debug_category);
#define GST_CAT_DEFAULT gst_pipewire_pool_debug_category

G_DEFINE_TYPE (GstPipeWirePool, gst_pipewire_pool, GST_TYPE_BUFFER_POOL);

enum
{
  ACTIVATED,
  /* FILL ME */
  LAST_SIGNAL
};


static guint pool_signals[LAST_SIGNAL] = { 0 };

static GQuark pool_data_quark;

GstPipeWirePool *
gst_pipewire_pool_new (void)
{
  GstPipeWirePool *pool;

  pool = g_object_new (GST_TYPE_PIPEWIRE_POOL, NULL);

  return pool;
}

static void
pool_data_destroy (gpointer user_data)
{
  GstPipeWirePoolData *data = user_data;

  gst_object_unref (data->pool);
  g_slice_free (GstPipeWirePoolData, data);
}

void gst_pipewire_pool_wrap_buffer (GstPipeWirePool *pool, struct pw_buffer *b)
{
  GstBuffer *buf;
  uint32_t i;
  GstPipeWirePoolData *data;

  GST_LOG_OBJECT (pool, "wrap buffer");

  data = g_slice_new (GstPipeWirePoolData);

  buf = gst_buffer_new ();

  for (i = 0; i < b->buffer->n_datas; i++) {
    struct spa_data *d = &b->buffer->datas[i];
    GstMemory *gmem = NULL;

    GST_LOG_OBJECT (pool, "wrap buffer %d %d", d->mapoffset, d->maxsize);
    if (d->type == SPA_DATA_MemFd) {
      gmem = gst_fd_allocator_alloc (pool->fd_allocator, d->fd,
                d->mapoffset + d->maxsize, GST_FD_MEMORY_FLAG_DONT_CLOSE);
      gst_memory_resize (gmem, d->mapoffset, d->maxsize);
      data->offset = d->mapoffset;
    }
    else if(d->type == SPA_DATA_DmaBuf) {
      gmem = gst_fd_allocator_alloc (pool->dmabuf_allocator, d->fd,
                d->mapoffset + d->maxsize, GST_FD_MEMORY_FLAG_DONT_CLOSE);
      gst_memory_resize (gmem, d->mapoffset, d->maxsize);
      data->offset = d->mapoffset;
    }
    else if (d->type == SPA_DATA_MemPtr) {
      gmem = gst_memory_new_wrapped (GST_MEMORY_FLAG_NO_SHARE, d->data, d->maxsize, 0,
                                     d->maxsize, NULL, NULL);
      data->offset = 0;
    }
    if (gmem)
      gst_buffer_append_memory (buf, gmem);
  }

  data->pool = gst_object_ref (pool);
  data->owner = NULL;
  data->header = spa_buffer_find_meta_data (b->buffer, SPA_META_Header, sizeof(*data->header));
  data->flags = GST_BUFFER_FLAGS (buf);
  data->b = b;
  data->buf = buf;
  data->crop = spa_buffer_find_meta_data (b->buffer, SPA_META_VideoCrop, sizeof(*data->crop));
  if (data->crop)
	  gst_buffer_add_video_crop_meta(buf);

  gst_mini_object_set_qdata (GST_MINI_OBJECT_CAST (buf),
                             pool_data_quark,
                             data,
                             pool_data_destroy);
  b->user_data = data;
}

GstPipeWirePoolData *gst_pipewire_pool_get_data (GstBuffer *buffer)
{
  return gst_mini_object_get_qdata (GST_MINI_OBJECT_CAST (buffer), pool_data_quark);
}

#if 0
gboolean
gst_pipewire_pool_add_buffer (GstPipeWirePool *pool, GstBuffer *buffer)
{
  g_return_val_if_fail (GST_IS_PIPEWIRE_POOL (pool), FALSE);
  g_return_val_if_fail (GST_IS_BUFFER (buffer), FALSE);

  GST_OBJECT_LOCK (pool);
  g_queue_push_tail (&pool->available, buffer);
  g_cond_signal (&pool->cond);
  GST_OBJECT_UNLOCK (pool);

  return TRUE;
}

gboolean
gst_pipewire_pool_remove_buffer (GstPipeWirePool *pool, GstBuffer *buffer)
{
  gboolean res;

  g_return_val_if_fail (GST_IS_PIPEWIRE_POOL (pool), FALSE);
  g_return_val_if_fail (GST_IS_BUFFER (buffer), FALSE);

  GST_OBJECT_LOCK (pool);
  res = g_queue_remove (&pool->available, buffer);
  GST_OBJECT_UNLOCK (pool);

  return res;
}
#endif

static GstFlowReturn
acquire_buffer (GstBufferPool * pool, GstBuffer ** buffer,
        GstBufferPoolAcquireParams * params)
{
  GstPipeWirePool *p = GST_PIPEWIRE_POOL (pool);
  GstPipeWirePoolData *data;
  struct pw_buffer *b;

  GST_OBJECT_LOCK (pool);
  while (TRUE) {
    if (G_UNLIKELY (GST_BUFFER_POOL_IS_FLUSHING (pool)))
      goto flushing;

    if ((b = pw_stream_dequeue_buffer(p->stream)))
      break;

    if (params && (params->flags & GST_BUFFER_POOL_ACQUIRE_FLAG_DONTWAIT))
      goto no_more_buffers;

    GST_WARNING ("queue empty");
    g_cond_wait (&p->cond, GST_OBJECT_GET_LOCK (pool));
  }

  data = b->user_data;
  *buffer = data->buf;

  GST_OBJECT_UNLOCK (pool);
  GST_DEBUG ("acquire buffer %p", *buffer);

  return GST_FLOW_OK;

flushing:
  {
    GST_OBJECT_UNLOCK (pool);
    return GST_FLOW_FLUSHING;
  }
no_more_buffers:
  {
    GST_LOG_OBJECT (pool, "no more buffers");
    GST_OBJECT_UNLOCK (pool);
    return GST_FLOW_EOS;
  }
}

static void
flush_start (GstBufferPool * pool)
{
  GstPipeWirePool *p = GST_PIPEWIRE_POOL (pool);

  GST_DEBUG ("flush start");
  GST_OBJECT_LOCK (pool);
  g_cond_signal (&p->cond);
  GST_OBJECT_UNLOCK (pool);
}

static void
release_buffer (GstBufferPool * pool, GstBuffer *buffer)
{
  GST_DEBUG ("release buffer %p", buffer);
}

static gboolean
do_start (GstBufferPool * pool)
{
  g_signal_emit (pool, pool_signals[ACTIVATED], 0, NULL);
  return TRUE;
}

static void
gst_pipewire_pool_finalize (GObject * object)
{
  GstPipeWirePool *pool = GST_PIPEWIRE_POOL (object);

  GST_DEBUG_OBJECT (pool, "finalize");
  g_object_unref (pool->fd_allocator);
  g_object_unref (pool->dmabuf_allocator);

  G_OBJECT_CLASS (gst_pipewire_pool_parent_class)->finalize (object);
}

static void
gst_pipewire_pool_class_init (GstPipeWirePoolClass * klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);
  GstBufferPoolClass *bufferpool_class = GST_BUFFER_POOL_CLASS (klass);

  gobject_class->finalize = gst_pipewire_pool_finalize;

  bufferpool_class->start = do_start;
  bufferpool_class->flush_start = flush_start;
  bufferpool_class->acquire_buffer = acquire_buffer;
  bufferpool_class->release_buffer = release_buffer;

  pool_signals[ACTIVATED] =
      g_signal_new ("activated", G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST,
      0, NULL, NULL, g_cclosure_marshal_generic, G_TYPE_NONE, 0, G_TYPE_NONE);

  GST_DEBUG_CATEGORY_INIT (gst_pipewire_pool_debug_category, "pipewirepool", 0,
      "debug category for pipewirepool object");

  pool_data_quark = g_quark_from_static_string ("GstPipeWirePoolDataQuark");
}

static void
gst_pipewire_pool_init (GstPipeWirePool * pool)
{
  pool->fd_allocator = gst_fd_allocator_new ();
  pool->dmabuf_allocator = gst_dmabuf_allocator_new ();
  g_cond_init (&pool->cond);
}
