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
#include <fcntl.h>
#include <unistd.h>

#include "config.h"

#include <spa/utils/hook.h>
#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/pod/parser.h>
#include <spa/pod/builder.h>
#include <spa/debug/pod.h>

#include "pipewire/pipewire.h"
#include "extensions/metadata.h"

#include "media-session.h"

#define NAME		"default-profile"
#define SESSION_KEY	"default-profile"
#define PREFIX		"default.profile."

#define SAVE_INTERVAL	1

struct impl {
	struct timespec now;

	struct sm_media_session *session;
	struct spa_hook listener;

	struct pw_context *context;
	struct spa_source *idle_timeout;

	struct spa_hook meta_listener;

	struct pw_properties *properties;
};

struct device {
	struct sm_device *obj;

	uint32_t id;
	struct impl *impl;
	char *name;
	char *key;

	struct spa_hook listener;

	unsigned int restored:1;
	uint32_t saved_profile;
	uint32_t best_profile;
	uint32_t active_profile;
};

static void remove_idle_timeout(struct impl *impl)
{
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);
	int res;

	if (impl->idle_timeout) {
		if ((res = sm_media_session_save_state(impl->session,
						SESSION_KEY, impl->properties)) < 0)
			pw_log_error("can't save "SESSION_KEY" state: %s", spa_strerror(res));
		pw_loop_destroy_source(main_loop, impl->idle_timeout);
		impl->idle_timeout = NULL;
	}
}

static void idle_timeout(void *data, uint64_t expirations)
{
	struct impl *impl = data;
	pw_log_debug(NAME " %p: idle timeout", impl);
	remove_idle_timeout(impl);
}

static void add_idle_timeout(struct impl *impl)
{
	struct timespec value;
	struct pw_loop *main_loop = pw_context_get_main_loop(impl->context);

	if (impl->idle_timeout == NULL)
		impl->idle_timeout = pw_loop_add_timer(main_loop, idle_timeout, impl);

	value.tv_sec = SAVE_INTERVAL;
	value.tv_nsec = 0;
	pw_loop_update_timer(main_loop, impl->idle_timeout, &value, NULL, false);
}

struct profile {
	struct sm_param *p;
	uint32_t index;
	const char *name;
	uint32_t prio;
	uint32_t available;
	bool save;
};

static int parse_profile(struct sm_param *p, struct profile *pr)
{
	pr->p = p;
	pr->prio = 0;
	pr->available = SPA_PARAM_AVAILABILITY_unknown;
	pr->save = false;
	return spa_pod_parse_object(p->param,
			SPA_TYPE_OBJECT_ParamProfile, NULL,
			SPA_PARAM_PROFILE_index, SPA_POD_Int(&pr->index),
			SPA_PARAM_PROFILE_name,  SPA_POD_String(&pr->name),
			SPA_PARAM_PROFILE_priority,  SPA_POD_OPT_Int(&pr->prio),
			SPA_PARAM_PROFILE_available,  SPA_POD_OPT_Id(&pr->available),
			SPA_PARAM_PROFILE_save,  SPA_POD_OPT_Bool(&pr->save));
}

static int find_current_profile(struct device *dev, struct profile *pr)
{
	struct sm_param *p;
	spa_list_for_each(p, &dev->obj->param_list, link) {
		if (p->id == SPA_PARAM_Profile &&
		    parse_profile(p, pr) >= 0)
			return 0;
	}
	return -ENOENT;
}

static int find_best_profile(struct device *dev, struct profile *pr)
{
	struct sm_param *p;
	struct profile best, best_avail, best_unk, off;

	spa_zero(best);
	spa_zero(best_avail);
	spa_zero(best_unk);
	spa_zero(off);

	spa_list_for_each(p, &dev->obj->param_list, link) {
		struct profile t;

		if (p->id != SPA_PARAM_EnumProfile ||
		    parse_profile(p, &t) < 0)
			continue;

		if (t.name && strcmp(t.name, "pro-audio") == 0)
			continue;

		if (t.name && strcmp(t.name, "off") == 0) {
			off = t;
		}
		else if (t.available == SPA_PARAM_AVAILABILITY_yes) {
			if (best_avail.name == NULL || t.prio > best_avail.prio)
				best_avail = t;
		}
		else if (t.available != SPA_PARAM_AVAILABILITY_no) {
			if (best_unk.name == NULL || t.prio > best_unk.prio)
				best_unk = t;
		}
	}
	best = best_avail;
	if (best.name == NULL)
		best = best_unk;
	if (best.name == NULL)
		best = off;
	if (best.name == NULL)
		return -ENOENT;
	*pr = best;
	return 0;
}

