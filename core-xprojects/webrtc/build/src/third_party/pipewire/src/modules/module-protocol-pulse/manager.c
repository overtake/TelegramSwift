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

#include "manager.h"

#include <spa/pod/iter.h>
#include <spa/pod/parser.h>
#include <spa/utils/result.h>
#include <extensions/metadata.h>

#define MAX_PARAMS 32

#define manager_emit_sync(m) spa_hook_list_call(&m->hooks, struct pw_manager_events, sync, 0)
#define manager_emit_added(m,o) spa_hook_list_call(&m->hooks, struct pw_manager_events, added, 0, o)
#define manager_emit_updated(m,o) spa_hook_list_call(&m->hooks, struct pw_manager_events, updated, 0, o)
#define manager_emit_removed(m,o) spa_hook_list_call(&m->hooks, struct pw_manager_events, removed, 0, o)
#define manager_emit_metadata(m,o,s,k,t,v) spa_hook_list_call(&m->hooks, struct pw_manager_events, metadata,0,o,s,k,t,v)

struct object;

struct manager {
	struct pw_manager this;

	struct spa_hook core_listener;
	struct spa_hook registry_listener;
	int sync_seq;

	struct spa_hook_list hooks;
};

struct object_info {
	const char *type;
	uint32_t version;
	const void *events;
	void (*init) (struct object *object);
	void (*destroy) (struct object *object);
};

struct object_data {
	struct spa_list link;
	const char *id;
	size_t size;
};

struct object {
	struct pw_manager_object this;

	struct manager *manager;

	const struct object_info *info;

	struct spa_list pending_list;

	struct spa_hook proxy_listener;
	struct spa_hook object_listener;

	int param_seq[MAX_PARAMS];

	struct spa_list data_list;
};

static int core_sync(struct manager *m)
{
	m->sync_seq = pw_core_sync(m->this.core, PW_ID_CORE, m->sync_seq);
	pw_log_debug("sync start %u", m->sync_seq);
	return m->sync_seq;
}

static uint32_t clear_params(struct spa_list *param_list, uint32_t id)
{
	struct pw_manager_param *p, *t;
	uint32_t count = 0;

	spa_list_for_each_safe(p, t, param_list, link) {
		if (id == SPA_ID_INVALID || p->id == id) {
			spa_list_remove(&p->link);
			free(p);
			count++;
		}
	}
	return count;
}

static struct pw_manager_param *add_param(struct spa_list *params,
		int seq, int *param_seq, uint32_t id, const struct spa_pod *param)
{
	struct pw_manager_param *p;

	if (id == SPA_ID_INVALID) {
		if (param == NULL || !spa_pod_is_object(param)) {
			errno = EINVAL;
			return NULL;
		}
		id = SPA_POD_OBJECT_ID(param);
	}

	if (id >= MAX_PARAMS) {
		pw_log_error("too big param id %d", id);
		errno = EINVAL;
		return NULL;
	}

	if (seq != param_seq[id]) {
		pw_log_debug("ignoring param %d, seq:%d != current_seq:%d",
				id, seq, param_seq[id]);
		errno = EBUSY;
		return NULL;
	}

	p = malloc(sizeof(*p) + (param != NULL ? SPA_POD_SIZE(param) : 0));
	if (p == NULL)
		return NULL;

	p->id = id;
	if (param != NULL) {
		p->param = SPA_MEMBER(p, sizeof(*p), struct spa_pod);
		memcpy(p->param, param, SPA_POD_SIZE(param));
	} else {
		clear_params(params, id);
		p->param = NULL;
	}
	spa_list_append(params, &p->link);

	return p;
}

static bool has_param(struct spa_list *param_list, struct pw_manager_param *p)
{
	struct pw_manager_param *t;
	spa_list_for_each(t, param_list, link) {
		if (p->id == t->id &&
		   SPA_POD_SIZE(p->param) == SPA_POD_SIZE(t->param) &&
		   memcmp(p->param, t->param, SPA_POD_SIZE(p->param)) == 0)
			return true;
	}
	return false;
}


static struct object *find_object(struct manager *m, uint32_t id)
{
	struct object *o;
	spa_list_for_each(o, &m->this.object_list, this.link) {
		if (o->this.creating)
			continue;
		if (o->this.id == id)
			return o;
	}
	return NULL;
}

