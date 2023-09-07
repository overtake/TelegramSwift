/* CTL - PipeWire plugin
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

#include <alsa/asoundlib.h>
#include <alsa/control_external.h>

#include <spa/utils/result.h>
#include <spa/utils/json.h>
#include <spa/param/props.h>
#include <spa/param/audio/format-utils.h>

#include <pipewire/pipewire.h>
#include <extensions/metadata.h>

#define NAME "alsa-plugin"

#define VOLUME_MAX 65536

struct volume {
	uint32_t channels;
	long values[SPA_AUDIO_MAX_CHANNELS];
};

typedef struct {
	snd_ctl_ext_t ext;

	struct spa_system *system;
	struct pw_thread_loop *mainloop;

	struct pw_context *context;
	struct pw_core *core;
	struct spa_hook core_listener;

	struct pw_registry *registry;
	struct spa_hook registry_listener;

	struct pw_metadata *metadata;
	struct spa_hook metadata_listener;

	int fd;
	int last_seq;
	int pending_seq;
	int error;

	char default_sink[1024];
	int sink_muted;
	struct volume sink_volume;

	char default_source[1024];
	int source_muted;
	struct volume source_volume;

	int subscribed;

#define UPDATE_SINK_VOL     (1<<0)
#define UPDATE_SINK_MUTE    (1<<1)
#define UPDATE_SOURCE_VOL   (1<<2)
#define UPDATE_SOURCE_MUTE  (1<<3)
	int updated;

	struct spa_list globals;
} snd_ctl_pipewire_t;

struct global;

struct global_info {
	const char *type;
	uint32_t version;
	const void *events;
	pw_destroy_t destroy;
	int (*init) (struct global *g);
};

struct global {
	struct spa_list link;

	snd_ctl_pipewire_t *ctl;

	struct global_info *ginfo;

	uint32_t id;
	uint32_t permissions;
	struct pw_properties *props;

	struct pw_proxy *proxy;
	struct spa_hook proxy_listener;
	struct spa_hook object_listener;

	union {
		struct {
#define NODE_FLAG_SINK		(1<<0)
#define NODE_FLAG_SOURCE	(1<<1)
#define NODE_FLAG_DEVICE_VOLUME	(1<<2)
#define NODE_FLAG_DEVICE_MUTE	(1<<3)
			uint32_t flags;
			uint32_t device_id;
			uint32_t profile_device_id;
			int priority;
			float volume;
			bool mute;
			struct volume channel_volume;
		} node;
		struct {
			uint32_t active_route_output;
			uint32_t active_route_input;
		} device;
	};
};

#define SOURCE_VOL_NAME "Capture Volume"
#define SOURCE_MUTE_NAME "Capture Switch"
#define SINK_VOL_NAME "Master Playback Volume"
#define SINK_MUTE_NAME "Master Playback Switch"

static void do_resync(snd_ctl_pipewire_t *ctl)
{
	ctl->pending_seq = pw_core_sync(ctl->core, PW_ID_CORE, ctl->pending_seq);
}

static int wait_resync(snd_ctl_pipewire_t *ctl)
{
	do_resync(ctl);

	while (true) {
		pw_thread_loop_wait(ctl->mainloop);

		if (ctl->error)
			return ctl->error;

		if (ctl->pending_seq == ctl->last_seq)
			break;
	}
	return 0;
}

static struct global *find_global(snd_ctl_pipewire_t *ctl, uint32_t id,
		const char *name, const char *type)
{
	struct global *g;
	uint32_t name_id = name ? (uint32_t)atoi(name) : SPA_ID_INVALID;
	const char *str;

	spa_list_for_each(g, &ctl->globals, link) {
		if ((g->id == id || g->id == name_id) &&
		    (type == NULL || strcmp(g->ginfo->type, type) == 0))
			return g;
		if (name != NULL && name[0] != '\0' &&
		    (str = pw_properties_get(g->props, PW_KEY_NODE_NAME)) != NULL &&
		    strcmp(name, str) == 0)
			return g;
	}
	return NULL;
}

static struct global *find_best_node(snd_ctl_pipewire_t *ctl, uint32_t flags)
{
	struct global *g, *best = NULL;
	spa_list_for_each(g, &ctl->globals, link) {
		if ((strcmp(g->ginfo->type, PW_TYPE_INTERFACE_Node) == 0) &&
		    (flags == 0 || (g->node.flags & flags) == flags) &&
		    (best == NULL || best->node.priority < g->node.priority))
			best = g;
	}
	return best;
}

static inline int poll_activate(snd_ctl_pipewire_t *ctl)
{
	spa_system_eventfd_write(ctl->system, ctl->fd, 1);
	return 1;
}

static inline int poll_deactivate(snd_ctl_pipewire_t *ctl)
{
	uint64_t val;
	spa_system_eventfd_read(ctl->system, ctl->fd, &val);
	return 1;
}

static bool volume_equal(struct volume *a, struct volume *b)
{
	if (a == b)
		return true;
	if (a->channels != b->channels)
		return false;
	return memcmp(a->values, b->values, sizeof(float) * a->channels) == 0;
}

static int pipewire_update_volume(snd_ctl_pipewire_t * ctl)
{
	bool changed = false;
	struct global *g;

	if (ctl->default_sink[0] == '\0')
		g = find_best_node(ctl, NODE_FLAG_SINK);
	else
		g = find_global(ctl, SPA_ID_INVALID, ctl->default_sink,
				PW_TYPE_INTERFACE_Node);

	if (g) {
		if (!!ctl->sink_muted != !!g->node.mute) {
			ctl->sink_muted = g->node.mute;
			ctl->updated |= UPDATE_SINK_MUTE;
			changed = true;
		}
		if (!volume_equal(&ctl->sink_volume, &g->node.channel_volume)) {
			ctl->sink_volume = g->node.channel_volume;
			ctl->updated |= UPDATE_SINK_VOL;
			changed = true;
		}
	}

	if (ctl->default_source[0] == '\0')
		g = find_best_node(ctl, NODE_FLAG_SOURCE);
	else
		g = find_global(ctl, SPA_ID_INVALID, ctl->default_source,
				PW_TYPE_INTERFACE_Node);

	if (g) {
		if (!!ctl->source_muted != !!g->node.mute) {
			ctl->source_muted = g->node.mute;
			ctl->updated |= UPDATE_SOURCE_MUTE;
			changed = true;
		}
		if (!volume_equal(&ctl->source_volume, &g->node.channel_volume)) {
			ctl->source_volume = g->node.channel_volume;
			ctl->updated |= UPDATE_SOURCE_VOL;
			changed = true;
		}
	}

	if (changed)
		poll_activate(ctl);

	return 0;
}

static int pipewire_elem_count(snd_ctl_ext_t * ext)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int count = 0, err;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	pw_thread_loop_lock(ctl->mainloop);


	err = ctl->error;
	if (err < 0) {
		count = err;
		goto finish;
	}
	err = pipewire_update_volume(ctl);
	if (err < 0) {
		count = err;
		goto finish;
	}

	if (ctl->default_source[0] != '\0')
		count += 2;
	if (ctl->default_sink[0] != '\0')
		count += 2;

finish:
	pw_thread_loop_unlock(ctl->mainloop);

	return count;
}

static int pipewire_elem_list(snd_ctl_ext_t * ext, unsigned int offset,
			   snd_ctl_elem_id_t * id)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int err;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);

	pw_thread_loop_lock(ctl->mainloop);

	err = ctl->error;
	if (err < 0)
		goto finish;

	if (ctl->default_source[0] != '\0') {
		if (offset == 0)
			snd_ctl_elem_id_set_name(id, SOURCE_VOL_NAME);
		else if (offset == 1)
			snd_ctl_elem_id_set_name(id, SOURCE_MUTE_NAME);
	} else
		offset += 2;

	err = 0;
finish:
	pw_thread_loop_unlock(ctl->mainloop);

	if (err >= 0) {
		if (offset == 2)
			snd_ctl_elem_id_set_name(id, SINK_VOL_NAME);
		else if (offset == 3)
			snd_ctl_elem_id_set_name(id, SINK_MUTE_NAME);
	}

	return err;
}

static snd_ctl_ext_key_t pipewire_find_elem(snd_ctl_ext_t * ext,
					 const snd_ctl_elem_id_t * id)
{
	const char *name;
	unsigned int numid;

	numid = snd_ctl_elem_id_get_numid(id);
	if (numid > 0 && numid <= 4)
		return numid - 1;

	name = snd_ctl_elem_id_get_name(id);

	if (strcmp(name, SOURCE_VOL_NAME) == 0)
		return 0;
	if (strcmp(name, SOURCE_MUTE_NAME) == 0)
		return 1;
	if (strcmp(name, SINK_VOL_NAME) == 0)
		return 2;
	if (strcmp(name, SINK_MUTE_NAME) == 0)
		return 3;

	return SND_CTL_EXT_KEY_NOT_FOUND;
}

static int pipewire_get_attribute(snd_ctl_ext_t * ext, snd_ctl_ext_key_t key,
			       int *type, unsigned int *acc,
			       unsigned int *count)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int err = 0;

	if (key > 3)
		return -EINVAL;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	pw_thread_loop_lock(ctl->mainloop);

	err = ctl->error;
	if (err < 0)
		goto finish;

	err = pipewire_update_volume(ctl);
	if (err < 0)
		goto finish;

	if (key & 1)
		*type = SND_CTL_ELEM_TYPE_BOOLEAN;
	else
		*type = SND_CTL_ELEM_TYPE_INTEGER;

	*acc = SND_CTL_EXT_ACCESS_READWRITE;

	if (key == 0)
		*count = ctl->source_volume.channels;
	else if (key == 2)
		*count = ctl->sink_volume.channels;
	else
		*count = 1;

finish:
	pw_thread_loop_unlock(ctl->mainloop);

	return err;
}

static int pipewire_get_integer_info(snd_ctl_ext_t * ext,
				  snd_ctl_ext_key_t key, long *imin,
				  long *imax, long *istep)
{
	*istep = 1;
	*imin = 0;
	*imax = VOLUME_MAX;

	return 0;
}

static int pipewire_read_integer(snd_ctl_ext_t * ext, snd_ctl_ext_key_t key,
			      long *value)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int err = 0;
	uint32_t i;
	struct volume *vol = NULL;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	pw_thread_loop_lock(ctl->mainloop);

	err = ctl->error;
	if (err < 0)
		goto finish;

	err = pipewire_update_volume(ctl);
	if (err < 0)
		goto finish;

	switch (key) {
	case 0:
		vol = &ctl->source_volume;
		break;
	case 1:
		*value = !ctl->source_muted;
		break;
	case 2:
		vol = &ctl->sink_volume;
		break;
	case 3:
		*value = !ctl->sink_muted;
		break;
	default:
		err = -EINVAL;
		goto finish;
	}

	if (vol) {
		for (i = 0; i < vol->channels; i++)
			value[i] = vol->values[i];
	}

finish:
	pw_thread_loop_unlock(ctl->mainloop);

	return err;
}

static struct spa_pod *build_volume_mute(struct spa_pod_builder *b, struct volume *volume, int *mute)
{
	struct spa_pod_frame f[1];

	spa_pod_builder_push_object(b, &f[0],
			SPA_TYPE_OBJECT_Props, SPA_PARAM_Props);
	if (volume) {
		float volumes[SPA_AUDIO_MAX_CHANNELS];
		uint32_t i, n_volumes = 0;

		n_volumes = volume->channels;
		for (i = 0; i < n_volumes; i++)
			volumes[i] = volume->values[i] / (float) VOLUME_MAX;

		spa_pod_builder_prop(b, SPA_PROP_channelVolumes, 0);
		spa_pod_builder_array(b, sizeof(float),
			SPA_TYPE_Float, n_volumes, volumes);
	}
	if (mute) {
		spa_pod_builder_prop(b, SPA_PROP_mute, 0);
		spa_pod_builder_bool(b, *mute ? true : false);
	}
	return spa_pod_builder_pop(b, &f[0]);
}

static int set_volume_mute(snd_ctl_pipewire_t *ctl, const char *name, struct volume *volume, int *mute)
{
	struct global *g, *dg;
	uint32_t id = SPA_ID_INVALID, device_id = SPA_ID_INVALID;
	char buf[1024];
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
	struct spa_pod_frame f[2];
	struct spa_pod *param;

	g = find_global(ctl, SPA_ID_INVALID, name, PW_TYPE_INTERFACE_Node);
	if (g == NULL)
		return -EINVAL;

	if (SPA_FLAG_IS_SET(g->node.flags, NODE_FLAG_DEVICE_VOLUME) &&
	    (dg = find_global(ctl, g->node.device_id, NULL, PW_TYPE_INTERFACE_Device)) != NULL) {
		if (g->node.flags & NODE_FLAG_SINK)
			id = dg->device.active_route_output;
		else if (g->node.flags & NODE_FLAG_SOURCE)
			id = dg->device.active_route_input;
		device_id = g->node.profile_device_id;
	}
	pw_log_debug("id %d device_id %d flags:%08x", id, device_id, g->node.flags);
	if (id != SPA_ID_INVALID && device_id != SPA_ID_INVALID) {
		if (!SPA_FLAG_IS_SET(dg->permissions, PW_PERM_W | PW_PERM_X))
			return -EPERM;

		spa_pod_builder_push_object(&b, &f[0],
			SPA_TYPE_OBJECT_ParamRoute, SPA_PARAM_Route);
		spa_pod_builder_add(&b,
			SPA_PARAM_ROUTE_index, SPA_POD_Int(id),
			SPA_PARAM_ROUTE_device, SPA_POD_Int(device_id),
			0);

		spa_pod_builder_prop(&b, SPA_PARAM_ROUTE_props, 0);
		build_volume_mute(&b, volume, mute);
		param = spa_pod_builder_pop(&b, &f[0]);

		pw_log_debug("set device %d mute/volume for node %d", dg->id, g->id);
		pw_device_set_param((struct pw_node*)dg->proxy,
			SPA_PARAM_Route, 0, param);
	} else {
		if (!SPA_FLAG_IS_SET(g->permissions, PW_PERM_W | PW_PERM_X))
			return -EPERM;

		param = build_volume_mute(&b, volume, mute);

		pw_log_debug("set node %d mute/volume", g->id);
		pw_node_set_param((struct pw_node*)g->proxy,
			SPA_PARAM_Props, 0, param);
	}
	return 0;
}

static int pipewire_write_integer(snd_ctl_ext_t * ext, snd_ctl_ext_key_t key,
			       long *value)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int err = 0;
	uint32_t i;
	struct volume *vol = NULL;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	pw_thread_loop_lock(ctl->mainloop);

	err = ctl->error;
	if (err < 0)
		goto finish;

	err = pipewire_update_volume(ctl);
	if (err < 0)
		goto finish;

	switch (key) {
	case 0:
		vol = &ctl->source_volume;
		break;
	case 1:
		if (!!ctl->source_muted == !*value)
			goto finish;
		ctl->source_muted = !*value;
		break;
	case 2:
		vol = &ctl->sink_volume;
		break;
	case 3:
		if (!!ctl->sink_muted == !*value)
			goto finish;
		ctl->sink_muted = !*value;
		break;
	default:
		err = -EINVAL;
		goto finish;
	}

	if (vol) {
		for (i = 0; i < vol->channels; i++)
			if (value[i] != vol->values[i])
				break;

		if (i == vol->channels)
			goto finish;

		for (i = 0; i < vol->channels; i++)
			vol->values[i] = value[i];

		if (key == 0)
			set_volume_mute(ctl, ctl->default_source, vol, NULL);
		else
			set_volume_mute(ctl, ctl->default_sink, vol, NULL);
	} else {
		if (key == 1)
			set_volume_mute(ctl, ctl->default_source, NULL, &ctl->source_muted);
		else
			set_volume_mute(ctl, ctl->default_sink, NULL, &ctl->sink_muted);
	}

	wait_resync(ctl);

	if (err < 0)
		goto finish;

	err = 1;

finish:
	pw_thread_loop_unlock(ctl->mainloop);

	return err;
}

static void pipewire_subscribe_events(snd_ctl_ext_t * ext, int subscribe)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;

	assert(ctl);

	if (!ctl->mainloop)
		return;

	pw_thread_loop_lock(ctl->mainloop);

	ctl->subscribed = !!(subscribe & SND_CTL_EVENT_MASK_VALUE);

	pw_thread_loop_unlock(ctl->mainloop);
}

static int pipewire_read_event(snd_ctl_ext_t * ext, snd_ctl_elem_id_t * id,
			    unsigned int *event_mask)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int offset;
	int err;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	pw_thread_loop_lock(ctl->mainloop);

	err = ctl->error;
	if (err < 0)
		goto finish;

	if (!ctl->updated || !ctl->subscribed) {
		err = -EAGAIN;
		goto finish;
	}

	if (ctl->default_source[0] != '\0')
		offset = 2;
	else
		offset = 0;

	if (ctl->updated & UPDATE_SOURCE_VOL) {
		pipewire_elem_list(ext, 0, id);
		ctl->updated &= ~UPDATE_SOURCE_VOL;
	} else if (ctl->updated & UPDATE_SOURCE_MUTE) {
		pipewire_elem_list(ext, 1, id);
		ctl->updated &= ~UPDATE_SOURCE_MUTE;
	} else if (ctl->updated & UPDATE_SINK_VOL) {
		pipewire_elem_list(ext, offset + 0, id);
		ctl->updated &= ~UPDATE_SINK_VOL;
	} else if (ctl->updated & UPDATE_SINK_MUTE) {
		pipewire_elem_list(ext, offset + 1, id);
		ctl->updated &= ~UPDATE_SINK_MUTE;
	}

	*event_mask = SND_CTL_EVENT_MASK_VALUE;

	if (!ctl->updated)
		poll_deactivate(ctl);

	err = 1;

finish:
	pw_thread_loop_unlock(ctl->mainloop);

	return err;
}

static int pipewire_ctl_poll_revents(snd_ctl_ext_t * ext, struct pollfd *pfd,
				  unsigned int nfds,
				  unsigned short *revents)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	int err = 0;

	assert(ctl);

	if (!ctl->mainloop)
		return -EBADFD;

	pw_thread_loop_lock(ctl->mainloop);

	err = ctl->error;
	if (err < 0)
		goto finish;

	if (ctl->updated)
		*revents = POLLIN;
	else
		*revents = 0;

	err = 0;

finish:
	pw_thread_loop_unlock(ctl->mainloop);

	return err;
}

static void snd_ctl_pipewire_free(snd_ctl_pipewire_t *ctl)
{
	if (ctl == NULL)
		return;

	pw_log_debug(NAME" %p:", ctl);
	if (ctl->mainloop)
		pw_thread_loop_stop(ctl->mainloop);
	if (ctl->registry)
		pw_proxy_destroy((struct pw_proxy*)ctl->registry);
	if (ctl->context)
		pw_context_destroy(ctl->context);
	if (ctl->fd >= 0)
		spa_system_close(ctl->system, ctl->fd);
	if (ctl->mainloop)
		pw_thread_loop_destroy(ctl->mainloop);
	free(ctl);
}

static void pipewire_close(snd_ctl_ext_t * ext)
{
	snd_ctl_pipewire_t *ctl = ext->private_data;
	snd_ctl_pipewire_free(ctl);
}

static const snd_ctl_ext_callback_t pipewire_ext_callback = {
	.elem_count = pipewire_elem_count,
	.elem_list = pipewire_elem_list,
	.find_elem = pipewire_find_elem,
	.get_attribute = pipewire_get_attribute,
	.get_integer_info = pipewire_get_integer_info,
	.read_integer = pipewire_read_integer,
	.write_integer = pipewire_write_integer,
	.subscribe_events = pipewire_subscribe_events,
	.read_event = pipewire_read_event,
	.poll_revents = pipewire_ctl_poll_revents,
	.close = pipewire_close,
};

/** device */
static void device_event_info(void *object, const struct pw_device_info *info)
{
	struct global *g = object;
	snd_ctl_pipewire_t *ctl = g->ctl;
	uint32_t n;

	pw_log_debug("info");

	if (info->change_mask & PW_DEVICE_CHANGE_MASK_PARAMS) {
		for (n = 0; n < info->n_params; n++) {
			if (!(info->params[n].flags & SPA_PARAM_INFO_READ))
				continue;

			switch (info->params[n].id) {
                        case SPA_PARAM_Route:
                                pw_device_enum_params((struct pw_device*)g->proxy,
                                        0, info->params[n].id, 0, -1, NULL);
                                break;
                        default:
                                break;
                        }
                }

	}
	do_resync(ctl);
}

