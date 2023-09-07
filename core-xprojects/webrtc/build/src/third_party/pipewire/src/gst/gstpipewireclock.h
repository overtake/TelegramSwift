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

#ifndef __GST_PIPEWIRE_CLOCK_H__
#define __GST_PIPEWIRE_CLOCK_H__

#include <gst/gst.h>

#include <pipewire/pipewire.h>

G_BEGIN_DECLS

#define GST_TYPE_PIPEWIRE_CLOCK \
  (gst_pipewire_clock_get_type())
#define GST_PIPEWIRE_CLOCK(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj),GST_TYPE_PIPEWIRE_CLOCK,GstPipeWireClock))
#define GST_PIPEWIRE_CLOCK_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass),GST_TYPE_PIPEWIRE_CLOCK,GstPipeWireClockClass))
#define GST_IS_PIPEWIRE_CLOCK(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj),GST_TYPE_PIPEWIRE_CLOCK))
#define GST_IS_PIPEWIRE_CLOCK_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass),GST_TYPE_PIPEWIRE_CLOCK))
#define GST_PIPEWIRE_CLOCK_GET_CLASS(klass) \
  (G_TYPE_INSTANCE_GET_CLASS ((klass), GST_TYPE_PIPEWIRE_CLOCK, GstPipeWireClockClass))

typedef struct _GstPipeWireClock GstPipeWireClock;
typedef struct _GstPipeWireClockClass GstPipeWireClockClass;

struct _GstPipeWireClock {
  GstSystemClock parent;

  struct pw_stream *stream;
  GstClockTime last_time;
  GstClockTimeDiff time_offset;
};

struct _GstPipeWireClockClass {
  GstSystemClockClass parent_class;
};

GType gst_pipewire_clock_get_type (void);

GstClock *      gst_pipewire_clock_new           (struct pw_stream *stream,
                                                  GstClockTime last_time);
void            gst_pipewire_clock_reset         (GstPipeWireClock *clock,
                                                  GstClockTime time);

G_END_DECLS

#endif /* __GST_PIPEWIRE_CLOCK_H__ */
