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

#ifndef PIPEWIRE_MANAGER_H
#define PIPEWIRE_MANAGER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <spa/utils/defs.h>
#include <spa/pod/pod.h>

#include <pipewire/pipewire.h>

struct pw_manager_object;

struct pw_manager_events {
#define PW_VERSION_MANAGER_EVENTS	0
	uint32_t version;

	void (*destroy) (void *data);

	void (*sync) (void *data);

	void (*added) (void *data, struct pw_manager_object *object);

	void (*updated) (void *data, struct pw_manager_object *object);

	void (*removed) (void *data, struct pw_manager_object *object);

	void (*metadata) (void *data, struct pw_manager_object *object,
			uint32_t subject, const char *key,
			const char *type, const char *value);
};

struct pw_manager {
	struct pw_core *core;
	struct pw_registry *registry;

	struct pw_core_info *info;

	uint32_t n_objects;
	struct spa_list object_list;
};

struct pw_manager_param {
	uint32_t id;
	struct spa_list link;           /**< link in manager_object param_list */
	struct spa_pod *param;
};

struct pw_manager_object {
	struct spa_list link;           /**< link in manager object_list */
	uint32_t id;
	uint32_t permissions;
	const char *type;
	uint32_t version;
	struct pw_properties *props;
	struct pw_proxy *proxy;
	char *message_object_path;
	int (*message_handler)(struct pw_manager *m, struct pw_manager_object *o,
	                       const char *message, const char *params, char **response);

	int changed;
	void *info;
	struct spa_list param_list;
	unsigned int creating:1;
	unsigned int removing:1;
};

struct pw_manager *pw_manager_new(struct pw_core *core);

void pw_manager_add_listener(struct pw_manager *manager,
		struct spa_hook *listener,
		const struct pw_manager_events *events, void *data);

int pw_manager_sync(struct pw_manager *manager);

void pw_manager_destroy(struct pw_manager *manager);

int pw_manager_set_metadata(struct pw_manager *manager,
		struct pw_manager_object *metadata,
		uint32_t subject, const char *key, const char *type,
		const char *format, ...) SPA_PRINTF_FUNC(6,7);

int pw_manager_for_each_object(struct pw_manager *manager,
		int (*callback) (void *data, struct pw_manager_object *object),
		void *data);

void *pw_manager_object_add_data(struct pw_manager_object *o, const char *id, size_t size);

bool pw_manager_object_is_client(struct pw_manager_object *o);
bool pw_manager_object_is_module(struct pw_manager_object *o);
bool pw_manager_object_is_card(struct pw_manager_object *o);
bool pw_manager_object_is_sink(struct pw_manager_object *o);
bool pw_manager_object_is_source(struct pw_manager_object *o);
bool pw_manager_object_is_monitor(struct pw_manager_object *o);
bool pw_manager_object_is_virtual(struct pw_manager_object *o);
bool pw_manager_object_is_source_or_monitor(struct pw_manager_object *o);
bool pw_manager_object_is_sink_input(struct pw_manager_object *o);
bool pw_manager_object_is_source_output(struct pw_manager_object *o);
bool pw_manager_object_is_recordable(struct pw_manager_object *o);
bool pw_manager_object_is_link(struct pw_manager_object *o);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* PIPEWIRE_MANAGER_H */
