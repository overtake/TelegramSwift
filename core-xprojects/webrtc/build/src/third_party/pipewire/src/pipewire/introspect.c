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

#include <string.h>

#include <spa/pod/builder.h>

#include "pipewire/pipewire.h"

#include "pipewire/core.h"

SPA_EXPORT
const char *pw_node_state_as_string(enum pw_node_state state)
{
	switch (state) {
	case PW_NODE_STATE_ERROR:
		return "error";
	case PW_NODE_STATE_CREATING:
		return "creating";
	case PW_NODE_STATE_SUSPENDED:
		return "suspended";
	case PW_NODE_STATE_IDLE:
		return "idle";
	case PW_NODE_STATE_RUNNING:
		return "running";
	}
	return "invalid-state";
}

SPA_EXPORT
const char *pw_direction_as_string(enum pw_direction direction)
{
	switch (direction) {
	case PW_DIRECTION_INPUT:
		return "input";
	case PW_DIRECTION_OUTPUT:
		return "output";
	}
	return "invalid";
}

SPA_EXPORT
const char *pw_link_state_as_string(enum pw_link_state state)
{
	switch (state) {
	case PW_LINK_STATE_ERROR:
		return "error";
	case PW_LINK_STATE_UNLINKED:
		return "unlinked";
	case PW_LINK_STATE_INIT:
		return "init";
	case PW_LINK_STATE_NEGOTIATING:
		return "negotiating";
	case PW_LINK_STATE_ALLOCATING:
		return "allocating";
	case PW_LINK_STATE_PAUSED:
		return "paused";
	case PW_LINK_STATE_ACTIVE:
		return "active";
	}
	return "invalid-state";
}

static void pw_spa_dict_destroy(struct spa_dict *dict)
{
	const struct spa_dict_item *item;

	spa_dict_for_each(item, dict) {
		free((void *) item->key);
		free((void *) item->value);
	}
	free((void*)dict->items);
	free(dict);
}

static struct spa_dict *pw_spa_dict_copy(struct spa_dict *dict)
{
	struct spa_dict *copy;
	struct spa_dict_item *items;
	uint32_t i;

	if (dict == NULL)
		return NULL;

	copy = calloc(1, sizeof(struct spa_dict));
	if (copy == NULL)
		goto no_mem;
	copy->items = items = calloc(dict->n_items, sizeof(struct spa_dict_item));
	if (copy->items == NULL)
		goto no_items;
	copy->n_items = dict->n_items;

	for (i = 0; i < dict->n_items; i++) {
		items[i].key = strdup(dict->items[i].key);
		items[i].value = dict->items[i].value ? strdup(dict->items[i].value) : NULL;
	}
	return copy;

      no_items:
	free(copy);
      no_mem:
	return NULL;
}

SPA_EXPORT
struct pw_core_info *pw_core_info_update(struct pw_core_info *info,
					 const struct pw_core_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_core_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
		info->cookie = update->cookie;
		info->user_name = update->user_name ? strdup(update->user_name) : NULL;
		info->host_name = update->host_name ? strdup(update->host_name) : NULL;
		info->version = update->version ? strdup(update->version) : NULL;
		info->name = update->name ? strdup(update->name) : NULL;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_CORE_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	return info;
}

SPA_EXPORT
void pw_core_info_free(struct pw_core_info *info)
{
	free((void *) info->user_name);
	free((void *) info->host_name);
	free((void *) info->version);
	free((void *) info->name);
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free(info);
}

SPA_EXPORT
struct pw_node_info *pw_node_info_update(struct pw_node_info *info,
					 const struct pw_node_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_node_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
		info->max_input_ports = update->max_input_ports;
		info->max_output_ports = update->max_output_ports;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_NODE_CHANGE_MASK_INPUT_PORTS) {
		info->n_input_ports = update->n_input_ports;
	}
	if (update->change_mask & PW_NODE_CHANGE_MASK_OUTPUT_PORTS) {
		info->n_output_ports = update->n_output_ports;
	}

	if (update->change_mask & PW_NODE_CHANGE_MASK_STATE) {
		info->state = update->state;
		free((void *) info->error);
		info->error = update->error ? strdup(update->error) : NULL;
	}
	if (update->change_mask & PW_NODE_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	if (update->change_mask & PW_NODE_CHANGE_MASK_PARAMS) {
		uint32_t i, user, n_params = update->n_params;;

		info->params = realloc(info->params, n_params * sizeof(struct spa_param_info));
		if (info->params == NULL)
			n_params = 0;

		for (i = 0; i < SPA_MIN(info->n_params, n_params); i++) {
			user = info->params[i].user;
			if (info->params[i].flags != update->params[i].flags)
				user++;
			info->params[i] = update->params[i];
			info->params[i].user = user;
		}
		info->n_params = n_params;
		for (; i < info->n_params; i++) {
			info->params[i] = update->params[i];
			info->params[i].user = 1;
		}
	}
	return info;
}

SPA_EXPORT
void pw_node_info_free(struct pw_node_info *info)
{

	free((void *) info->error);
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free((void *) info->params);
	free(info);
}

