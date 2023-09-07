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

struct selector {
	bool (*type) (struct pw_manager_object *o);
	uint32_t id;
	const char *key;
	const char *value;
	void (*accumulate) (struct selector *sel, struct pw_manager_object *o);
	int32_t score;
	struct pw_manager_object *best;
};

static void select_best(struct selector *s, struct pw_manager_object *o)
{
	const char *str;
	int32_t prio = 0;

	if (o->props &&
	    (str = pw_properties_get(o->props, PW_KEY_PRIORITY_SESSION)) != NULL) {
		prio = pw_properties_parse_int(str);
		if (s->best == NULL || prio > s->score) {
			s->best = o;
			s->score = prio;
		}
	}
}

static struct pw_manager_object *select_object(struct pw_manager *m,
		struct selector *s)
{
	struct pw_manager_object *o;
	const char *str;

	spa_list_for_each(o, &m->object_list, link) {
		if (o->creating || o->removing)
			continue;
		if (s->type != NULL && !s->type(o))
			continue;
		if (o->id == s->id)
			return o;
		if (s->accumulate)
			s->accumulate(s, o);
		if (o->props && s->key != NULL && s->value != NULL &&
		    (str = pw_properties_get(o->props, s->key)) != NULL &&
		    strcmp(str, s->value) == 0)
			return o;
		if (s->value != NULL && (uint32_t)atoi(s->value) == o->id)
			return o;
	}
	return s->best;
}

static struct pw_manager_object *find_linked(struct pw_manager *m, uint32_t obj_id, enum pw_direction direction)
{
	struct pw_manager_object *o, *p;
	const char *str;
	uint32_t in_node, out_node;

	spa_list_for_each(o, &m->object_list, link) {
		if (o->props == NULL || !pw_manager_object_is_link(o))
			continue;

		if ((str = pw_properties_get(o->props, PW_KEY_LINK_OUTPUT_NODE)) == NULL)
                        continue;
		out_node = pw_properties_parse_int(str);
                if ((str = pw_properties_get(o->props, PW_KEY_LINK_INPUT_NODE)) == NULL)
                        continue;
		in_node = pw_properties_parse_int(str);

		if (direction == PW_DIRECTION_OUTPUT && obj_id == out_node) {
			struct selector sel = { .id = in_node, .type = pw_manager_object_is_sink, };
			if ((p = select_object(m, &sel)) != NULL)
				return p;
		}
		if (direction == PW_DIRECTION_INPUT && obj_id == in_node) {
			struct selector sel = { .id = out_node, .type = pw_manager_object_is_recordable, };
			if ((p = select_object(m, &sel)) != NULL)
				return p;
		}
	}
	return NULL;
}

struct card_info {
	uint32_t n_profiles;
	uint32_t active_profile;
	const char *active_profile_name;

	uint32_t n_ports;
};

#define CARD_INFO_INIT (struct card_info) {				\
				.active_profile = SPA_ID_INVALID,	\
}

static void collect_card_info(struct pw_manager_object *card, struct card_info *info)
{
	struct pw_manager_param *p;

	spa_list_for_each(p, &card->param_list, link) {
		switch (p->id) {
		case SPA_PARAM_EnumProfile:
			info->n_profiles++;
			break;
		case SPA_PARAM_Profile:
			spa_pod_parse_object(p->param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&info->active_profile));
			break;
		case SPA_PARAM_EnumRoute:
			info->n_ports++;
			break;
		}
	}
}

struct profile_info {
	uint32_t id;
	const char *name;
	const char *description;
	uint32_t priority;
	uint32_t available;
	uint32_t n_sources;
	uint32_t n_sinks;
};

static uint32_t collect_profile_info(struct pw_manager_object *card, struct card_info *card_info,
		struct profile_info *profile_info)
{
	struct pw_manager_param *p;
	struct profile_info *pi;
	uint32_t n;

	n = 0;
	spa_list_for_each(p, &card->param_list, link) {
		struct spa_pod *classes = NULL;

		if (p->id != SPA_PARAM_EnumProfile)
			continue;

		pi = &profile_info[n];
		spa_zero(*pi);

		if (spa_pod_parse_object(p->param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&pi->id),
				SPA_PARAM_PROFILE_name,  SPA_POD_String(&pi->name),
				SPA_PARAM_PROFILE_description,  SPA_POD_OPT_String(&pi->description),
				SPA_PARAM_PROFILE_priority,  SPA_POD_OPT_Int(&pi->priority),
				SPA_PARAM_PROFILE_available,  SPA_POD_OPT_Id(&pi->available),
				SPA_PARAM_PROFILE_classes,  SPA_POD_OPT_Pod(&classes)) < 0) {
			continue;
		}
		if (pi->description == NULL)
			pi->description = pi->name;
		if (pi->id == card_info->active_profile)
			card_info->active_profile_name = pi->name;