static void parse_props(struct global *g, const struct spa_pod *param, bool device)
{
	struct spa_pod_prop *prop;
	struct spa_pod_object *obj = (struct spa_pod_object *) param;

	SPA_POD_OBJECT_FOREACH(obj, prop) {
		switch (prop->key) {
		case SPA_PROP_volume:
			if (spa_pod_get_float(&prop->value, &g->node.volume) < 0)
				continue;
			pw_log_debug("update node %d volume", g->id);
			SPA_FLAG_UPDATE(g->node.flags, NODE_FLAG_DEVICE_VOLUME, device);
			break;
		case SPA_PROP_mute:
			if (spa_pod_get_bool(&prop->value, &g->node.mute) < 0)
				continue;
			SPA_FLAG_UPDATE(g->node.flags, NODE_FLAG_DEVICE_MUTE, device);
			pw_log_debug("update node %d mute", g->id);
			break;
		case SPA_PROP_channelVolumes:
		{
			float volumes[SPA_AUDIO_MAX_CHANNELS];
			uint32_t n_volumes, i;

			n_volumes = spa_pod_copy_array(&prop->value, SPA_TYPE_Float,
					volumes, SPA_AUDIO_MAX_CHANNELS);

			g->node.channel_volume.channels = n_volumes;
			for (i = 0; i < n_volumes; i++)
				g->node.channel_volume.values[i] = volumes[i] * VOLUME_MAX;

			SPA_FLAG_UPDATE(g->node.flags, NODE_FLAG_DEVICE_VOLUME, device);
			pw_log_debug("update node %d channelVolumes", g->id);
			break;
		}
		default:
			break;
		}
	}
}

