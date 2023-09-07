/* Simple Plugin API
 * Copyright © 2018 Collabora Ltd.
 *   @author George Kiagiadakis <george.kiagiadakis@collabora.com>
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

#include <spa/buffer/alloc.h>
#include <spa/buffer/buffer.h>
#include <spa/buffer/meta.h>
#include <spa/debug/buffer.h>
#include <spa/debug/dict.h>
#include <spa/debug/format.h>
#include <spa/debug/mem.h>
#include <spa/debug/node.h>
#include <spa/debug/pod.h>
#include <spa/debug/types.h>
#include <spa/graph/graph.h>
#include <spa/monitor/device.h>
#include <spa/node/command.h>
#include <spa/node/event.h>
#include <spa/node/io.h>
#include <spa/node/node.h>
#include <spa/param/format.h>
#include <spa/param/format-utils.h>
#include <spa/param/param.h>
#include <spa/param/props.h>
#include <spa/param/audio/format.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/audio/layout.h>
#include <spa/param/audio/raw.h>
#include <spa/param/video/chroma.h>
#include <spa/param/video/color.h>
#include <spa/param/video/encoded.h>
#include <spa/param/video/format.h>
#include <spa/param/video/format-utils.h>
#include <spa/param/video/multiview.h>
#include <spa/param/video/raw.h>
#include <spa/pod/builder.h>
#include <spa/pod/command.h>
#include <spa/pod/compare.h>
#include <spa/pod/event.h>
#include <spa/pod/filter.h>
#include <spa/pod/iter.h>
#include <spa/pod/parser.h>
#include <spa/pod/pod.h>
#include <spa/pod/vararg.h>
#include <spa/support/cpu.h>
#include <spa/support/dbus.h>
#include <spa/support/log.h>
#include <spa/support/log-impl.h>
#include <spa/support/loop.h>
#include <spa/support/plugin.h>
#include <spa/utils/defs.h>
#include <spa/utils/dict.h>
#include <spa/utils/hook.h>
#include <spa/utils/list.h>
#include <spa/utils/ringbuffer.h>
#include <spa/utils/type.h>

int main(int argc, char *argv[])
{
    return 0;
}