		if (classes != NULL) {
			struct spa_pod *iter;

			SPA_POD_STRUCT_FOREACH(classes, iter) {
				struct spa_pod_parser prs;
				char *class;
				uint32_t count;

				spa_pod_parser_pod(&prs, iter);
				if (spa_pod_parser_get_struct(&prs,
						SPA_POD_String(&class),
						SPA_POD_Int(&count)) < 0)
					continue;

				if (strcmp(class, "Audio/Sink") == 0)
					pi->n_sinks += count;
				else if (strcmp(class, "Audio/Source") == 0)
					pi->n_sources += count;
			}
		}
		n++;
	}
	if (card_info->active_profile_name == NULL && n > 0)
		card_info->active_profile_name = profile_info[0].name;

	return n;
}

static uint32_t find_profile_id(struct pw_manager_object *card, const char *name)
{
	struct pw_manager_param *p;

	spa_list_for_each(p, &card->param_list, link) {
		uint32_t id;
		const char *test_name;

		if (p->id != SPA_PARAM_EnumProfile)
			continue;

		if (spa_pod_parse_object(p->param,
				SPA_TYPE_OBJECT_ParamProfile, NULL,
				SPA_PARAM_PROFILE_index, SPA_POD_Int(&id),
				SPA_PARAM_PROFILE_name,  SPA_POD_String(&test_name)) < 0)
			continue;

		if (strcmp(test_name, name) == 0)
			return id;

	}
	return SPA_ID_INVALID;
}

struct device_info {
	uint32_t direction;

	struct sample_spec ss;
	struct channel_map map;
	struct volume_info volume_info;
	unsigned int have_volume:1;

	uint32_t device;
	uint32_t active_port;
	const char *active_port_name;
};

#define DEVICE_INFO_INIT(_dir) (struct device_info) {			\
				.direction = _dir,			\
				.ss = SAMPLE_SPEC_INIT,			\
				.map = CHANNEL_MAP_INIT,		\
				.volume_info = VOLUME_INFO_INIT,	\
				.device = SPA_ID_INVALID,		\
				.active_port = SPA_ID_INVALID,		\
			}

static void collect_device_info(struct pw_manager_object *device,
		struct pw_manager_object *card, struct device_info *dev_info, bool monitor)
{
	struct pw_manager_param *p;

	if (card && !monitor) {
		spa_list_for_each(p, &card->param_list, link) {
			uint32_t id, device;
			struct spa_pod *props;

			if (p->id != SPA_PARAM_Route)
				continue;

			if (spa_pod_parse_object(p->param,
					SPA_TYPE_OBJECT_ParamRoute, NULL,
					SPA_PARAM_ROUTE_index, SPA_POD_Int(&id),
					SPA_PARAM_ROUTE_device,  SPA_POD_Int(&device),
					SPA_PARAM_ROUTE_props,  SPA_POD_OPT_Pod(&props)) < 0)
				continue;
			if (device != dev_info->device)
				continue;
			dev_info->active_port = id;
			if (props) {
				volume_parse_param(props, &dev_info->volume_info, monitor);
				dev_info->have_volume = true;
			}
		}
	}

	spa_list_for_each(p, &device->param_list, link) {
		switch (p->id) {
		case SPA_PARAM_EnumFormat:
		{
			struct spa_pod *copy = spa_pod_copy(p->param);
			spa_pod_fixate(copy);
			format_parse_param(copy, &dev_info->ss, &dev_info->map);
			free(copy);
			break;
		}
		case SPA_PARAM_Format:
			format_parse_param(p->param, &dev_info->ss, &dev_info->map);
			break;

		case SPA_PARAM_Props:
			if (!dev_info->have_volume) {
				volume_parse_param(p->param, &dev_info->volume_info, monitor);
				dev_info->have_volume = true;
			}
			break;
		}
	}
	if (dev_info->ss.channels != dev_info->map.channels)
		dev_info->ss.channels = dev_info->map.channels;
	if (dev_info->volume_info.volume.channels != dev_info->map.channels)
		dev_info->volume_info.volume.channels = dev_info->map.channels;
}