static struct global *find_node_for_route(snd_ctl_pipewire_t *ctl, uint32_t card, uint32_t device)
{
	struct global *n;
	spa_list_for_each(n, &ctl->globals, link) {
		if (strcmp(n->ginfo->type, PW_TYPE_INTERFACE_Node) == 0 &&
		    (n->node.device_id == card) &&
		    (n->node.profile_device_id == device))
			return n;
	}
	return NULL;
}

static void device_event_param(void *object, int seq,
                uint32_t id, uint32_t index, uint32_t next,
                const struct spa_pod *param)
{
	struct global *g = object;
	snd_ctl_pipewire_t *ctl = g->ctl;

	pw_log_debug("param %d", id);

	switch (id) {
	case SPA_PARAM_Route:
	{
		uint32_t index, device;
		enum spa_direction direction;
		struct spa_pod *props = NULL;
		struct global *ng;

		if (spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamRoute, NULL,
				SPA_PARAM_ROUTE_index, SPA_POD_Int(&index),
				SPA_PARAM_ROUTE_direction, SPA_POD_Id(&direction),
				SPA_PARAM_ROUTE_device, SPA_POD_Int(&device),
				SPA_PARAM_ROUTE_props, SPA_POD_OPT_Pod(&props)) < 0) {
			pw_log_warn("device %d: can't parse route", g->id);
			return;
		}
		if (direction == SPA_DIRECTION_OUTPUT)
			g->device.active_route_output = index;
                else
                        g->device.active_route_input = index;

		pw_log_debug("device %d: active %s route %d", g->id,
				direction == SPA_DIRECTION_OUTPUT ? "output" : "input",
				index);

		ng = find_node_for_route(ctl, g->id, device);
		if (props && ng)
			parse_props(ng, props, true);
		break;
	}
	default:
		break;
	}
}

