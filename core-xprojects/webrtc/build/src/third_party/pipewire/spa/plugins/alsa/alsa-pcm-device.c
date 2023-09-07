/* Spa ALSA Device
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

#include <stddef.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <poll.h>

#include <alsa/asoundlib.h>

#include <spa/support/log.h>
#include <spa/utils/type.h>
#include <spa/node/node.h>
#include <spa/utils/keys.h>
#include <spa/utils/names.h>
#include <spa/support/loop.h>
#include <spa/support/plugin.h>
#include <spa/monitor/device.h>
#include <spa/monitor/utils.h>
#include <spa/param/param.h>
#include <spa/pod/filter.h>
#include <spa/pod/parser.h>
#include <spa/debug/pod.h>

#define NAME  "alsa-device"

#define MAX_DEVICES	64

static const char default_device[] = "hw:0";

struct props {
	char device[64];
};

static void reset_props(struct props *props)
{
	strncpy(props->device, default_device, 64);
}

struct impl {
	struct spa_handle handle;
	struct spa_device device;

	struct spa_log *log;

	struct spa_hook_list hooks;

	struct props props;
	uint32_t n_nodes;
	uint32_t n_capture;
	uint32_t n_playback;

	uint32_t profile;
};

static const char *get_stream(snd_pcm_info_t *pcminfo)
{
	switch (snd_pcm_info_get_stream(pcminfo)) {
	case SND_PCM_STREAM_PLAYBACK:
		return "playback";
	case SND_PCM_STREAM_CAPTURE:
		return "capture";
	default:
		return "unknown";
	}
}

static const char *get_class(snd_pcm_info_t *pcminfo)
{
	switch (snd_pcm_info_get_class(pcminfo)) {
	case SND_PCM_CLASS_GENERIC:
		return "generic";
	case SND_PCM_CLASS_MULTI:
		return "multichannel";
	case SND_PCM_CLASS_MODEM:
		return "modem";
	case SND_PCM_CLASS_DIGITIZER:
		return "digitizer";
	default:
		return "unknown";
	}
}

static const char *get_subclass(snd_pcm_info_t *pcminfo)
{
	switch (snd_pcm_info_get_subclass(pcminfo)) {
	case SND_PCM_SUBCLASS_GENERIC_MIX:
		return "generic-mix";
	case SND_PCM_SUBCLASS_MULTI_MIX:
		return "multichannel-mix";
	default:
		return "unknown";
	}
}

static int emit_node(struct impl *this, snd_ctl_card_info_t *cardinfo, snd_pcm_info_t *pcminfo, uint32_t id)
{
	struct spa_dict_item items[12];
	char device_name[128], path[180];
	char sync_name[128], dev[16], subdev[16], card[16];
	struct spa_device_object_info info;
	snd_pcm_sync_id_t sync_id;
	const char *stream;

	info = SPA_DEVICE_OBJECT_INFO_INIT();
	info.type = SPA_TYPE_INTERFACE_Node;

	if (snd_pcm_info_get_stream(pcminfo) == SND_PCM_STREAM_PLAYBACK) {
		info.factory_name = SPA_NAME_API_ALSA_PCM_SINK;
		stream = "playback";
	} else {
		info.factory_name = SPA_NAME_API_ALSA_PCM_SOURCE;
		stream = "capture";
	}

	info.change_mask = SPA_DEVICE_OBJECT_CHANGE_MASK_PROPS;

	snprintf(card, sizeof(card), "%d", snd_pcm_info_get_card(pcminfo));
	snprintf(dev, sizeof(dev), "%d", snd_pcm_info_get_device(pcminfo));
	snprintf(subdev, sizeof(subdev), "%d", snd_pcm_info_get_subdevice(pcminfo));
	snprintf(device_name, sizeof(device_name), "%s,%s", this->props.device, dev);
	snprintf(path, sizeof(path), "alsa:pcm:%s:%s:%s", snd_ctl_card_info_get_id(cardinfo), dev, stream);
	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_OBJECT_PATH,	       path);
	items[1] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PATH,           device_name);
	items[2] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_CARD,       card);
	items[3] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_DEVICE,     dev);
	items[4] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_SUBDEVICE,  subdev);
	items[5] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_STREAM,     get_stream(pcminfo));
	items[6] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_ID,         snd_pcm_info_get_id(pcminfo));
	items[7] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_NAME,       snd_pcm_info_get_name(pcminfo));
	items[8] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_SUBNAME,    snd_pcm_info_get_subdevice_name(pcminfo));
	items[9] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_CLASS,      get_class(pcminfo));
	items[10] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_SUBCLASS,  get_subclass(pcminfo));
	sync_id = snd_pcm_info_get_sync(pcminfo);
	snprintf(sync_name, sizeof(sync_name), "%08x:%08x:%08x:%08x",
			sync_id.id32[0], sync_id.id32[1], sync_id.id32[2], sync_id.id32[3]);
	items[11] = SPA_DICT_ITEM_INIT(SPA_KEY_API_ALSA_PCM_SYNC_ID,    sync_name);
	info.props = &SPA_DICT_INIT_ARRAY(items);

	spa_device_emit_object_info(&this->hooks, id, &info);

	return 0;
}

static int activate_profile(struct impl *this, snd_ctl_t *ctl_hndl, uint32_t id)
{
	int err = 0, dev;
	uint32_t i, n_cap, n_play;
	snd_pcm_info_t *pcminfo;
	snd_ctl_card_info_t *cardinfo;

	spa_log_debug(this->log, "profile %d", id);
	this->profile = id;

	snd_ctl_card_info_alloca(&cardinfo);
	if ((err = snd_ctl_card_info(ctl_hndl, cardinfo)) < 0) {
		spa_log_error(this->log, "error card info: %s", snd_strerror(err));
		return err;
	}

	for (i = 0; i < this->n_nodes; i++)
		spa_device_emit_object_info(&this->hooks, i, NULL);

	this->n_nodes = this->n_capture = this->n_playback = 0;

	if (id == 0)
		return 0;

        snd_pcm_info_alloca(&pcminfo);
	dev = -1;
	i = n_cap = n_play = 0;
	while (1) {
		if ((err = snd_ctl_pcm_next_device(ctl_hndl, &dev)) < 0) {
			spa_log_error(this->log, "error iterating devices: %s", snd_strerror(err));
			break;
		}
		if (dev < 0)
			break;

		snd_pcm_info_set_device(pcminfo, dev);
		snd_pcm_info_set_subdevice(pcminfo, 0);

		snd_pcm_info_set_stream(pcminfo, SND_PCM_STREAM_PLAYBACK);
		if ((err = snd_ctl_pcm_info(ctl_hndl, pcminfo)) < 0) {
			if (err != -ENOENT)
				spa_log_error(this->log, "error pcm info: %s", snd_strerror(err));
		}
		if (err >= 0) {
			n_play++;
			emit_node(this, cardinfo, pcminfo, i++);
		}

		snd_pcm_info_set_stream(pcminfo, SND_PCM_STREAM_CAPTURE);
		if ((err = snd_ctl_pcm_info(ctl_hndl, pcminfo)) < 0) {
			if (err != -ENOENT)
				spa_log_error(this->log, "error pcm info: %s", snd_strerror(err));
		}
		if (err >= 0) {
			n_cap++;
			emit_node(this, cardinfo, pcminfo, i++);
		}
	}
	this->n_capture = n_cap;
	this->n_playback = n_play;
	this->n_nodes = i;
	return err;
}

static int set_profile(struct impl *this, uint32_t id)
{
	snd_ctl_t *ctl_hndl;
	int err;

	spa_log_debug(this->log, "open card %s", this->props.device);
	if ((err = snd_ctl_open(&ctl_hndl, this->props.device, 0)) < 0) {
		spa_log_error(this->log, "can't open control for card %s: %s",
				this->props.device, snd_strerror(err));
		return err;
	}

	err = activate_profile(this, ctl_hndl, id);

	spa_log_debug(this->log, "close card %s", this->props.device);
	snd_ctl_close(ctl_hndl);

	return err;
}

static int emit_info(struct impl *this, bool full)
{
	int err = 0;
	struct spa_dict_item items[20];
	uint32_t n_items = 0;
	snd_ctl_t *ctl_hndl;
	snd_ctl_card_info_t *info;
	struct spa_device_info dinfo;
	struct spa_param_info params[2];
	char path[128];

	spa_log_debug(this->log, "open card %s", this->props.device);
	if ((err = snd_ctl_open(&ctl_hndl, this->props.device, 0)) < 0) {
		spa_log_error(this->log, "can't open control for card %s: %s",
				this->props.device, snd_strerror(err));
		return err;
	}

	snd_ctl_card_info_alloca(&info);
	if ((err = snd_ctl_card_info(ctl_hndl, info)) < 0) {
		spa_log_error(this->log, "error hardware info: %s", snd_strerror(err));
		goto exit;
	}

	dinfo = SPA_DEVICE_INFO_INIT();

	dinfo.change_mask = SPA_DEVICE_CHANGE_MASK_PROPS;

#define ADD_ITEM(key, value) items[n_items++] = SPA_DICT_ITEM_INIT(key, value)
	snprintf(path, sizeof(path), "alsa:pcm:%s", snd_ctl_card_info_get_id(info));
	ADD_ITEM(SPA_KEY_OBJECT_PATH, path);
	ADD_ITEM(SPA_KEY_DEVICE_API, "alsa:pcm");
	ADD_ITEM(SPA_KEY_MEDIA_CLASS, "Audio/Device");
	ADD_ITEM(SPA_KEY_API_ALSA_PATH,	(char *)this->props.device);
	ADD_ITEM(SPA_KEY_API_ALSA_CARD_ID, snd_ctl_card_info_get_id(info));
	ADD_ITEM(SPA_KEY_API_ALSA_CARD_COMPONENTS, snd_ctl_card_info_get_components(info));
	ADD_ITEM(SPA_KEY_API_ALSA_CARD_DRIVER, snd_ctl_card_info_get_driver(info));
	ADD_ITEM(SPA_KEY_API_ALSA_CARD_NAME, snd_ctl_card_info_get_name(info));
	ADD_ITEM(SPA_KEY_API_ALSA_CARD_LONGNAME, snd_ctl_card_info_get_longname(info));
	ADD_ITEM(SPA_KEY_API_ALSA_CARD_MIXERNAME, snd_ctl_card_info_get_mixername(info));
	dinfo.props = &SPA_DICT_INIT(items, n_items);
#undef ADD_ITEM

	dinfo.change_mask |= SPA_DEVICE_CHANGE_MASK_PARAMS;
	params[0] = SPA_PARAM_INFO(SPA_PARAM_EnumProfile, SPA_PARAM_INFO_READ);
	params[1] = SPA_PARAM_INFO(SPA_PARAM_Profile, SPA_PARAM_INFO_READWRITE);
	dinfo.n_params = SPA_N_ELEMENTS(params);
	dinfo.params = params;

	spa_device_emit_info(&this->hooks, &dinfo);

      exit:
	spa_log_debug(this->log, "close card %s", this->props.device);
	snd_ctl_close(ctl_hndl);
	return err;
}

static int impl_add_listener(void *object,
			struct spa_hook *listener,
			const struct spa_device_events *events,
			void *data)
{
	struct impl *this = object;
	struct spa_hook_list save;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(events != NULL, -EINVAL);

	spa_hook_list_isolate(&this->hooks, &save, listener, events, data);

	if (events->info || events->object_info)
		emit_info(this, true);

	spa_hook_list_join(&this->hooks, &save);

	return 0;
}


static int impl_sync(void *object, int seq)
{
	struct impl *this = object;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	spa_device_emit_result(&this->hooks, seq, 0, 0, NULL);

	return 0;
}

static struct spa_pod *build_profile(struct impl *this, struct spa_pod_builder *b,
		uint32_t id, uint32_t index)
{
	struct spa_pod_frame f[2];
	const char *name, *desc;

	switch (index) {
	case 0:
		name = "off";
		desc = "Off";
		break;
	case 1:
		name = "on";
		desc = "On";
		break;
	default:
		errno = EINVAL;
		return NULL;
	}

	spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_ParamProfile, id);
	spa_pod_builder_add(b,
		SPA_PARAM_PROFILE_index,   SPA_POD_Int(index),
		SPA_PARAM_PROFILE_name, SPA_POD_String(name),
		SPA_PARAM_PROFILE_description, SPA_POD_String(desc),
		0);
	if (index == 1) {
		spa_pod_builder_prop(b, SPA_PARAM_PROFILE_classes, 0);
		spa_pod_builder_push_struct(b, &f[1]);
		if (this->n_capture) {
			spa_pod_builder_add_struct(b,
				SPA_POD_String("Audio/Source"),
				SPA_POD_Int(this->n_capture));
		}
		if (this->n_playback) {
			spa_pod_builder_add_struct(b,
				SPA_POD_String("Audio/Sink"),
				SPA_POD_Int(this->n_playback));
		}
		spa_pod_builder_pop(b, &f[1]);
	}
	return spa_pod_builder_pop(b, &f[0]);

}
static int impl_enum_params(void *object, int seq,
			    uint32_t id, uint32_t start, uint32_t num,
			    const struct spa_pod *filter)
{
	struct impl *this = object;
	struct spa_pod *param;
	struct spa_pod_builder b = { 0 };
	uint8_t buffer[1024];
	struct spa_result_device_params result;
	uint32_t count = 0;

	spa_return_val_if_fail(this != NULL, -EINVAL);
	spa_return_val_if_fail(num != 0, -EINVAL);

	result.id = id;
	result.next = start;
      next:
	result.index = result.next++;

	spa_pod_builder_init(&b, buffer, sizeof(buffer));

	switch (id) {
	case SPA_PARAM_EnumProfile:
	{
		switch (result.index) {
		case 0:
		case 1:
			param = build_profile(this, &b, id, result.index);
			break;
		default:
			return 0;
		}
		break;
	}
	case SPA_PARAM_Profile:
	{
		switch (result.index) {
		case 0:
			param = build_profile(this, &b, id, this->profile);
			break;
		default:
			return 0;
		}
		break;
	}
	default:
		return -ENOENT;
	}

	if (spa_pod_filter(&b, &result.param, param, filter) < 0)
		goto next;

	spa_device_emit_result(&this->hooks, seq, 0,
			SPA_RESULT_TYPE_DEVICE_PARAMS, &result);

	if (++count != num)
		goto next;

	return 0;
}

static int impl_set_param(void *object,
			  uint32_t id, uint32_t flags,
			  const struct spa_pod *param)
{
	struct impl *this = object;
	int res;

	spa_return_val_if_fail(this != NULL, -EINVAL);

	switch (id) {
	case SPA_PARAM_Profile:
	{
		uint32_t id;

		if ((res = spa_pod_parse_object(param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&id))) < 0) {
			spa_log_warn(this->log, "can't parse profile");
			spa_debug_pod(0, NULL, param);
			return res;
		}

		set_profile(this, id);
		break;
	}
	default:
		return -ENOENT;
	}
	return 0;
}

static const struct spa_device_methods impl_device = {
	SPA_VERSION_DEVICE_METHODS,
	.add_listener = impl_add_listener,
	.sync = impl_sync,
	.enum_params = impl_enum_params,
	.set_param = impl_set_param,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Device) == 0)
		*interface = &this->device;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct impl);
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *this;
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	this->device.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Device,
			SPA_VERSION_DEVICE,
			&impl_device, this);
	spa_hook_list_init(&this->hooks);

	reset_props(&this->props);

	snd_config_update_free_global();

	if (info && (str = spa_dict_lookup(info, SPA_KEY_API_ALSA_PATH)))
		snprintf(this->props.device, 64, "%s", str);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Device,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	if (*index >= SPA_N_ELEMENTS(impl_interfaces))
		return 0;

	*info = &impl_interfaces[(*index)++];
	return 1;
}

const struct spa_handle_factory spa_alsa_device_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_API_ALSA_PCM_DEVICE,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