static bool array_contains(uint32_t *vals, uint32_t n_vals, uint32_t val)
{
	uint32_t n;
	if (vals == NULL || n_vals == 0)
		return false;
	for (n = 0; n < n_vals; n++)
		if (vals[n] == val)
			return true;
	return false;
}

struct port_info {
	uint32_t id;
	uint32_t direction;
	const char *name;
	const char *description;
	uint32_t priority;
	uint32_t available;

	const char *availability_group;
	uint32_t type;

	uint32_t n_devices;
	uint32_t *devices;
	uint32_t n_profiles;
	uint32_t *profiles;

	uint32_t n_props;
	struct spa_pod *info;
};

static uint32_t collect_port_info(struct pw_manager_object *card, struct card_info *card_info,
		struct device_info *dev_info, struct port_info *port_info)
{
	struct pw_manager_param *p;
	uint32_t n;

	if (card == NULL)
		return 0;

	n = 0;
	spa_list_for_each(p, &card->param_list, link) {
		struct spa_pod *devices = NULL, *profiles = NULL;
		struct port_info *pi;

		if (p->id != SPA_PARAM_EnumRoute)
			continue;

		pi = &port_info[n];
		spa_zero(*pi);

		if (spa_pod_parse_object(p->param,
				SPA_TYPE_OBJECT_ParamRoute, NULL,
				SPA_PARAM_ROUTE_index, SPA_POD_Int(&pi->id),
				SPA_PARAM_ROUTE_direction, SPA_POD_Id(&pi->direction),
				SPA_PARAM_ROUTE_name,  SPA_POD_String(&pi->name),
				SPA_PARAM_ROUTE_description,  SPA_POD_OPT_String(&pi->description),
				SPA_PARAM_ROUTE_priority,  SPA_POD_OPT_Int(&pi->priority),
				SPA_PARAM_ROUTE_available,  SPA_POD_OPT_Id(&pi->available),
				SPA_PARAM_ROUTE_info,  SPA_POD_OPT_Pod(&pi->info),
				SPA_PARAM_ROUTE_devices,  SPA_POD_OPT_Pod(&devices),
				SPA_PARAM_ROUTE_profiles,  SPA_POD_OPT_Pod(&profiles)) < 0)
			continue;

		if (pi->description == NULL)
			pi->description = pi->name;
		if (devices)
			pi->devices = spa_pod_get_array(devices, &pi->n_devices);
		if (profiles)
			pi->profiles = spa_pod_get_array(profiles, &pi->n_profiles);

		if (dev_info != NULL) {
			if (pi->direction != dev_info->direction)
				continue;
			if (!array_contains(pi->profiles, pi->n_profiles, card_info->active_profile))
				continue;
			if (!array_contains(pi->devices, pi->n_devices, dev_info->device))
				continue;
			if (pi->id == dev_info->active_port)
				dev_info->active_port_name = pi->name;
		}

		while (pi->info != NULL) {
			struct spa_pod_parser prs;
			struct spa_pod_frame f[1];
			uint32_t n;
			const char *key, *value;

			spa_pod_parser_pod(&prs, pi->info);
			if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
			    spa_pod_parser_get_int(&prs, (int32_t*)&pi->n_props) < 0)
				break;

			for (n = 0; n < pi->n_props; n++) {
				if (spa_pod_parser_get(&prs,
						SPA_POD_String(&key),
						SPA_POD_String(&value),
						NULL) < 0)
					break;
				if (strcmp(key, "port.availability-group") == 0)
					pi->availability_group = value;
				else if (strcmp(key, "port.type") == 0)
					pi->type = port_type_value(value);
			}
			spa_pod_parser_pop(&prs, &f[0]);
			break;
		}
		n++;
	}
	if (dev_info != NULL && dev_info->active_port_name == NULL && n > 0)
		dev_info->active_port_name = port_info[0].name;
	return n;
}