static const struct pw_device_events device_events = {
	PW_VERSION_DEVICE_EVENTS,
	.info = device_event_info,
	.param = device_event_param,
};

struct global_info device_info = {
	.type = PW_TYPE_INTERFACE_Device,
	.version = PW_VERSION_DEVICE,
	.events = &device_events,
};

/** node */
static void node_event_info(void *object, const struct pw_node_info *info)
{
	struct global *g = object;
	snd_ctl_pipewire_t *ctl = g->ctl;
	const char *str;
	uint32_t i;

	pw_log_debug("update %d %"PRIu64, g->id, info->change_mask);

	if (info->change_mask & PW_NODE_CHANGE_MASK_PROPS && info->props) {
		if ((str = spa_dict_lookup(info->props, "card.profile.device")))
			g->node.profile_device_id = atoi(str);
		else
			g->node.profile_device_id = SPA_ID_INVALID;

		if ((str = spa_dict_lookup(info->props, PW_KEY_DEVICE_ID)))
			g->node.device_id = atoi(str);
		else
			g->node.device_id = SPA_ID_INVALID;

		if ((str = spa_dict_lookup(info->props, PW_KEY_PRIORITY_SESSION)))
			g->node.priority = atoi(str);
		if ((str = spa_dict_lookup(info->props, PW_KEY_MEDIA_CLASS))) {
			if (strcmp(str, "Audio/Sink") == 0)
				g->node.flags |= NODE_FLAG_SINK;
			else if (strcmp(str, "Audio/Source") == 0)
				g->node.flags |= NODE_FLAG_SOURCE;
		}
	}
	if (info->change_mask & PW_NODE_CHANGE_MASK_PARAMS) {
		for (i = 0; i < info->n_params; i++) {
			if (!(info->params[i].flags & SPA_PARAM_INFO_READ))
				continue;

			switch (info->params[i].id) {
			case SPA_PARAM_Props:
				pw_node_enum_params((struct pw_node*)g->proxy,
					0, info->params[i].id, 0, -1, NULL);
				break;
			default:
				break;
			}
		}
	}
	do_resync(ctl);
}


