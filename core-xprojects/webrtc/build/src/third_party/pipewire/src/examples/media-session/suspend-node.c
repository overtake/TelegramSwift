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

#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>
#include <time.h>

#include "config.h"

#include <spa/node/node.h>
#include <spa/utils/hook.h>
#include <spa/param/props.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"

#include "media-session.h"

#define NAME		"suspend-node"
#define SESSION_KEY	"suspend-node"

#define DEFAULT_IDLE_SECONDS	3

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_context *context;

	struct spa_list node_list;
	int seq;
};

struct node {
	struct sm_node *obj;

	uint32_t id;
	struct impl *impl;

	struct spa_list link;		/**< link in impl node_list */
	enum pw_direction direction;

	struct spa_hook listener;
	struct spa_source *idle_timeout;
};


static void remove_idle_timeout(struct node *node)
{
	struct impl *impl = node->impl;
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);

	if (node->idle_timeout) {
		pw_loop_destroy_source(main_loop, node->idle_timeout);
		node->idle_timeout = NULL;
	}
}

static void idle_timeout(void *data, uint64_t expirations)
{
	struct node *node = data;
	struct impl *impl = node->impl;
	struct spa_command *cmd = &SPA_NODE_COMMAND_INIT(SPA_NODE_COMMAND_Suspend);

	pw_log_debug(NAME " %p: node %d idle timeout", impl, node->id);

	remove_idle_timeout(node);

	pw_node_send_command((struct pw_node*)node->obj->obj.proxy, cmd);

	sm_object_release(&node->obj->obj);
}

static void add_idle_timeout(struct node *node)
{
	struct timespec value;
	struct impl *impl = node->impl;
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);
	const char *str;

	if (node->obj->info && node->obj->info->props &&
	    (str = spa_dict_lookup(node->obj->info->props, "session.suspend-timeout-seconds")) != NULL)
		value.tv_sec = atoi(str);
	else
		value.tv_sec = DEFAULT_IDLE_SECONDS;

	if (value.tv_sec == 0)
		return;

	if (node->idle_timeout == NULL)
		node->idle_timeout = pw_loop_add_timer(main_loop, idle_timeout, node);

	value.tv_nsec = 0;
	pw_loop_update_timer(main_loop, node->idle_timeout, &value, NULL, false);
}

static int on_node_idle(struct impl *impl, struct node *node)
{
	pw_log_debug(NAME" %p: node %d idle", impl, node->id);
	add_idle_timeout(node);
	return 0;
}

static int on_node_running(struct impl *impl, struct node *node)
{
	pw_log_debug(NAME" %p: node %d running", impl, node->id);
	sm_object_acquire(&node->obj->obj);
	remove_idle_timeout(node);
	return 0;
}

static void object_update(void *data)
{
	struct node *node = data;
	struct impl *impl = node->impl;

	pw_log_debug(NAME" %p: node %p %08x", impl, node, node->obj->obj.changed);

	if (node->obj->obj.changed & SM_NODE_CHANGE_MASK_INFO) {
		const struct pw_node_info *info = node->obj->info;

		if (info->change_mask & PW_NODE_CHANGE_MASK_STATE) {
			switch (info->state) {
			case PW_NODE_STATE_ERROR:
			case PW_NODE_STATE_IDLE:
				on_node_idle(impl, node);
				break;
			case PW_NODE_STATE_RUNNING:
				on_node_running(impl, node);
				break;
			case PW_NODE_STATE_SUSPENDED:
				break;
			default:
				break;
			}
		}
	}
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static int
handle_node(struct impl *impl, struct sm_object *object)
{
	struct node *node;
	const char *media_class;

	media_class = object->props ? pw_properties_get(object->props, PW_KEY_MEDIA_CLASS) : NULL;
	if (media_class == NULL)
		return 0;

	if (strstr(media_class, "Audio/") != media_class &&
	    (strstr(media_class, "Video/") != media_class))
		return 0;

	node = sm_object_add_data(object, SESSION_KEY, sizeof(struct node));
	node->obj = (struct sm_node*)object;
	node->impl = impl;
	node->id = object->id;
	spa_list_append(&impl->node_list, &node->link);

	node->obj->obj.mask |= SM_NODE_CHANGE_MASK_INFO;
	sm_object_add_listener(&node->obj->obj, &node->listener, &object_events, node);

	return 1;
}

static void destroy_node(struct impl *impl, struct node *node)
{
	remove_idle_timeout(node);
	spa_list_remove(&node->link);
	spa_hook_remove(&node->listener);
	sm_object_remove_data((struct sm_object*)node->obj, SESSION_KEY);
}

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	int res;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0)
		res = handle_node(impl, object);
	else
		res = 0;

	if (res < 0)
		pw_log_warn(NAME" %p: can't handle global %d", impl, object->id);
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	pw_log_debug(NAME " %p: remove global '%d'", impl, object->id);

	if (strcmp(object->type, PW_TYPE_INTERFACE_Node) == 0) {
		struct node *node;
		if ((node = sm_object_get_data(object, SESSION_KEY)) != NULL)
			destroy_node(impl, node);
	}
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	spa_hook_remove(&impl->listener);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.create = session_create,
	.remove = session_remove,
	.destroy = session_destroy,
};

int sm_suspend_node_start(struct sm_media_session *session)
{
	struct impl *impl;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	spa_list_init(&impl->node_list);

	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	return 0;
}