static int find_saved_profile(struct device *dev, struct profile *pr)
{
	struct spa_json it[2];
	struct impl *impl = dev->impl;
	const char *json, *value;
	char name[1024] = "\0", key[128];
	struct sm_param *p;

	json = pw_properties_get(impl->properties, dev->key);
	if (json == NULL)
		return -ENODEV;

	spa_json_init(&it[0], json, strlen(json));
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
                return -EINVAL;

	while (spa_json_get_string(&it[1], key, sizeof(key)-1) > 0) {
		if (strcmp(key, "name") == 0) {
			if (spa_json_get_string(&it[1], name, sizeof(name)) <= 0)
                                continue;
		} else {
			if (spa_json_next(&it[1], &value) <= 0)
                                break;
		}
	}
	pw_log_debug("device '%s': find profile '%s'", dev->name, name);

	spa_list_for_each(p, &dev->obj->param_list, link) {
		if (p->id != SPA_PARAM_EnumProfile ||
		    parse_profile(p, pr) < 0)
			continue;

		if (strcmp(pr->name, name) == 0)
			return 0;
	}
	return -ENOENT;
}

static int set_profile(struct device *dev, struct profile *pr)
{
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));

	if (dev->active_profile == pr->index)
		return 0;

	pw_device_set_param((struct pw_device*)dev->obj->obj.proxy,
			SPA_PARAM_Profile, 0,
			spa_pod_builder_add_object(&b,
				SPA_TYPE_OBJECT_ParamProfile, SPA_PARAM_Profile,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(pr->index),
				SPA_PARAM_PROFILE_save, SPA_POD_Bool(pr->save)));

	sm_media_session_schedule_rescan(dev->impl->session);

	return 0;
}

static int handle_active_profile(struct device *dev)
{
	struct impl *impl = dev->impl;
	struct profile pr;
	int res;

	/* check if current profile changed */
	if ((res = find_current_profile(dev, &pr)) < 0)
		return res;

	/* when the active profile is off, always try to restored the saved
	 * profile again */
	if (strcmp(pr.name, "off") == 0)
		dev->restored = false;

	if (dev->active_profile == pr.index) {
		/* no change, we're done */
		pw_log_info("device '%s': active profile '%s'", dev->name, pr.name);
		return 0;
	}

	/* we get here when we had configured a profile but something
	 * else changed it, in that case, save it when asked. */
	pw_log_info("device '%s': active profile changed to '%s'", dev->name, pr.name);
	dev->active_profile = pr.index;

	if (!pr.save)
		return 0;

	dev->saved_profile = pr.index;
	if (pw_properties_setf(impl->properties, dev->key, "{ \"name\": \"%s\" }", pr.name)) {
		pw_log_info("device '%s': active profile saved as '%s'", dev->name, pr.name);
		add_idle_timeout(impl);
	}
	return 0;
}

static int handle_profile_switch(struct device *dev)
{
	struct profile saved, best;
	int res;
	bool changed = false;

	/* try to find the next best profile */
	res = find_best_profile(dev, &best);
	if (res < 0) {
		pw_log_info("device '%s': can't find best profile: %s",
				dev->name, spa_strerror(res));
		best.index = SPA_ID_INVALID;
	} else {
		changed = dev->best_profile != best.index;
		dev->best_profile = best.index;
		pw_log_info("device '%s': found best profile '%s' changed:%d",
				dev->name, best.name, changed);
	}
	if (!dev->restored) {
		/* try to restore our saved profile */
		res = find_saved_profile(dev, &saved);
		if (res >= 0) {
			/* we found a saved profile */
			if (saved.available == SPA_PARAM_AVAILABILITY_no) {
				pw_log_info("device '%s': saved profile '%s' unavailable",
					dev->name, saved.name);
			} else {
				pw_log_info("device '%s': found saved profile '%s'",
							dev->name, saved.name);
				/* make sure we save again */
				saved.save = true;
				best = saved;
				changed = true;
			}
		} else {
			pw_log_info("device '%s': no saved profile: %s",
				dev->name, spa_strerror(res));
		}
		dev->restored = true;
	}

	if (best.index != SPA_ID_INVALID && changed) {
		if (dev->active_profile == best.index) {
			pw_log_info("device '%s': best profile '%s' is already active",
					dev->name, best.name);
		} else {
			pw_log_info("device '%s': restore best profile '%s' index %d",
					dev->name, best.name, best.index);
			set_profile(dev, &best);
		}
	} else if (res < 0) {
		pw_log_warn("device '%s': can't restore profile: %s", dev->name,
				spa_strerror(res));
	} else {
		pw_log_info("device '%s': no profile switch needed", dev->name);
	}
	return 0;
}