static void object_update_params(struct object *o)
{
	struct pw_manager_param *p;

	spa_list_consume(p, &o->pending_list, link) {
		spa_list_remove(&p->link);
		if (p->param == NULL) {
			clear_params(&o->this.param_list, p->id);
			free(p);
		} else {
			spa_list_append(&o->this.param_list, &p->link);
		}
	}
}

static void object_destroy(struct object *o)
{
	struct manager *m = o->manager;
	struct object_data *d;
	spa_list_remove(&o->this.link);
	m->this.n_objects--;
	if (o->this.proxy)
		pw_proxy_destroy(o->this.proxy);
	if (o->this.props)
		pw_properties_free(o->this.props);
	if (o->this.message_object_path)
		free(o->this.message_object_path);
	clear_params(&o->this.param_list, SPA_ID_INVALID);
	clear_params(&o->pending_list, SPA_ID_INVALID);
	spa_list_consume(d, &o->data_list, link) {
		spa_list_remove(&d->link);
		free(d);
	}
	free(o);
}

/* core */
static const struct object_info core_info = {
	.type = PW_TYPE_INTERFACE_Core,
	.version = PW_VERSION_CORE,
};

/* client */
static void client_event_info(void *object, const struct pw_client_info *info)
{
	struct object *o = object;
	int changed = 0;

        pw_log_debug("object %p: id:%d change-mask:%08"PRIx64, o, o->this.id, info->change_mask);

        info = o->this.info = pw_client_info_update(o->this.info, info);

	if (info->change_mask & PW_CLIENT_CHANGE_MASK_PROPS)
		changed++;

	if (changed) {
		o->this.changed += changed;
		core_sync(o->manager);
	}
}

static const struct pw_client_events client_events = {
	PW_VERSION_CLIENT_EVENTS,
	.info = client_event_info,
};

static void client_destroy(struct object *o)
{
	if (o->this.info) {
		pw_client_info_free(o->this.info);
		o->this.info = NULL;
	}
}

static const struct object_info client_info = {
	.type = PW_TYPE_INTERFACE_Client,
	.version = PW_VERSION_CLIENT,
	.events = &client_events,
	.destroy = client_destroy,
};

/* module */
static void module_event_info(void *object, const struct pw_module_info *info)
{
        struct object *o = object;
	int changed = 0;

        pw_log_debug("object %p: id:%d change-mask:%08"PRIx64, o, o->this.id, info->change_mask);

        info = o->this.info = pw_module_info_update(o->this.info, info);

	if (info->change_mask & PW_MODULE_CHANGE_MASK_PROPS)
		changed++;

	if (changed) {
		o->this.changed += changed;
		core_sync(o->manager);
	}
}

static const struct pw_module_events module_events = {
	PW_VERSION_MODULE_EVENTS,
	.info = module_event_info,
};

static void module_destroy(struct object *o)
{
	if (o->this.info) {
		pw_module_info_free(o->this.info);
		o->this.info = NULL;
	}
}

static const struct object_info module_info = {
	.type = PW_TYPE_INTERFACE_Module,
	.version = PW_VERSION_MODULE,
	.events = &module_events,
	.destroy = module_destroy,
};

/* device */
static void device_event_info(void *object, const struct pw_device_info *info)
{
	struct object *o = object;
	uint32_t i, changed = 0;

	pw_log_debug("object %p: id:%d change-mask:%08"PRIx64, o, o->this.id, info->change_mask);

	info = o->this.info = pw_device_info_update(o->this.info, info);

	if (info->change_mask & PW_DEVICE_CHANGE_MASK_PROPS)
		changed++;

	if (info->change_mask & PW_DEVICE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t id = info->params[i].id;
			int res;

			if (info->params[i].user == 0)
				continue;
			info->params[i].user = 0;

			if (id >= MAX_PARAMS) {
				pw_log_error("too big param id %d", id);
				continue;
			}

			switch (id) {
			case SPA_PARAM_EnumProfile:
			case SPA_PARAM_Profile:
			case SPA_PARAM_EnumRoute:
				changed++;
				break;
			case SPA_PARAM_Route:
				break;
			}
			add_param(&o->pending_list, o->param_seq[id], o->param_seq, id, NULL);
			if (!(info->params[i].flags & SPA_PARAM_INFO_READ))
				continue;

			res = pw_device_enum_params((struct pw_device*)o->this.proxy,
					++o->param_seq[id], id, 0, -1, NULL);
			if (SPA_RESULT_IS_ASYNC(res))
				o->param_seq[id] = res;
		}
	}
	if (changed) {
		o->this.changed += changed;
		core_sync(o->manager);
	}
}
static struct object *find_device(struct manager *m, uint32_t card_id, uint32_t device)
{
	struct object *o;

