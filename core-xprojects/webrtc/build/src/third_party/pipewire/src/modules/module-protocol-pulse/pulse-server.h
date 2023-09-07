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
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#ifndef PIPEWIRE_PROTOCOL_PULSE_H
#define PIPEWIRE_PROTOCOL_PULSE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <spa/utils/defs.h>
#include <spa/utils/hook.h>

#define PW_PROTOCOL_PULSE_DEFAULT_PORT 4713
#define PW_PROTOCOL_PULSE_DEFAULT_SOCKET "native"

#define PW_PROTOCOL_PULSE_DEFAULT_SERVER "unix:"PW_PROTOCOL_PULSE_DEFAULT_SOCKET

#define PW_PROTOCOL_PULSE_USAGE	"[ server.address=(tcp:[<ip>:]<port>|unix:<path>)[,...] ] "		\

struct pw_protocol_pulse;
struct pw_protocol_pulse_server;

struct pw_protocol_pulse *pw_protocol_pulse_new(struct pw_context *context,
		struct pw_properties *props, size_t user_data_size);
void *pw_protocol_pulse_get_user_data(struct pw_protocol_pulse *pulse);
void pw_protocol_pulse_destroy(struct pw_protocol_pulse *pulse);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* PIPEWIRE_PROTOCOL_PULSE_H */
