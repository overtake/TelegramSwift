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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <string.h>
#include <stdio.h>
#include <dlfcn.h>

#include <spa/node/node.h>
#include <spa/node/utils.h>
#include <spa/utils/result.h>
#include <spa/param/props.h>
#include <spa/pod/iter.h>
#include <spa/debug/types.h>

#include "spa-node.h"

struct impl {
	struct pw_impl_node *this;

	enum pw_spa_node_flags flags;

	struct spa_handle *handle;
	struct spa_node *node;          /**< handle to SPA node */

	struct spa_hook node_listener;
	int init_pending;

	void *user_data;

	unsigned int async_init:1;
};

static void spa_node_free(void *data)
{
	struct impl *impl = data;
	struct pw_impl_node *node = impl->this;

	pw_log_debug("spa-node %p: free", node);

	spa_hook_remove(&impl->node_listener);
	if (impl->handle)
		pw_unload_spa_handle(impl->handle);
}

static void complete_init(struct impl *impl)
{
        struct pw_impl_node *this = impl->this;

	impl->init_pending = SPA_ID_INVALID;

	if (SPA_FLAG_IS_SET(impl->flags, PW_SPA_NODE_FLAG_ACTIVATE))
		pw_impl_node_set_active(this, true);

	if (!SPA_FLAG_IS_SET(impl->flags, PW_SPA_NODE_FLAG_NO_REGISTER))
		pw_impl_node_register(this, NULL);
	else
		pw_impl_node_initialized(this);
}

static void spa_node_result(void *data, int seq, int res, uint32_t type, const void *result)
{
	struct impl *impl = data;
	struct pw_impl_node *node = impl->this;

	if (seq == impl->init_pending) {
		pw_log_debug("spa-node %p: init complete event %d %d", node, seq, res);
		complete_init(impl);
	}
}

static const struct pw_impl_node_events node_events = {
	PW_VERSION_IMPL_NODE_EVENTS,
	.free = spa_node_free,
	.result = spa_node_result,
};

struct pw_impl_node *
pw_spa_node_new(struct pw_context *context,
		enum pw_spa_node_flags flags,
		struct spa_node *node,
		struct spa_handle *handle,
		struct pw_properties *properties,
		size_t user_data_size)
{
	struct pw_impl_node *this;
	struct impl *impl;
	int res;

	this = pw_context_create_node(context, properties, sizeof(struct impl) + user_data_size);
	if (this == NULL) {
		res = -errno;
		goto error_exit;
	}

	impl = pw_impl_node_get_user_data(this);
	impl->this = this;
	impl->node = node;
	impl->handle = handle;
	impl->flags = flags;

	if (user_data_size > 0)
                impl->user_data = SPA_MEMBER(impl, sizeof(struct impl), void);

	pw_impl_node_add_listener(this, &impl->node_listener, &node_events, impl);
	if ((res = pw_impl_node_set_implementation(this, impl->node)) < 0)
		goto error_exit_clean_node;

	if (flags & PW_SPA_NODE_FLAG_ASYNC) {
		impl->init_pending = spa_node_sync(impl->node, res);
	} else {
		complete_init(impl);
	}
	return this;

error_exit_clean_node:
	pw_impl_node_destroy(this);
	handle = NULL;
error_exit:
	if (handle)
		pw_unload_spa_handle(handle);
	errno = -res;
	return NULL;

}

void *pw_spa_node_get_user_data(struct pw_impl_node *node)
{
	struct impl *impl = pw_impl_node_get_user_data(node);
	return impl->user_data;
}

static int
setup_props(struct pw_context *context, struct spa_node *spa_node, struct pw_properties *pw_props)
{
	int res;
	struct spa_pod *props;
	void *state = NULL;
	const char *key;
	uint32_t index = 0;
	uint8_t buf[2048];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
	const struct spa_pod_prop *prop = NULL;

	res = spa_node_enum_params_sync(spa_node,
					SPA_PARAM_Props, &index, NULL, &props,
					&b);
	if (res != 1) {
		if (res < 0)
			pw_log_debug("spa_node_get_props result: %s", spa_strerror(res));
		if (res == -ENOTSUP || res == -ENOENT)
			res = 0;
		return res;
	}

	while ((key = pw_properties_iterate(pw_props, &state))) {
		uint32_t type = 0;

		type = spa_debug_type_find_type(spa_type_props, key);
		if (type == SPA_TYPE_None)
			continue;

		if ((prop = spa_pod_find_prop(props, prop, type))) {
			const char *value = pw_properties_get(pw_props, key);

			if (value == NULL)
				continue;

			pw_log_debug("configure prop %s to %s", key, value);

			switch(prop->value.type) {
			case SPA_TYPE_Bool:
				SPA_POD_VALUE(struct spa_pod_bool, &prop->value) =
					pw_properties_parse_bool(value);
				break;
			case SPA_TYPE_Id:
				SPA_POD_VALUE(struct spa_pod_id, &prop->value) =
					pw_properties_parse_int(value);
				break;
			case SPA_TYPE_Int:
				SPA_POD_VALUE(struct spa_pod_int, &prop->value) =
					pw_properties_parse_int(value);
				break;
			case SPA_TYPE_Long:
				SPA_POD_VALUE(struct spa_pod_long, &prop->value) =
					pw_properties_parse_int64(value);
				break;
			case SPA_TYPE_Float:
				SPA_POD_VALUE(struct spa_pod_float, &prop->value) =
					pw_properties_parse_float(value);
				break;
			case SPA_TYPE_Double:
				SPA_POD_VALUE(struct spa_pod_double, &prop->value) =
					pw_properties_parse_double(value);
				break;
			case SPA_TYPE_String:
				break;
			default:
				break;
			}
		}
	}

	if ((res = spa_node_set_param(spa_node, SPA_PARAM_Props, 0, props)) < 0) {
		pw_log_debug("spa_node_set_props failed: %s", spa_strerror(res));
		return res;
	}
	return 0;
}


struct pw_impl_node *pw_spa_node_load(struct pw_context *context,
				 const char *factory_name,
				 enum pw_spa_node_flags flags,
				 struct pw_properties *properties,
				 size_t user_data_size)
{
	struct pw_impl_node *this;
	struct spa_node *spa_node;
	int res;
	struct spa_handle *handle;
	void *iface;

	handle = pw_context_load_spa_handle(context,
			factory_name,
			properties ? &properties->dict : NULL);
	if (handle == NULL) {
		res = -errno;
		goto error_exit;
	}

	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Node, &iface)) < 0) {
		pw_log_error("can't get node interface %d", res);
		goto error_exit_unload;
	}
	if (SPA_RESULT_IS_ASYNC(res))
		flags |= PW_SPA_NODE_FLAG_ASYNC;

	spa_node = iface;

	if (properties != NULL) {
		if ((res = setup_props(context, spa_node, properties)) < 0) {
			pw_log_warn("can't setup properties: %s", spa_strerror(res));
		}
	}

	this = pw_spa_node_new(context, flags,
			       spa_node, handle, properties, user_data_size);
	if (this == NULL) {
		res = -errno;
		properties = NULL;
		goto error_exit_unload;
	}

	return this;

error_exit_unload:
	pw_unload_spa_handle(handle);
error_exit:
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}
