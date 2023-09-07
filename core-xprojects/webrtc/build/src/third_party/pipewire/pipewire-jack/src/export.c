/* PipeWire
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
 */

#include <spa/utils/defs.h>

#define JACK_METADATA_PREFIX "http://jackaudio.org/metadata/"
SPA_EXPORT const char *JACK_METADATA_CONNECTED   = JACK_METADATA_PREFIX "connected";
SPA_EXPORT const char *JACK_METADATA_EVENT_TYPES = JACK_METADATA_PREFIX "event-types";
SPA_EXPORT const char *JACK_METADATA_HARDWARE    = JACK_METADATA_PREFIX "hardware";
SPA_EXPORT const char *JACK_METADATA_ICON_LARGE  = JACK_METADATA_PREFIX "icon-large";
SPA_EXPORT const char *JACK_METADATA_ICON_NAME   = JACK_METADATA_PREFIX "icon-name";
SPA_EXPORT const char *JACK_METADATA_ICON_SMALL  = JACK_METADATA_PREFIX "icon-small";
SPA_EXPORT const char *JACK_METADATA_ORDER       = JACK_METADATA_PREFIX "order";
SPA_EXPORT const char *JACK_METADATA_PORT_GROUP  = JACK_METADATA_PREFIX "port-group";
SPA_EXPORT const char *JACK_METADATA_PRETTY_NAME = JACK_METADATA_PREFIX "pretty-name";
SPA_EXPORT const char *JACK_METADATA_SIGNAL_TYPE = JACK_METADATA_PREFIX "signal-type";
#undef JACK_METADATA_PREFIX
