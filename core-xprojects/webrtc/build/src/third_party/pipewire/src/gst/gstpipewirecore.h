/* GStreamer
 *
 * Copyright © 2020 Wim Taymans
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

#ifndef __GST_PIPEWIRE_CORE_H__
#define __GST_PIPEWIRE_CORE_H__

#include <gst/gst.h>

#include <pipewire/pipewire.h>

G_BEGIN_DECLS

typedef struct _GstPipeWireCore GstPipeWireCore;

/**
 * GstPipeWireCore:
 *
 * Opaque data structure.
 */
struct _GstPipeWireCore {
  gint refcount;
  int fd;
  struct pw_thread_loop *loop;
  struct pw_context *context;
  struct pw_core *core;
  struct spa_hook core_listener;
  int last_error;
  int last_seq;
  int pending_seq;
};

GstPipeWireCore *gst_pipewire_core_get     (int fd);
void             gst_pipewire_core_release (GstPipeWireCore *core);

G_END_DECLS

#endif /* __GST_PIPEWIRE_CORE_H__ */
