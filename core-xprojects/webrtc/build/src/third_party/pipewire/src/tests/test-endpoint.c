/* PipeWire
 *
 * Copyright © 2020 Collabora Ltd.
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

#include <unistd.h>

#include <pipewire/pipewire.h>
#include <extensions/session-manager.h>

#include <spa/pod/builder.h>
#include <spa/pod/parser.h>
#include <spa/pod/filter.h>

struct props
{
	float volume;
	bool mute;
};

struct endpoint
{
	struct spa_interface iface;
	struct spa_hook_list hooks;
	struct pw_properties *properties;
	struct pw_endpoint_info info;
	uint32_t n_subscribe_ids;
	uint32_t subscribe_ids[2];
	struct props props;
};

#define pw_endpoint_emit(hooks,method,version,...) \
	spa_hook_list_call_simple(hooks, struct pw_endpoint_events, \
				  method, version, ##__VA_ARGS__)

#define pw_endpoint_emit_info(hooks,...)	pw_endpoint_emit(hooks, info, 0, ##__VA_ARGS__)
#define pw_endpoint_emit_param(hooks,...)	pw_endpoint_emit(hooks, param, 0, ##__VA_ARGS__)

static int
endpoint_add_listener(void *object,
		struct spa_hook *listener,
		const struct pw_endpoint_events *events,
		void *data)
{
	struct endpoint *self = object;
	struct spa_hook_list save;

	spa_hook_list_isolate(&self->hooks, &save, listener, events, data);
	pw_endpoint_emit_info(&self->hooks, &self->info);
	spa_hook_list_join(&self->hooks, &save);
	return 0;
}

static int
endpoint_enum_params (void *object, int seq,
		uint32_t id, uint32_t start, uint32_t num,
		const struct spa_pod *filter)
{
	struct endpoint *self = object;
	struct spa_pod *param, *result;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	uint32_t count = 0, index, next = start;

	next = start;
      next:
	index = next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_PropInfo:
	{
		struct props *p = &self->props;

		switch (index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_volume),
				SPA_PROP_INFO_name, SPA_POD_String("volume"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_RANGE_Float(p->volume, 0.0, 1.0));
			break;
		case 1:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_PropInfo, id,
				SPA_PROP_INFO_id,   SPA_POD_Id(SPA_PROP_mute),
				SPA_PROP_INFO_name, SPA_POD_String("mute"),
				SPA_PROP_INFO_type, SPA_POD_CHOICE_Bool(p->mute));
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Props:
	{
		struct props *p = &self->props;

		switch (index) {
		case 0:
			param = spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Props, id,
				SPA_PROP_volume,  SPA_POD_Float(p->volume),
				SPA_PROP_mute,    SPA_POD_Bool(p->mute));
			break;
		default:
			return 0;
		}
		break;
	}
	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result, param, filter) < 0)
		goto next;

	pw_endpoint_emit_param(&self->hooks, seq, id, index, next, result);

	if (++count != num)
		goto next;

	return 0;
}

static int
endpoint_subscribe_params (void *object, uint32_t *ids, uint32_t n_ids)
{
	struct endpoint *self = object;

	n_ids = SPA_MIN(n_ids, SPA_N_ELEMENTS(self->subscribe_ids));
	self->n_subscribe_ids = n_ids;

	for (uint32_t i = 0; i < n_ids; i++) {
		self->subscribe_ids[i] = ids[i];
		endpoint_enum_params(object, 1, ids[i], 0, UINT32_MAX, NULL);
	}
	return 0;
}

static int
endpoint_set_param (void *object, uint32_t id, uint32_t flags,
		const struct spa_pod *param)
{
	struct endpoint *self = object;

	if (id == SPA_PARAM_Props) {
		struct props *p = &self->props;
		spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_Props, NULL,
			SPA_PROP_volume, SPA_POD_OPT_Float(&p->volume),
			SPA_PROP_mute,   SPA_POD_OPT_Bool(&p->mute));
	}
	else {
		spa_assert_not_reached();
		return -ENOENT;
	}

	for (uint32_t i = 0; i < self->n_subscribe_ids; i++) {
		if (id == self->subscribe_ids[i])
			endpoint_enum_params (self, 1, id, 0, UINT32_MAX, NULL);
	}

	return 0;
}

static int
endpoint_create_link (void *object, const struct spa_dict *props)
{
	spa_assert_not_reached();
	return -ENOTSUP;
}

static const struct pw_endpoint_methods endpoint_methods = {
	PW_VERSION_ENDPOINT_METHODS,
	.add_listener = endpoint_add_listener,
	.subscribe_params = endpoint_subscribe_params,
	.enum_params = endpoint_enum_params,
	.set_param = endpoint_set_param,
	.create_link = endpoint_create_link,
};

static struct spa_param_info param_info[] = {
	SPA_PARAM_INFO (SPA_PARAM_Props, SPA_PARAM_INFO_READWRITE),
	SPA_PARAM_INFO (SPA_PARAM_PropInfo, SPA_PARAM_INFO_READ)
};

static void
endpoint_init(struct endpoint * self)
{
	self->iface = SPA_INTERFACE_INIT (
		PW_TYPE_INTERFACE_Endpoint,
		PW_VERSION_ENDPOINT,
		&endpoint_methods, self);
	spa_hook_list_init (&self->hooks);

	self->info.version = PW_VERSION_ENDPOINT_INFO;
	self->info.change_mask = PW_ENDPOINT_CHANGE_MASK_ALL;
	self->info.name = "test-endpoint";
	self->info.media_class = "Audio/Sink";
	self->info.direction = PW_DIRECTION_OUTPUT;
	self->info.n_streams = 0;
	self->info.session_id = SPA_ID_INVALID;

	self->properties = pw_properties_new(
		PW_KEY_ENDPOINT_NAME, self->info.name,
		PW_KEY_MEDIA_CLASS, self->info.media_class,
		NULL);
	self->info.props = &self->properties->dict;

	self->info.params = param_info;
	self->info.n_params = SPA_N_ELEMENTS (param_info);

	self->props.volume = 0.9;
	self->props.mute = false;
}

static void
endpoint_clear(struct endpoint * self)
{
	spa_hook_list_clean(&self->hooks);
	pw_properties_free(self->properties);
}

struct test_endpoint_data
{
	struct pw_main_loop *loop;
	struct pw_context *context;
	struct pw_core *core;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct endpoint endpoint;
	struct pw_proxy *export_proxy;
	struct pw_proxy *bound_proxy;
	struct spa_hook object_listener;
	struct spa_hook proxy_listener;

	struct props props;
	bool info_received;
	int params_received;
};

static void
endpoint_event_info(void *object, const struct pw_endpoint_info *info)
{
	struct test_endpoint_data *d = object;
	const char *val;

	spa_assert(info);
	spa_assert(info->version == PW_VERSION_ENDPOINT_INFO);
	spa_assert(info->id == pw_proxy_get_bound_id(d->bound_proxy));
	spa_assert(info->id == pw_proxy_get_bound_id(d->export_proxy));
	spa_assert(info->change_mask == PW_ENDPOINT_CHANGE_MASK_ALL);
	spa_assert(!strcmp(info->name, "test-endpoint"));
	spa_assert(!strcmp(info->media_class, "Audio/Sink"));
	spa_assert(info->direction == PW_DIRECTION_OUTPUT);
	spa_assert(info->n_streams == 0);
	spa_assert(info->session_id == SPA_ID_INVALID);
	spa_assert(info->n_params == SPA_N_ELEMENTS (param_info));
	spa_assert(info->n_params == 2);
	spa_assert(info->params[0].id == param_info[0].id);
	spa_assert(info->params[0].flags == param_info[0].flags);
	spa_assert(info->params[1].id == param_info[1].id);
	spa_assert(info->params[1].flags == param_info[1].flags);
	spa_assert(info->props != NULL);
	val = spa_dict_lookup(info->props, PW_KEY_ENDPOINT_NAME);
	spa_assert(val && !strcmp(val, "test-endpoint"));
	val = spa_dict_lookup(info->props, PW_KEY_MEDIA_CLASS);
	spa_assert(val && !strcmp(val, "Audio/Sink"));

	d->info_received = true;
	pw_main_loop_quit(d->loop);
}

static void
endpoint_event_param(void *object, int seq,
		uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct test_endpoint_data *d = object;

	if (id == SPA_PARAM_Props) {
		struct props *p = &d->props;
		spa_assert(param);
		spa_pod_parse_object(param,
			SPA_TYPE_OBJECT_Props, &id,
			SPA_PROP_volume, SPA_POD_OPT_Float(&p->volume),
			SPA_PROP_mute,   SPA_POD_OPT_Bool(&p->mute));
		spa_assert(id == SPA_PARAM_Props);
	}

	d->params_received++;
	pw_main_loop_quit(d->loop);
}

static const struct pw_endpoint_events endpoint_events = {
	PW_VERSION_ENDPOINT_EVENTS,
	.info = endpoint_event_info,
	.param = endpoint_event_param,
};

static void
endpoint_proxy_destroy(void *object)
{
	struct test_endpoint_data *d = object;
	d->bound_proxy = NULL;
	pw_main_loop_quit(d->loop);
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.destroy = endpoint_proxy_destroy,
};

static void
test_endpoint_global(void *object, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	struct test_endpoint_data *d = object;
	const char *val;

	if (strcmp(type, PW_TYPE_INTERFACE_Endpoint) != 0)
		return;

	d->bound_proxy = pw_registry_bind(d->registry, id, type,
					PW_VERSION_ENDPOINT, 0);
	spa_assert(d->bound_proxy != NULL);

	spa_assert(props != NULL);
	val = spa_dict_lookup(props, PW_KEY_ENDPOINT_NAME);
	spa_assert(val && !strcmp(val, "test-endpoint"));
	val = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS);
	spa_assert(val && !strcmp(val, "Audio/Sink"));

	pw_endpoint_add_listener(d->bound_proxy, &d->object_listener,
				 &endpoint_events, d);
	pw_proxy_add_listener(d->bound_proxy, &d->proxy_listener,
				 &proxy_events, d);
}

static void
test_endpoint_global_remove(void *object, uint32_t id)
{
	struct test_endpoint_data *d = object;
	if (d->bound_proxy && id == pw_proxy_get_bound_id(d->bound_proxy))
		pw_proxy_destroy(d->bound_proxy);
}

static const struct pw_registry_events registry_events = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = test_endpoint_global,
	.global_remove = test_endpoint_global_remove,
};

static void test_endpoint(void)
{
	struct test_endpoint_data d;
	uint32_t ids[] = { SPA_PARAM_Props };
	uint8_t buffer[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, 1024);

	d.loop = pw_main_loop_new(NULL);
	d.context = pw_context_new(pw_main_loop_get_loop(d.loop), NULL, 0);
	spa_assert(d.context != NULL);

	d.core = pw_context_connect_self(d.context, NULL, 0);
	spa_assert(d.core != NULL);

	d.registry = pw_core_get_registry(d.core, PW_VERSION_REGISTRY, 0);
	pw_registry_add_listener(d.registry,
				&d.registry_listener,
				&registry_events, &d);

	/* export and expect to get a global on the registry, along with info */
	d.info_received = false;
	endpoint_init(&d.endpoint);
	d.export_proxy = pw_core_export(d.core, PW_TYPE_INTERFACE_Endpoint,
				d.endpoint.info.props, &d.endpoint.iface, 0);
	spa_assert(d.export_proxy != NULL);
	pw_main_loop_run(d.loop);
	spa_assert(d.bound_proxy);
	spa_assert(d.info_received == true);

	/* request params */
	d.params_received = 0;
	d.props.volume = 0.0;
	d.props.mute = true;
	pw_endpoint_subscribe_params(d.bound_proxy, ids, SPA_N_ELEMENTS(ids));
	pw_main_loop_run(d.loop);
	spa_assert(d.params_received == 1);
	spa_assert(d.props.volume > 0.89 && d.props.volume < 0.91);
	spa_assert(d.props.mute == false);

	/* set param from the client */
	d.params_received = 0;
	pw_endpoint_set_param(d.bound_proxy, SPA_PARAM_Props, 0,
		spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Props, SPA_PARAM_Props,
				SPA_PROP_volume, SPA_POD_Float(0.5)));
	pw_main_loop_run(d.loop);
	spa_assert(d.params_received == 1);
	spa_assert(d.props.volume > 0.49 && d.props.volume < 0.51);
	spa_assert(d.props.mute == false);

	/* set param from the impl */
	d.params_received = 0;
	pw_endpoint_set_param(&d.endpoint.iface, SPA_PARAM_Props, 0,
		spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_Props, SPA_PARAM_Props,
				SPA_PROP_volume, SPA_POD_Float(0.2),
				SPA_PROP_mute, SPA_POD_Bool(true)));
	pw_main_loop_run(d.loop);
	spa_assert(d.params_received == 1);
	spa_assert(d.props.volume > 0.19 && d.props.volume < 0.21);
	spa_assert(d.props.mute == true);

	/* stop exporting and expect to see that reflected on the registry */
	pw_proxy_destroy(d.export_proxy);
	pw_main_loop_run(d.loop);
	spa_assert(!d.bound_proxy);

	endpoint_clear(&d.endpoint);
	pw_proxy_destroy((struct pw_proxy*)d.registry);
	pw_context_destroy(d.context);
	pw_main_loop_destroy(d.loop);
}

int main(int argc, char *argv[])
{
	pw_init(&argc, &argv);

	alarm(5); /* watchdog; terminate after 5 seconds */
	test_endpoint();

	return 0;
}