static void node_event_param(void *object, int seq,
                uint32_t id, uint32_t index, uint32_t next,
                const struct spa_pod *param)
{
	struct global *g = object;
	pw_log_debug("update param %d %d", g->id, id);

	switch (id) {
	case SPA_PARAM_Props:
		if (!SPA_FLAG_IS_SET(g->node.flags, NODE_FLAG_DEVICE_VOLUME | NODE_FLAG_DEVICE_MUTE))
			parse_props(g, param, false);
		break;
	default:
		break;
	}
}

static const struct pw_node_events node_events = {
	PW_VERSION_NODE_EVENTS,
	.info = node_event_info,
	.param = node_event_param,
};

struct global_info node_info = {
	.type = PW_TYPE_INTERFACE_Node,
	.version = PW_VERSION_NODE,
	.events = &node_events,
};

/** metadata */
static int json_object_find(const char *obj, const char *key, char *value, size_t len)
{
	struct spa_json it[2];
	const char *v;
	char k[128];

	spa_json_init(&it[0], obj, strlen(obj));
	if (spa_json_enter_object(&it[0], &it[1]) <= 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], k, sizeof(k)-1) > 0) {
		if (strcmp(k, key) == 0) {
			if (spa_json_get_string(&it[1], value, len) <= 0)
				continue;
			return 0;
		} else {
			if (spa_json_next(&it[1], &v) <= 0)
				break;
		}
	}
	return -ENOENT;
}