SPA_EXPORT
struct pw_port_info *pw_port_info_update(struct pw_port_info *info,
					 const struct pw_port_info *update)
{

	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_port_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
		info->direction = update->direction;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_PORT_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	if (update->change_mask & PW_PORT_CHANGE_MASK_PARAMS) {
		uint32_t i, user, n_params = update->n_params;;

		info->params = realloc(info->params, n_params * sizeof(struct spa_param_info));
		if (info->params == NULL)
			n_params = 0;

		for (i = 0; i < SPA_MIN(info->n_params, n_params); i++) {
			user = info->params[i].user;
			if (info->params[i].flags != update->params[i].flags)
				user++;
			info->params[i] = update->params[i];
			info->params[i].user = user;
		}
		info->n_params = n_params;
		for (; i < info->n_params; i++) {
			info->params[i] = update->params[i];
			info->params[i].user = 1;
		}
	}
	return info;
}

SPA_EXPORT
void pw_port_info_free(struct pw_port_info *info)
{

	if (info->props)
		pw_spa_dict_destroy(info->props);
	free((void *) info->params);
	free(info);
}

SPA_EXPORT
struct pw_factory_info *pw_factory_info_update(struct pw_factory_info *info,
					       const struct pw_factory_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_factory_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
		info->name = update->name ? strdup(update->name) : NULL;
		info->type = update->type ? strdup(update->type) : NULL;
		info->version = update->version;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_FACTORY_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	return info;
}

SPA_EXPORT
void pw_factory_info_free(struct pw_factory_info *info)
{
	free((void *) info->name);
	free((void *) info->type);
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free(info);
}

SPA_EXPORT
struct pw_module_info *pw_module_info_update(struct pw_module_info *info,
					     const struct pw_module_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_module_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
		info->name = update->name ? strdup(update->name) : NULL;
		info->filename = update->filename ? strdup(update->filename) : NULL;
		info->args = update->args ? strdup(update->args) : NULL;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_MODULE_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	return info;
}

SPA_EXPORT
void pw_module_info_free(struct pw_module_info *info)
{
	free((void *) info->name);
	free((void *) info->filename);
	free((void *) info->args);
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free(info);
}

SPA_EXPORT
struct pw_device_info *pw_device_info_update(struct pw_device_info *info,
					     const struct pw_device_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_device_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_DEVICE_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	if (update->change_mask & PW_DEVICE_CHANGE_MASK_PARAMS) {
		uint32_t i, user, n_params = update->n_params;;

		info->params = realloc(info->params, n_params * sizeof(struct spa_param_info));
		if (info->params == NULL)
			n_params = 0;

		for (i = 0; i < SPA_MIN(info->n_params, n_params); i++) {
			user = info->params[i].user;
			if (info->params[i].flags != update->params[i].flags)
				user++;
			info->params[i] = update->params[i];
			info->params[i].user = user;
		}
		info->n_params = n_params;
		for (; i < info->n_params; i++) {
			info->params[i] = update->params[i];
			info->params[i].user = 1;
		}
	}
	return info;
}

SPA_EXPORT
void pw_device_info_free(struct pw_device_info *info)
{
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free((void *) info->params);
	free(info);
}

SPA_EXPORT
struct pw_client_info *pw_client_info_update(struct pw_client_info *info,
					     const struct pw_client_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_client_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
	}
	info->change_mask = update->change_mask;

	if (update->change_mask & PW_CLIENT_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	return info;
}

SPA_EXPORT
void pw_client_info_free(struct pw_client_info *info)
{
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free(info);
}

SPA_EXPORT
struct pw_link_info *pw_link_info_update(struct pw_link_info *info,
					 const struct pw_link_info *update)
{
	if (update == NULL)
		return info;

	if (info == NULL) {
		info = calloc(1, sizeof(struct pw_link_info));
		if (info == NULL)
			return NULL;

		info->id = update->id;
		info->output_node_id = update->output_node_id;
		info->output_port_id = update->output_port_id;
		info->input_node_id = update->input_node_id;
		info->input_port_id = update->input_port_id;
	}

	info->change_mask = update->change_mask;

	if (update->change_mask & PW_LINK_CHANGE_MASK_STATE) {
		info->state = update->state;
		free((void *) info->error);
		info->error = update->error ? strdup(update->error) : NULL;
	}
	if (update->change_mask & PW_LINK_CHANGE_MASK_FORMAT) {
		free(info->format);
		info->format = update->format ? spa_pod_copy(update->format) : NULL;
	}
	if (update->change_mask & PW_LINK_CHANGE_MASK_PROPS) {
		if (info->props)
			pw_spa_dict_destroy(info->props);
		info->props = pw_spa_dict_copy(update->props);
	}
	return info;
}

SPA_EXPORT
void pw_link_info_free(struct pw_link_info *info)
{
	free((void *) info->error);
	free(info->format);
	if (info->props)
		pw_spa_dict_destroy(info->props);
	free(info);
}