	spa_list_for_each(o, &m->this.object_list, this.link) {
		struct pw_node_info *info;
		const char *str;

		if (strcmp(o->this.type, PW_TYPE_INTERFACE_Node) != 0)
			continue;

		if ((info = o->this.info) != NULL &&
		    (str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)) != NULL &&
		    (uint32_t)atoi(str) == card_id &&
		    (str = spa_dict_lookup(info->props, "card.profile.device")) != NULL &&
		    (uint32_t)atoi(str) == device)
			return o;
	}
	return NULL;
}

static void device_event_param(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct object *o = object, *dev;
	struct manager *m = o->manager;
	struct pw_manager_param *p;

	p = add_param(&o->pending_list, seq, o->param_seq, id, param);
	if (p == NULL)
		return;

	if (id == SPA_PARAM_Route && !has_param(&o->this.param_list, p)) {
		uint32_t id, device;
		if (spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamRoute, NULL,
				SPA_PARAM_ROUTE_index, SPA_POD_Int(&id),
				SPA_PARAM_ROUTE_device,  SPA_POD_Int(&device)) < 0)
			return;

		if ((dev = find_device(m, o->this.id, device)) != NULL) {
			dev->this.changed++;
			core_sync(o->manager);
		}
	}
}

static const struct pw_device_events device_events = {
	PW_VERSION_DEVICE_EVENTS,
	.info = device_event_info,
	.param = device_event_param,
};

static void device_destroy(struct object *o)
{
	if (o->this.info) {
		pw_device_info_free(o->this.info);
		o->this.info = NULL;
	}
}

static const struct object_info device_info = {
	.type = PW_TYPE_INTERFACE_Device,
	.version = PW_VERSION_DEVICE,
	.events = &device_events,
	.destroy = device_destroy,
};

/* node */
static void node_event_info(void *object, const struct pw_node_info *info)
{
	struct object *o = object;
	uint32_t i, changed = 0;

	pw_log_debug("object %p: id:%d change-mask:%08"PRIx64, o, o->this.id, info->change_mask);

	info = o->this.info = pw_node_info_update(o->this.info, info);

	if (info->change_mask & PW_NODE_CHANGE_MASK_STATE)
		changed++;

	if (info->change_mask & PW_NODE_CHANGE_MASK_PROPS)
		changed++;

	if (info->change_mask & PW_NODE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			uint32_t id = info->params[i].id;
			int res;

			if (info->params[i].user == 0)
				continue;
			info->params[i].user = 0;

			if (id >= MAX_PARAMS) {
				pw_log_error("too big param id %d", id);
				continue;
			}

			changed++;
			add_param(&o->pending_list, o->param_seq[id], o->param_seq, id, NULL);
			if (!(info->params[i].flags & SPA_PARAM_INFO_READ))
				continue;

			res = pw_node_enum_params((struct pw_node*)o->this.proxy,
					++o->param_seq[id], id, 0, -1, NULL);
			if (SPA_RESULT_IS_ASYNC(res))
				o->param_seq[id] = res;
		}
	}
	if (changed) {
		o->this.changed += changed;
		core_sync(o->manager);
	}
}

static void node_event_param(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct object *o = object;
	add_param(&o->pending_list, seq, o->param_seq, id, param);
}

static const struct pw_node_events node_events = {
	PW_VERSION_NODE_EVENTS,
	.info = node_event_info,
	.param = node_event_param,
};

static void node_destroy(struct object *o)
{
	if (o->this.info) {
		pw_node_info_free(o->this.info);
		o->this.info = NULL;
	}
}

static const struct object_info node_info = {
	.type = PW_TYPE_INTERFACE_Node,
	.version = PW_VERSION_NODE,
	.events = &node_events,
	.destroy = node_destroy,
};