static int metadata_property(void *object,
                        uint32_t subject,
                        const char *key,
                        const char *type,
                        const char *value)
{
	struct global *g = object;
	snd_ctl_pipewire_t *ctl = g->ctl;

	if (subject == PW_ID_CORE) {
		if (key == NULL || strcmp(key, "default.audio.sink") == 0) {
			if (value == NULL ||
			    json_object_find(value, "name",
					ctl->default_sink, sizeof(ctl->default_sink)) < 0)
				ctl->default_sink[0] = '\0';
			pw_log_debug("found default sink: %s", ctl->default_sink);
		}
		if (key == NULL || strcmp(key, "default.audio.source") == 0) {
			if (value == NULL ||
			    json_object_find(value, "name",
					ctl->default_source, sizeof(ctl->default_source)) < 0)
				ctl->default_source[0] = '\0';
			pw_log_debug("found default source: %s", ctl->default_source);
		}
        }
        return 0;
}

static int metadata_init(struct global *g)
{
	snd_ctl_pipewire_t *ctl = g->ctl;
	ctl->metadata = (struct pw_metadata*)g->proxy;
	return 0;
}

static const struct pw_metadata_events metadata_events = {
	PW_VERSION_METADATA_EVENTS,
	.property = metadata_property,
};

struct global_info metadata_info = {
	.type = PW_TYPE_INTERFACE_Metadata,
	.version = PW_VERSION_METADATA,
	.events = &metadata_events,
	.init = metadata_init
};

/** proxy */
static void proxy_removed(void *data)
{
	struct global *g = data;
	pw_proxy_destroy(g->proxy);
}

static void proxy_destroy(void *data)
{
	struct global *g = data;
	spa_list_remove(&g->link);
	g->proxy = NULL;
}

static const struct pw_proxy_events proxy_events = {
	PW_VERSION_PROXY_EVENTS,
	.removed = proxy_removed,
	.destroy = proxy_destroy
};

