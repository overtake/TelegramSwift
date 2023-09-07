/* PipeWire
 *
 * Copyright © 2020 Georges Basile Stavracas Neto
 * Copyright © 2021 Wim Taymans <wim.taymans@gmail.com>
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

#ifndef PIPEWIRE_PULSE_MODULE_H
#define PIPEWIRE_PULSE_MODULE_H

#include <spa/param/audio/raw.h>

#include "internal.h"

struct module;

struct module_info {
	const char *name;
	struct module *(*create) (struct impl *impl, const char *args);
};

struct module_events {
#define VERSION_MODULE_EVENTS	0
	uint32_t version;

	void (*loaded) (void *data, int res);
};

#define module_emit_loaded(m,r) spa_hook_list_call(&m->hooks, struct module_events, loaded, 0, r)

struct module_methods {
#define VERSION_MODULE_METHODS	0
	uint32_t version;

	int (*load) (struct client *client, struct module *module);
	int (*unload) (struct client *client, struct module *module);
};

struct module {
	uint32_t idx;
	const char *name;
	const char *args;
	struct pw_properties *props;
	struct spa_list link;           /**< link in client modules */
	struct impl *impl;
	const struct module_methods *methods;
	struct spa_hook_list hooks;
	void *user_data;
};

struct module *module_new(struct impl *impl, const struct module_methods *methods, size_t user_data);
void module_schedule_unload(struct module *module);

void module_args_add_props(struct pw_properties *props, const char *str);
int module_args_to_audioinfo(struct impl *impl, struct pw_properties *props, struct spa_audio_info_raw *info);

#endif