/* link */
static const struct object_info link_info = {
	.type = PW_TYPE_INTERFACE_Link,
	.version = PW_VERSION_LINK,
};

/* metadata */
static int metadata_property(void *object,
			uint32_t subject,
			const char *key,
			const char *type,
			const char *value)
{
	struct object *o = object;
	struct manager *m = o->manager;
	manager_emit_metadata(m, &o->this, subject, key, type, value);
	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property,
};

static void metadata_init(struct object *object)
{
	struct object *o = object;
	struct manager *m = o->manager;
	o->this.creating = false;
	manager_emit_added(m, &o->this);
}

static const struct object_info metadata_info = {
	.type = PW_TYPE_INTERFACE_Metadata,
	.version = PW_VERSION_METADATA,
	.events = &metadata_events,
	.init = metadata_init,
};

static const struct object_info *objects[] =
{
	&core_info,
	&module_info,
	&client_info,
	&device_info,
	&node_info,
	&link_info,
	&metadata_info,
};

static const struct object_info *find_info(const char *type, uint32_t version)
{
	size_t i;
	for (i = 0; i < SPA_N_ELEMENTS(objects); i++) {
		if (strcmp(objects[i]->type, type) == 0 &&
		    objects[i]->version <= version)
			return objects[i];
	}
	return NULL;
}

static void
destroy_removed(void *data)
{
	struct object *o = data;
	pw_proxy_destroy(o->this.proxy);
}

static void
destroy_proxy(void *data)
{
	struct object *o = data;

	spa_assert(o->info);

	if (o->info->events)
		spa_hook_remove(&o->object_listener);
	spa_hook_remove(&o->proxy_listener);

	if (o->info->destroy)
                o->info->destroy(o);

        o->this.proxy = NULL;
}

static const struct pw_proxy_events proxy_events = {
        PW_VERSION_PROXY_EVENTS,
        .removed = destroy_removed,
        .destroy = destroy_proxy,
};

static void registry_event_global(void *data, uint32_t id,
			uint32_t permissions, const char *type, uint32_t version,
			const struct spa_dict *props)
{
	struct manager *m = data;
	struct object *o;
	const struct object_info *info;
	struct pw_proxy *proxy;

	info = find_info(type, version);
	if (info == NULL)
		return;

	proxy = pw_registry_bind(m->this.registry,
			id, type, info->version, 0);
        if (proxy == NULL)
		return;

	o = calloc(1, sizeof(*o));
	if (o == NULL) {
		pw_log_error("can't alloc object for %u %s/%d: %m", id, type, version);
		pw_proxy_destroy(proxy);
		return;
	}
	o->this.id = id;
	o->this.permissions = permissions;
	o->this.type = info->type;
	o->this.version = version;
	o->this.props = props ? pw_properties_new_dict(props) : NULL;
	o->this.proxy = proxy;
	o->this.creating = true;
	spa_list_init(&o->this.param_list);
	spa_list_init(&o->pending_list);
	spa_list_init(&o->data_list);

	o->manager = m;
	o->info = info;
	spa_list_append(&m->this.object_list, &o->this.link);
	m->this.n_objects++;

	if (info->events)
		pw_proxy_add_object_listener(proxy,
				&o->object_listener,
				o->info->events, o);
	pw_proxy_add_listener(proxy,
			&o->proxy_listener,
			&proxy_events, o);

	if (info->init)
		info->init(o);

	core_sync(m);
}

static void registry_event_global_remove(void *object, uint32_t id)
{
	struct manager *m = object;
	struct object *o;

	if ((o = find_object(m, id)) == NULL)
		return;

	o->this.removing = true;

	manager_emit_removed(m, &o->this);

	object_destroy(o);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = registry_event_global,
	.global_remove = registry_event_global_remove,
};

static void on_core_info(void *data, const struct pw_core_info *info)
{
	struct manager *m = data;
	m->this.info = pw_core_info_update(m->this.info, info);
}