static void registry_event_global(void *data, uint32_t id,
		uint32_t permissions, const char *type, uint32_t version,
		const struct spa_dict *props)
{
	snd_ctl_pipewire_t *ctl = data;
	struct global_info *info = NULL;
	struct pw_proxy *proxy;
	const char *str;

	pw_log_debug("got %d %s", id, type);

	if (strcmp(type, PW_TYPE_INTERFACE_Device) == 0) {
		if (props == NULL ||
		    ((str = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS)) == NULL) ||
		    (strcmp(str, "Audio/Device") != 0))
			return;

		pw_log_debug("found device %d", id);
		info = &device_info;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
		if (props == NULL ||
		    ((str = spa_dict_lookup(props, PW_KEY_MEDIA_CLASS)) == NULL) ||
		    ((strcmp(str, "Audio/Sink") != 0) &&
		     (strcmp(str, "Audio/Source") != 0)))
			return;

		pw_log_debug("found node %d type:%s", id, str);
		info = &node_info;
	} else if (strcmp(type, PW_TYPE_INTERFACE_Metadata) == 0) {
		if (ctl->metadata != NULL)
			return;
		info = &metadata_info;
	}
	if (info) {
		struct global *g;

		proxy = pw_registry_bind(ctl->registry,
				id, info->type, info->version,
				sizeof(struct global));

		g = pw_proxy_get_user_data(proxy);
		g->ctl = ctl;
		g->ginfo = info;
		g->id = id;
		g->permissions = permissions;
		g->props = props ? pw_properties_new_dict(props) : NULL;
		g->proxy = proxy;
		spa_list_append(&ctl->globals, &g->link);

		pw_proxy_add_listener(proxy,
				&g->proxy_listener,
				&proxy_events, g);

		if (info->events) {
			pw_proxy_add_object_listener(proxy,
					&g->object_listener,
					info->events, g);
		}
		if (info->init)
			info->init(g);

		do_resync(ctl);
	}
}

static void registry_event_global_remove(void *data, uint32_t id)
{
	snd_ctl_pipewire_t *ctl = data;
	struct global *g;
	const char *name;

	if ((g = find_global(ctl, id, NULL, PW_TYPE_INTERFACE_Node)) == NULL)
		return;
	if ((name = pw_properties_get(g->props, PW_KEY_NODE_NAME)) == NULL)
		return;

	if (strcmp(name, ctl->default_sink) == 0)
		ctl->default_sink[0] = '\0';
	if (strcmp(name, ctl->default_source) == 0)
		ctl->default_source[0] = '\0';
}

static const struct pw_registry_events registry_events = {
        PW_VERSION_REGISTRY_EVENTS,
        .global = registry_event_global,
        .global_remove = registry_event_global_remove,
};

static void on_core_error(void *data, uint32_t id, int seq, int res, const char *message)
{
	snd_ctl_pipewire_t *ctl = data;

	pw_log_warn(NAME" %p: error id:%u seq:%d res:%d (%s): %s", ctl,
			id, seq, res, spa_strerror(res), message);

	if (id == PW_ID_CORE) {
		ctl->error = res;
		if (ctl->fd != -1)
			poll_activate(ctl);
	}
	pw_thread_loop_signal(ctl->mainloop, false);
}

static void on_core_done(void *data, uint32_t id, int seq)
{
	snd_ctl_pipewire_t *ctl = data;

	pw_log_debug("done %d %d %d", id, seq, ctl->pending_seq);

	if (id != PW_ID_CORE)
		return;

	ctl->last_seq = ctl->pending_seq;
	if (seq == ctl->pending_seq) {
		pipewire_update_volume(ctl);
		pw_thread_loop_signal(ctl->mainloop, false);
	}
}

static const struct pw_core_events core_events = {
	PW_VERSION_CORE_EVENTS,
        .error = on_core_error,
        .done = on_core_done,
};


