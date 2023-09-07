/* PipeWire
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

#ifndef PIPEWIRE_SPA_DEVICE_H
#define PIPEWIRE_SPA_DEVICE_H

#include <spa/monitor/device.h>

#include <pipewire/impl.h>

#ifdef __cplusplus
extern "C" {
#endif

enum pw_spa_device_flags {
	PW_SPA_DEVICE_FLAG_DISABLE	= (1 << 0),
	PW_SPA_DEVICE_FLAG_NO_REGISTER	= (1 << 1),
};

struct pw_impl_device *
pw_spa_device_new(struct pw_context *context,
		  enum pw_spa_device_flags flags,
		  struct spa_device *device,
		  struct spa_handle *handle,
		  struct pw_properties *properties,
		  size_t user_data_size);

struct pw_impl_device *
pw_spa_device_load(struct pw_context *context,
		   const char *factory_name,
		   enum pw_spa_device_flags flags,
		   struct pw_properties *properties,
		   size_t user_data_size);

void *pw_spa_device_get_user_data(struct pw_impl_device *device);

#ifdef __cplusplus
}
#endif

#endif /* PIPEWIRE_SPA_DEVICE_H */
