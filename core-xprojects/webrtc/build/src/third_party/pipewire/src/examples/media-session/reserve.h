/* DBus device reservation API
 *
 * Copyright © 2019 Wim Taymans
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

#ifndef DEVICE_RESERVE_H
#define DEVICE_RESERVE_H

#include <dbus/dbus.h>
#include <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif

struct rd_device;

struct rd_device_callbacks {
	/** the device is acquired by us */
	void (*acquired) (void *data, struct rd_device *d);
	/** request a release of the device */
	void (*release) (void *data, struct rd_device *d, int forced);
	/** the device is busy by someone else */
	void (*busy) (void *data, struct rd_device *d, const char *name, int32_t priority);
	/** the device is made available by someone else */
	void (*available) (void *data, struct rd_device *d, const char *name);
};

/* create a new device and start watching */
struct rd_device *
rd_device_new(DBusConnection *connection,		/**< Bus to watch */
		const char *device_name,		/**< The device to lock, e.g. "Audio0" */
		const char *application_name,		/**< A human readable name of the application,
							  *  e.g. "PipeWire Server" */
		int32_t priority,			/**< The priority for this application.
							  *  If unsure use 0 */
		const struct rd_device_callbacks *callbacks,	/**< Called when device name is acquired/released */
		void *data);

/** try to acquire the device */
int rd_device_acquire(struct rd_device *d);

/** request the owner to release the device */
int rd_device_request_release(struct rd_device *d);

/** complete the release of the device */
int rd_device_complete_release(struct rd_device *d, int res);

/** release a device */
void rd_device_release(struct rd_device *d);

/** destroy a device */
void rd_device_destroy(struct rd_device *d);

/* Set the application device name for an rd_device object. Returns 0
 * on success, a negative errno style return value on error. */
int rd_device_set_application_device_name(struct rd_device *d, const char *name);

#ifdef __cplusplus
}
#endif

#endif