static int handle_profile(struct device *dev)
{
	/* check if current profile changed */
	handle_active_profile(dev);

	/* check if we need to switch profile */
	handle_profile_switch(dev);

	return 0;
}

static void object_update(void *data)
{
	struct device *dev = data;
	struct impl *impl = dev->impl;
	const char *str;

	pw_log_debug(NAME" %p: device %p %08x/%08x", impl, dev,
			dev->obj->obj.changed, dev->obj->obj.avail);

	if (dev->obj->info && dev->obj->info->props &&
	    (str = spa_dict_lookup(dev->obj->info->props, PW_KEY_DEVICE_BUS)) != NULL &&
	    strcmp(str, "bluetooth") == 0)
		return;

	if (dev->obj->obj.changed & SM_DEVICE_CHANGE_MASK_PARAMS)
		handle_profile(dev);
}

static const struct sm_object_events object_events = {
	SM_VERSION_OBJECT_EVENTS,
	.update = object_update
};

static void session_create(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	struct device *dev;
	const char *name;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Device) != 0 ||
	    object->props == NULL ||
	    (name = pw_properties_get(object->props, PW_KEY_DEVICE_NAME)) == NULL)
		return;

	pw_log_debug(NAME " %p: add device '%d' %s", impl, object->id, name);

	dev = sm_object_add_data(object, SESSION_KEY, sizeof(struct device));
	dev->obj = (struct sm_device*)object;
	dev->id = object->id;
	dev->impl = impl;
	dev->name = strdup(name);
	dev->key = spa_aprintf(PREFIX"%s", name);
	dev->active_profile = SPA_ID_INVALID;
	dev->saved_profile = SPA_ID_INVALID;
	dev->best_profile = SPA_ID_INVALID;

	dev->obj->obj.mask |= SM_DEVICE_CHANGE_MASK_PARAMS;
	sm_object_add_listener(&dev->obj->obj, &dev->listener, &object_events, dev);
}

static void destroy_device(struct impl *impl, struct device *dev)
{
	spa_hook_remove(&dev->listener);
	free(dev->name);
	free(dev->key);
	sm_object_remove_data((struct sm_object*)dev->obj, SESSION_KEY);
}

static void session_remove(void *data, struct sm_object *object)
{
	struct impl *impl = data;
	struct device *dev;

	if (strcmp(object->type, PW_TYPE_INTERFACE_Device) != 0)
		return;

	pw_log_debug(NAME " %p: remove device '%d'", impl, object->id);

	if ((dev = sm_object_get_data(object, SESSION_KEY)) != NULL)
		destroy_device(impl, dev);
}

static void session_destroy(void *data)
{
	struct impl *impl = data;
	remove_idle_timeout(impl);
	spa_hook_remove(&impl->listener);
	pw_properties_free(impl->properties);
	free(impl);
}

static const struct sm_media_session_events session_events = {
	SM_VERSION_MEDIA_SESSION_EVENTS,
	.create = session_create,
	.remove = session_remove,
	.destroy = session_destroy,
};

int sm_default_profile_start(struct sm_media_session *session)
{
	struct impl *impl;
	int res;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		return -errno;

	impl->session = session;
	impl->context = session->context;

	impl->properties = pw_properties_new(NULL, NULL);
	if (impl->properties == NULL) {
		free(impl);
		return -ENOMEM;
	}

	if ((res = sm_media_session_load_state(impl->session,
					SESSION_KEY, impl->properties)) < 0)
		pw_log_info("can't load "SESSION_KEY" state: %s", spa_strerror(res));

	sm_media_session_add_listener(impl->session, &impl->listener, &session_events, impl);

	return 0;
}
