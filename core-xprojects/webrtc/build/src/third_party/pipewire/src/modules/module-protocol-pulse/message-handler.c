static int bluez_card_object_message_handler(struct pw_manager *m, struct pw_manager_object *o, const char *message, const char *params, char **response)
{
	struct transport_codec_info codecs[64];
	uint32_t n_codecs, active;

	pw_log_debug(NAME "bluez-card %p object message:'%s' params:'%s'", o, message, params);

	n_codecs = collect_transport_codec_info(o, codecs, SPA_N_ELEMENTS(codecs), &active);

	if (n_codecs == 0)
		return -EINVAL;

	if (strcmp(message, "switch-codec") == 0) {
		regex_t re;
		regmatch_t matches[2];
		char *codec;
		char buf[1024];
		struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof(buf));
		struct spa_pod_frame f[1];
		struct spa_pod *param;
		uint32_t codec_id = SPA_ID_INVALID;

		/* Parse args */
		if (params == NULL)
			return -EINVAL;
		if (regcomp(&re, "[:space:]*{\\([0-9]*\\)}[:space:]*", 0) != 0)
			return -EIO;
		if (regexec(&re, params, SPA_N_ELEMENTS(matches), matches, 0) != 0) {
			regfree(&re);
			return -EINVAL;
		}
		regfree(&re);

		codec = strndup(params + matches[1].rm_so, matches[1].rm_eo - matches[1].rm_so);
		if (codec) {
			codec_id = atoi(codec);
			free(codec);
		}

		/* Switch codec */
		spa_pod_builder_push_object(&b, &f[0],
				SPA_TYPE_OBJECT_Props, SPA_PARAM_Props);
		spa_pod_builder_add(&b,
				SPA_PROP_bluetoothAudioCodec, SPA_POD_Id(codec_id), 0);
		param = spa_pod_builder_pop(&b, &f[0]);

		pw_device_set_param((struct pw_device *)o->proxy,
				SPA_PARAM_Props, 0, param);
		return 0;
	} else if (strcmp(message, "list-codecs") == 0) {
		uint32_t i;
		FILE *r;
		size_t size;

		r = open_memstream(response, &size);
		if (r == NULL)
			return -ENOMEM;

		fputc('{', r);
		for (i = 0; i < n_codecs; ++i) {
			const char *desc = codecs[i].description;
			fprintf(r, "{{%d}{%s}}", (int)codecs[i].id, desc ? desc : "Unknown");
		}
		fputc('}', r);

		return fclose(r) ? -errno : 0;
	} else if (strcmp(message, "get-codec") == 0) {
		if (active == SPA_ID_INVALID)
			*response = strdup("{none}");
		else
			*response = spa_aprintf("{%d}", (int)codecs[active].id);
		return *response ? 0 : -ENOMEM;
	}

	return -ENOSYS;
}

static int core_object_message_handler(struct pw_manager *m, struct pw_manager_object *o, const char *message, const char *params, char **response)
{
	pw_log_debug(NAME "core %p object message:'%s' params:'%s'", o, message, params);

	if (strcmp(message, "list-handlers") == 0) {
		FILE *r;
		size_t size;

		r = open_memstream(response, &size);
		if (r == NULL)
			return -ENOMEM;

		fputc('{', r);
		spa_list_for_each(o, &m->object_list, link) {
			if (o->message_object_path)
				fprintf(r, "{{%s}{%s}}", o->message_object_path, o->type);
		}
		fputc('}', r);
		return fclose(r) ? -errno : 0;
	}

	return -ENOSYS;
}

static void register_object_message_handlers(struct pw_manager_object *o)
{
	const char *str;

	if (o->id == 0) {
		free(o->message_object_path);
		o->message_object_path = strdup("/core");
		o->message_handler = core_object_message_handler;
		return;
	}

	if (pw_manager_object_is_card(o) && o->props != NULL &&
	    (str = pw_properties_get(o->props, PW_KEY_DEVICE_API)) != NULL &&
	    strcmp(str, "bluez5") == 0) {
		str = pw_properties_get(o->props, PW_KEY_DEVICE_NAME);
		if (str) {
			free(o->message_object_path);
			o->message_object_path = spa_aprintf("/card/%s/bluez", str);
			o->message_handler = bluez_card_object_message_handler;
		}
		return;
	}
}