static void on_core_done(void *data, uint32_t id, int seq)
{
	struct manager *m = data;
	struct object *o;

	if (id == PW_ID_CORE) {
		if (m->sync_seq != seq)
			return;

		pw_log_debug("sync end %u/%u", m->sync_seq, seq);

		manager_emit_sync(m);

		spa_list_for_each(o, &m->this.object_list, this.link)
			object_update_params(o);

		spa_list_for_each(o, &m->this.object_list, this.link) {
			if (o->this.creating) {
				o->this.creating = false;
				manager_emit_added(m, &o->this);
				o->this.changed = 0;
			} else if (o->this.changed > 0) {
				manager_emit_updated(m, &o->this);
				o->this.changed = 0;
			}
		}
	}
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
	.done = on_core_done,
	.info = on_core_info,
};

struct pw_manager *pw_manager_new(struct pw_core *core)
{
	struct manager *m;

	m = calloc(1, sizeof(*m));
	if (m == NULL)
		return NULL;

	m->this.core = core;
	m->this.registry = pw_core_get_registry(m->this.core,
			PW_VERSION_REGISTRY, 0);
	if (m->this.registry == NULL) {
		free(m);
		return NULL;
	}

	spa_hook_list_init(&m->hooks);

	spa_list_init(&m->this.object_list);

	pw_core_add_listener(m->this.core,
			&m->core_listener,
			&core_events, m);
	pw_registry_add_listener(m->this.registry,
			&m->registry_listener,
			&registry_events, m);

	return &m->this;
}

void pw_manager_add_listener(struct pw_manager *manager,
		struct spa_hook *listener,
		const struct pw_manager_events *events, void *data)
{
	struct manager *m = SPA_CONTAINER_OF(manager, struct manager, this);
	spa_hook_list_append(&m->hooks, listener, events, data);
	core_sync(m);
}

int pw_manager_set_metadata(struct pw_manager *manager,
		struct pw_manager_object *metadata,
		uint32_t subject, const char *key, const char *type,
		const char *format, ...)
{
	struct manager *m = SPA_CONTAINER_OF(manager, struct manager, this);
	struct object *s;
	va_list args;
	char buf[1024];
	char *value;

	if ((s = find_object(m, subject)) == NULL)
		return -ENOENT;
	if (!SPA_FLAG_IS_SET(s->this.permissions, PW_PERM_M))
		return -EACCES;

	if (metadata == NULL)
		return -ENOTSUP;
	if (!SPA_FLAG_IS_SET(metadata->permissions, PW_PERM_W|PW_PERM_X))
		return -EACCES;
	if (metadata->proxy == NULL)
		return -ENOENT;

	if (type != NULL) {
		va_start(args, format);
		vsnprintf(buf, sizeof(buf), format, args);
		va_end(args);
		value = buf;
	} else {
		spa_assert(format == NULL);
		value = NULL;
	}

	pw_metadata_set_property(metadata->proxy,
			subject, key, type, value);
	return 0;
}

int pw_manager_for_each_object(struct pw_manager *manager,
		int (*callback) (void *data, struct pw_manager_object *object),
		void *data)
{
	struct manager *m = SPA_CONTAINER_OF(manager, struct manager, this);
	struct object *o;
	int res;

	spa_list_for_each(o, &m->this.object_list, this.link) {
		if (o->this.creating)
			continue;
		if ((res = callback(data, &o->this)) != 0)
			return res;
	}
	return 0;
}

void pw_manager_destroy(struct pw_manager *manager)
{
	struct manager *m = SPA_CONTAINER_OF(manager, struct manager, this);
	struct object *o;

	spa_hook_remove(&m->core_listener);

	spa_list_consume(o, &m->this.object_list, this.link)
		object_destroy(o);

	spa_hook_remove(&m->registry_listener);
	pw_proxy_destroy((struct pw_proxy*)m->this.registry);

	if (m->this.info)
		pw_core_info_free(m->this.info);

	free(m);
}

static struct object_data *object_find_data(struct object *o, const char *id)
{
	struct object_data *d;
	spa_list_for_each(d, &o->data_list, link) {
		if (strcmp(d->id, id) == 0)
			return d;
	}
	return NULL;
}

void *pw_manager_object_add_data(struct pw_manager_object *obj, const char *id, size_t size)
{
	struct object *o = SPA_CONTAINER_OF(obj, struct object, this);
	struct object_data *d;

	d = object_find_data(o, id);
	if (d != NULL) {
		if (d->size == size)
			goto done;
		spa_list_remove(&d->link);
		free(d);
	}

	d = calloc(1, sizeof(struct object_data) + size);
	d->id = id;
	d->size = size;

	spa_list_append(&o->data_list, &d->link);

done:
	return SPA_MEMBER(d, sizeof(struct object_data), void);
}