static uint32_t find_port_id(struct pw_manager_object *card, uint32_t direction, const char *port_name)
{
	struct pw_manager_param *p;

	spa_list_for_each(p, &card->param_list, link) {
		uint32_t id, dir;
		const char *name;

		if (p->id != SPA_PARAM_EnumRoute)
			continue;

		if (spa_pod_parse_object(p->param,
				SPA_TYPE_OBJECT_ParamRoute, NULL,
				SPA_PARAM_ROUTE_index, SPA_POD_Int(&id),
				SPA_PARAM_ROUTE_direction, SPA_POD_Id(&dir),
				SPA_PARAM_ROUTE_name, SPA_POD_String(&name)) < 0)
			continue;
		if (dir != direction)
			continue;
		if (strcmp(name, port_name) == 0)
			return id;

	}
	return SPA_ID_INVALID;
}

static struct spa_dict *collect_props(struct spa_pod *info, struct spa_dict *dict)
{
	struct spa_pod_parser prs;
	struct spa_pod_frame f[1];
	int32_t n, n_items;

	spa_pod_parser_pod(&prs, info);
	if (spa_pod_parser_push_struct(&prs, &f[0]) < 0 ||
	    spa_pod_parser_get_int(&prs, &n_items) < 0)
		return NULL;

	for (n = 0; n < n_items; n++) {
		if (spa_pod_parser_get(&prs,
				SPA_POD_String(&dict->items[n].key),
				SPA_POD_String(&dict->items[n].value),
				NULL) < 0)
			break;
	}
	spa_pod_parser_pop(&prs, &f[0]);
	dict->n_items = n;
	return dict;
}

struct transport_codec_info {
	enum spa_bluetooth_audio_codec id;
	const char *description;
};

static uint32_t collect_transport_codec_info(struct pw_manager_object *card,
		struct transport_codec_info *codecs, uint32_t max_codecs, uint32_t *active)
{
	struct pw_manager_param *p;
	uint32_t n_codecs = 0;

	*active = SPA_ID_INVALID;

	if (card == NULL)
		return 0;

	spa_list_for_each(p, &card->param_list, link) {
		uint32_t iid;
		const struct spa_pod_choice *type;
		const struct spa_pod_struct *labels;
		struct spa_pod_parser prs;
		struct spa_pod_frame f;
		int32_t *id;
		bool first;

		if (p->id != SPA_PARAM_PropInfo)
			continue;

		if (spa_pod_parse_object(p->param,
						SPA_TYPE_OBJECT_PropInfo, NULL,
						SPA_PROP_INFO_id, SPA_POD_Id(&iid),
						SPA_PROP_INFO_type, SPA_POD_PodChoice(&type),
						SPA_PROP_INFO_labels, SPA_POD_PodStruct(&labels)) < 0)
			continue;

		if (iid != SPA_PROP_bluetoothAudioCodec)
			continue;

		if (SPA_POD_CHOICE_TYPE(type) != SPA_CHOICE_Enum ||
				SPA_POD_TYPE(SPA_POD_CHOICE_CHILD(type)) != SPA_TYPE_Int)
			continue;

		/*
		 * XXX: PropInfo currently uses Int, not Id, in type and labels.
		 */

		/* Codec name list */
		first = true;
		SPA_POD_CHOICE_FOREACH(type, id) {
			if (first) {
				/* Skip default */
				first = false;
				continue;
			}
			if (n_codecs >= max_codecs)
				break;
			codecs[n_codecs++].id = *id;
		}

		/* Codec description list */
		spa_pod_parser_pod(&prs, (struct spa_pod *)labels);
		if (spa_pod_parser_push_struct(&prs, &f) < 0)
			continue;

		while (1) {
			int32_t id;
			const char *desc;
			uint32_t j;

			if (spa_pod_parser_get_int(&prs, &id) < 0 ||
					spa_pod_parser_get_string(&prs, &desc) < 0)
				break;

			for (j = 0; j < n_codecs; ++j) {
				if (codecs[j].id == (uint32_t)id)
					codecs[j].description = desc;
			}
		}
	}

	/* Active codec */
	spa_list_for_each(p, &card->param_list, link) {
		uint32_t j;
		uint32_t id;

		if (p->id != SPA_PARAM_Props)
			continue;

		if (spa_pod_parse_object(p->param,
						SPA_TYPE_OBJECT_Props, NULL,
						SPA_PROP_bluetoothAudioCodec, SPA_POD_Id(&id)) < 0)
			continue;

		for (j = 0; j < n_codecs; ++j) {
			if (codecs[j].id == id)
				*active = j;
		}
	}

	return n_codecs;
}