SPA_EXPORT
SND_CTL_PLUGIN_DEFINE_FUNC(pipewire)
{
	snd_config_iterator_t i, next;
	const char *server = NULL;
	const char *device = NULL;
	const char *source = NULL;
	const char *sink = NULL;
	const char *fallback_name = NULL;
	int err;
	const char *str;
	struct pw_properties *props = NULL;
	snd_ctl_pipewire_t *ctl;
	struct pw_loop *loop;

        pw_init(NULL, NULL);

	snd_config_for_each(i, next, conf) {
		snd_config_t *n = snd_config_iterator_entry(i);
		const char *id;
		if (snd_config_get_id(n, &id) < 0)
			continue;
		if (strcmp(id, "comment") == 0 || strcmp(id, "type") == 0
		    || strcmp(id, "hint") == 0)
			continue;
		if (strcmp(id, "server") == 0) {
			if (snd_config_get_string(n, &server) < 0) {
				SNDERR("Invalid type for %s", id);
				return -EINVAL;
			} else if (!*server) {
				server = NULL;
			}
			continue;
		}
		if (strcmp(id, "device") == 0) {
			if (snd_config_get_string(n, &device) < 0) {
				SNDERR("Invalid type for %s", id);
				return -EINVAL;
			} else if (!*device) {
				device = NULL;
			}
			continue;
		}
		if (strcmp(id, "source") == 0) {
			if (snd_config_get_string(n, &source) < 0) {
				SNDERR("Invalid type for %s", id);
				return -EINVAL;
			} else if (!*source) {
				source = NULL;
			}
			continue;
		}
		if (strcmp(id, "sink") == 0) {
			if (snd_config_get_string(n, &sink) < 0) {
				SNDERR("Invalid type for %s", id);
				return -EINVAL;
			} else if (!*sink) {
				sink = NULL;
			}
			continue;
		}
		if (strcmp(id, "fallback") == 0) {
			if (snd_config_get_string(n, &fallback_name) < 0) {
				SNDERR("Invalid value for %s", id);
				return -EINVAL;
			}
			continue;
		}
		SNDERR("Unknown field %s", id);
		return -EINVAL;
	}

	str = getenv("PIPEWIRE_REMOTE");
	if (str != NULL && str[0] != '\0')
		server = str;

	if (fallback_name && name && !strcmp(name, fallback_name))
		fallback_name = NULL; /* no fallback for the same name */

	ctl = calloc(1, sizeof(*ctl));
	if (!ctl)
		return -ENOMEM;

	spa_list_init(&ctl->globals);

	if (source == NULL)
		source = device;
	if (source != NULL)
		snprintf(ctl->default_source, sizeof(ctl->default_source),
				"%s", source);
	if (sink == NULL)
		sink = device;
	if (sink != NULL)
		snprintf(ctl->default_sink, sizeof(ctl->default_sink),
				"%s", sink);

	ctl->mainloop = pw_thread_loop_new("alsa-pipewire", NULL);
	if (ctl->mainloop == NULL) {
		err = -errno;
		goto error;
	}
	loop = pw_thread_loop_get_loop(ctl->mainloop);

	ctl->system = loop->system;
	ctl->fd = spa_system_eventfd_create(ctl->system, SPA_FD_CLOEXEC | SPA_FD_NONBLOCK);
	if (ctl->fd == -1) {
		err = -errno;
		goto error;
	}

	ctl->context = pw_context_new(loop, NULL, 0);
	if (ctl->context == NULL) {
		err = -errno;
		goto error;
	}

	props = pw_properties_new(NULL, NULL);
	if (props == NULL) {
		err = -errno;
		goto error;
	}

	pw_properties_setf(props, PW_KEY_APP_NAME, "PipeWire ALSA [%s]",
			pw_get_prgname());

	if (server)
		pw_properties_set(props, PW_KEY_REMOTE_NAME, server);

	if ((err = pw_thread_loop_start(ctl->mainloop)) < 0)
		goto error;

	pw_thread_loop_lock(ctl->mainloop);
	ctl->core = pw_context_connect(ctl->context, props, 0);
	props = NULL;
	if (ctl->core == NULL) {
		err = -errno;
		goto error_unlock;
	}
	pw_core_add_listener(ctl->core,
			&ctl->core_listener,
			&core_events, ctl);

	ctl->registry = pw_core_get_registry(ctl->core, PW_VERSION_REGISTRY, 0);
	if (ctl->registry == NULL) {
		err = -errno;
		goto error_unlock;
	}

	pw_registry_add_listener(ctl->registry,
			&ctl->registry_listener,
			&registry_events, ctl);

	wait_resync(ctl);

	pw_thread_loop_unlock(ctl->mainloop);

	ctl->ext.version = SND_CTL_EXT_VERSION;
	ctl->ext.card_idx = 0;
	strncpy(ctl->ext.id, "pipewire", sizeof(ctl->ext.id) - 1);
	strncpy(ctl->ext.driver, "PW plugin", sizeof(ctl->ext.driver) - 1);
	strncpy(ctl->ext.name, "PipeWire", sizeof(ctl->ext.name) - 1);
	strncpy(ctl->ext.longname, "PipeWire", sizeof(ctl->ext.longname) - 1);
	strncpy(ctl->ext.mixername, "PipeWire", sizeof(ctl->ext.mixername) - 1);
	ctl->ext.poll_fd = ctl->fd;

	ctl->ext.callback = &pipewire_ext_callback;
	ctl->ext.private_data = ctl;

	err = snd_ctl_ext_create(&ctl->ext, name, mode);
	if (err < 0)
		goto error;

	*handlep = ctl->ext.handle;

	return 0;

error_unlock:
	pw_thread_loop_unlock(ctl->mainloop);
error:
	snd_ctl_pipewire_free(ctl);
	pw_log_error("error %d (%s)", err, spa_strerror(err));

	if (fallback_name)
		return snd_ctl_open_fallback(handlep, root,
					     fallback_name, name, mode);

	return err;
}

SPA_EXPORT
SND_CTL_PLUGIN_SYMBOL(pipewire);