int pw_manager_sync(struct pw_manager *manager)
{
	struct manager *m = SPA_CONTAINER_OF(manager, struct manager, this);
	return core_sync(m);
}

bool pw_manager_object_is_client(struct pw_manager_object *o)
{
	return strcmp(o->type, PW_TYPE_INTERFACE_Client) == 0;
}

bool pw_manager_object_is_module(struct pw_manager_object *o)
{
	return strcmp(o->type, PW_TYPE_INTERFACE_Module) == 0;
}

bool pw_manager_object_is_card(struct pw_manager_object *o)
{
	const char *str;
	return strcmp(o->type, PW_TYPE_INTERFACE_Device) == 0 &&
		o->props != NULL &&
		(str = pw_properties_get(o->props, PW_KEY_MEDIA_CLASS)) != NULL &&
		strcmp(str, "Audio/Device") == 0;
}

bool pw_manager_object_is_sink(struct pw_manager_object *o)
{
	const char *str;
	return strcmp(o->type, PW_TYPE_INTERFACE_Node) == 0 &&
		o->props != NULL &&
		(str = pw_properties_get(o->props, PW_KEY_MEDIA_CLASS)) != NULL &&
		(strcmp(str, "Audio/Sink") == 0 || strcmp(str, "Audio/Duplex") == 0);
}

bool pw_manager_object_is_source(struct pw_manager_object *o)
{
	const char *str;
	return strcmp(o->type, PW_TYPE_INTERFACE_Node) == 0 &&
		o->props != NULL &&
		(str = pw_properties_get(o->props, PW_KEY_MEDIA_CLASS)) != NULL &&
		(strcmp(str, "Audio/Source") == 0 ||
		 strcmp(str, "Audio/Duplex") == 0 ||
		 strcmp(str, "Audio/Source/Virtual") == 0);
}

bool pw_manager_object_is_monitor(struct pw_manager_object *o)
{
	const char *str;
	return strcmp(o->type, PW_TYPE_INTERFACE_Node) == 0 &&
		o->props != NULL &&
		(str = pw_properties_get(o->props, PW_KEY_MEDIA_CLASS)) != NULL &&
		(strcmp(str, "Audio/Sink") == 0);
}

bool pw_manager_object_is_virtual(struct pw_manager_object *o)
{
	const char *str;
	struct pw_node_info *info;
	return strcmp(o->type, PW_TYPE_INTERFACE_Node) == 0 &&
		(info = o->info) != NULL && info->props != NULL &&
		(str = spa_dict_lookup(info->props, PW_KEY_NODE_VIRTUAL)) != NULL &&
		pw_properties_parse_bool(str);
}

bool pw_manager_object_is_source_or_monitor(struct pw_manager_object *o)
{
	return pw_manager_object_is_source(o) || pw_manager_object_is_monitor(o);
}

bool pw_manager_object_is_sink_input(struct pw_manager_object *o)
{
	const char *str;
	return strcmp(o->type, PW_TYPE_INTERFACE_Node) == 0 &&
		o->props != NULL &&
		(str = pw_properties_get(o->props, PW_KEY_MEDIA_CLASS)) != NULL &&
		strcmp(str, "Stream/Output/Audio") == 0;
}

bool pw_manager_object_is_source_output(struct pw_manager_object *o)
{
	const char *str;
	return strcmp(o->type, PW_TYPE_INTERFACE_Node) == 0 &&
		o->props != NULL &&
		(str = pw_properties_get(o->props, PW_KEY_MEDIA_CLASS)) != NULL &&
		strcmp(str, "Stream/Input/Audio") == 0;
}

bool pw_manager_object_is_recordable(struct pw_manager_object *o)
{
	return pw_manager_object_is_source(o) || pw_manager_object_is_sink(o) || pw_manager_object_is_sink_input(o);
}

bool pw_manager_object_is_link(struct pw_manager_object *o)
{
	return strcmp(o->type, PW_TYPE_INTERFACE_Link) == 0;
}
