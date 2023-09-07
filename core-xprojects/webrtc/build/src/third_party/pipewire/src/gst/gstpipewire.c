/* PipeWire GStreamer Elements
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
 * gst-launch -v pipewiresrc ! ximagesink
 * ]| Shows PipeWire output in an X window.
 * </refsect2>
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "gstpipewiresrc.h"
#include "gstpipewiresink.h"
#include "gstpipewiredeviceprovider.h"

GST_DEBUG_CATEGORY (pipewire_debug);

static gboolean
plugin_init (GstPlugin *plugin)
{
  pw_init (NULL, NULL);

  gst_element_register (plugin, "pipewiresrc", GST_RANK_PRIMARY + 1,
      GST_TYPE_PIPEWIRE_SRC);
  gst_element_register (plugin, "pipewiresink", GST_RANK_NONE,
      GST_TYPE_PIPEWIRE_SINK);

#if HAVE_GSTREAMER_DEVICE_PROVIDER
  if (!gst_device_provider_register (plugin, "pipewiredeviceprovider",
       GST_RANK_PRIMARY + 1, GST_TYPE_PIPEWIRE_DEVICE_PROVIDER))
    return FALSE;
#endif

  GST_DEBUG_CATEGORY_INIT (pipewire_debug, "pipewire", 0, "PipeWire elements");

  return TRUE;
}

GST_PLUGIN_DEFINE (GST_VERSION_MAJOR,
    GST_VERSION_MINOR,
    pipewire,
    "Uses PipeWire to handle media streams",
    plugin_init, VERSION, "MIT/X11", "pipewire", "pipewire.org")
