/* PipeWire
 *
 * Copyright © 2017 Wim Taymans <wim.taymans@gmail.com>
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

#include <stdio.h>
#include <errno.h>

#include "spa/pod/parser.h"
#include "spa/pod/builder.h"
#include "spa/debug/pod.h"

#include "pipewire/pipewire.h"
#include "pipewire/private.h"
#include "pipewire/protocol.h"
#include "pipewire/resource.h"
#include "extensions/protocol-native.h"
#include "extensions/metadata.h"
#include "extensions/session-manager.h"
#include "extensions/client-node.h"

#include "interfaces.h"
#include "typemap.h"

#include "../connection.h"

#define PW_PROTOCOL_NATIVE_FLAG_REMAP        (1<<0)

SPA_EXPORT
uint32_t pw_protocol_native0_find_type(struct pw_impl_client *client, const char *type)
{
	uint32_t i;
	for (i = 0; i < SPA_N_ELEMENTS(type_map); i++) {
		if (!strcmp(type_map[i].type, type))
			return i;
	}
	return SPA_ID_INVALID;
}

static void
update_types_server(struct pw_resource *resource)
{
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_V0_EVENT_UPDATE_TYPES, NULL);

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", 0,
			    "i", SPA_N_ELEMENTS(type_map), NULL);

	for (i = 0; i < SPA_N_ELEMENTS(type_map); i++) {
		spa_pod_builder_add(b, "s", type_map[i].type, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}


static void core_marshal_info(void *object, const struct pw_core_info *info)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct protocol_compat_v2 *compat_v2 = client->compat_v2;
	struct spa_pod_builder *b;
	uint32_t i, n_items;
	uint64_t change_mask = 0;
	struct spa_pod_frame f;
	struct pw_protocol_native_message *msg;

#define PW_CORE_V0_CHANGE_MASK_USER_NAME  (1 << 0)
#define PW_CORE_V0_CHANGE_MASK_HOST_NAME  (1 << 1)
#define PW_CORE_V0_CHANGE_MASK_VERSION    (1 << 2)
#define PW_CORE_V0_CHANGE_MASK_NAME       (1 << 3)
#define PW_CORE_V0_CHANGE_MASK_COOKIE     (1 << 4)
#define PW_CORE_V0_CHANGE_MASK_PROPS      (1 << 5)

	if (compat_v2->send_types) {
		update_types_server(resource);
		change_mask |= PW_CORE_V0_CHANGE_MASK_USER_NAME |
			PW_CORE_V0_CHANGE_MASK_HOST_NAME |
			PW_CORE_V0_CHANGE_MASK_VERSION |
			PW_CORE_V0_CHANGE_MASK_NAME |
			PW_CORE_V0_CHANGE_MASK_COOKIE;
		compat_v2->send_types = false;
	}
	b = pw_protocol_native_begin_resource(resource, PW_CORE_V0_EVENT_INFO, &msg);

	n_items = info->props ? info->props->n_items : 0;

	if (info->change_mask & PW_CORE_CHANGE_MASK_PROPS)
		change_mask |= PW_CORE_V0_CHANGE_MASK_PROPS;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", change_mask,
			    "s", info->user_name,
			    "s", info->host_name,
			    "s", info->version,
			    "s", info->name,
			    "i", info->cookie,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void core_marshal_done(void *object, uint32_t id, int seq)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_V0_EVENT_DONE, NULL);

	spa_pod_builder_add_struct(b, "i", seq);

	pw_protocol_native_end_resource(resource, b);
}

static void core_marshal_error(void *object, uint32_t id, int seq, int res, const char *error)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_V0_EVENT_ERROR, NULL);

	spa_pod_builder_add_struct(b,
			       "i", id,
			       "i", res,
			       "s", error);

	pw_protocol_native_end_resource(resource, b);
}

static void core_marshal_remove_id(void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_CORE_V0_EVENT_REMOVE_ID, NULL);

	spa_pod_builder_add_struct(b, "i", id);

	pw_protocol_native_end_resource(resource, b);
}

static int core_demarshal_client_update(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_dict props;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
		    "i", &props.n_items, NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	for (i = 0; i < props.n_items; i++) {
		if (spa_pod_parser_get(&prs,
				"s", &props.items[i].key,
				"s", &props.items[i].value,
				NULL) < 0)
			return -EINVAL;
	}
	pw_impl_client_update_properties(client, &props);
	return 0;
}

static uint32_t parse_perms(const char *str)
{
	uint32_t perms = 0;

	while (*str != '\0') {
		switch (*str++) {
		case 'r':
			perms |= PW_PERM_R;
			break;
		case 'w':
			perms |= PW_PERM_W;
			break;
		case 'x':
			perms |= PW_PERM_X;
			break;
		}
	}
	return perms;
}

static int core_demarshal_permissions(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_dict props;
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t i, n_permissions;
	struct pw_permission *permissions, defperm = { 0, };

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs, "i", &props.n_items, NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));

	n_permissions = 0;
	permissions = alloca(props.n_items * sizeof(struct pw_permission));

	for (i = 0; i < props.n_items; i++) {
		uint32_t id, perms;
		const char *str;

		if (spa_pod_parser_get(&prs,
				"s", &props.items[i].key,
				"s", &props.items[i].value,
				NULL) < 0)
			return -EINVAL;

		str = props.items[i].value;
		/* first set global permissions */
		if (strcmp(props.items[i].key, PW_CORE_PERMISSIONS_GLOBAL) == 0) {
			size_t len;

                        /* <global-id>:[r][w][x] */
			len = strcspn(str, ":");
			if (len == 0)
				continue;
			id = atoi(str);
			perms = parse_perms(str + len);
			permissions[n_permissions++] = PW_PERMISSION_INIT(id, perms);
		} else if (strcmp(props.items[i].key, PW_CORE_PERMISSIONS_DEFAULT) == 0) {
			perms = parse_perms(str);
			defperm = PW_PERMISSION_INIT(PW_ID_ANY, perms);
		}
	}
	/* add default permission if set */
	if (defperm.id == PW_ID_ANY)
		permissions[n_permissions++] = defperm;

	for (i = 0; i < n_permissions; i++) {
		pw_log_debug("%d: %d: %08x", i, permissions[i].id, permissions[i].permissions);
	}

	return pw_impl_client_update_permissions(resource->client,
			n_permissions, permissions);
}

static int core_demarshal_hello(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	void *ptr;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				"P", &ptr) < 0)
		return -EINVAL;

        return pw_resource_notify(resource, struct pw_core_methods, hello, 0, 2);
}

static int core_demarshal_sync(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	uint32_t seq;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs, "i", &seq) < 0)
		return -EINVAL;

        return pw_resource_notify(resource, struct pw_core_methods, sync, 0, 0, seq);
}

static int core_demarshal_get_registry(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct spa_pod_parser prs;
	int32_t version, new_id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				"i", &version,
				"i", &new_id) < 0)
		return -EINVAL;

        return pw_resource_notify(resource, struct pw_core_methods, get_registry, 0, version, new_id);
}

SPA_EXPORT
uint32_t pw_protocol_native0_type_from_v2(struct pw_impl_client *client, uint32_t type)
{
	void *t;
	uint32_t index;
	struct protocol_compat_v2 *compat_v2 = client->compat_v2;

	if ((t = pw_map_lookup(&compat_v2->types, type)) == NULL)
		return SPA_ID_INVALID;

	index = PW_MAP_PTR_TO_ID(t);
	if (index >= SPA_N_ELEMENTS(type_map))
		return SPA_ID_INVALID;

	return type_map[index].id;
}

SPA_EXPORT
const char * pw_protocol_native0_name_from_v2(struct pw_impl_client *client, uint32_t type)
{
	void *t;
	uint32_t index;
	struct protocol_compat_v2 *compat_v2 = client->compat_v2;

	if ((t = pw_map_lookup(&compat_v2->types, type)) == NULL)
		return NULL;

	index = PW_MAP_PTR_TO_ID(t);
	if (index >= SPA_N_ELEMENTS(type_map))
		return NULL;

	return type_map[index].name;
}

SPA_EXPORT
uint32_t pw_protocol_native0_name_to_v2(struct pw_impl_client *client, const char *name)
{
	uint32_t i;
	/* match name to type table and return index */
	for (i = 0; i < SPA_N_ELEMENTS(type_map); i++) {
		if (type_map[i].name != NULL && !strcmp(type_map[i].name, name))
			return i;
	}
	return SPA_ID_INVALID;
}

SPA_EXPORT
uint32_t pw_protocol_native0_type_to_v2(struct pw_impl_client *client,
		const struct spa_type_info *info, uint32_t type)
{
	const char *name;

	/** find full name of type in type_info */
	if ((name = spa_debug_type_find_name(info, type)) == NULL)
		return SPA_ID_INVALID;

	return pw_protocol_native0_name_to_v2(client, name);
}

struct spa_pod_prop_body0 {
        uint32_t key;
#define SPA_POD_PROP0_RANGE_NONE         0       /**< no range */
#define SPA_POD_PROP0_RANGE_MIN_MAX      1       /**< property has range */
#define SPA_POD_PROP0_RANGE_STEP         2       /**< property has range with step */
#define SPA_POD_PROP0_RANGE_ENUM         3       /**< property has enumeration */
#define SPA_POD_PROP0_RANGE_FLAGS        4       /**< property has flags */
#define SPA_POD_PROP0_RANGE_MASK         0xf     /**< mask to select range type */
#define SPA_POD_PROP0_FLAG_UNSET         (1 << 4)        /**< property value is unset */
#define SPA_POD_PROP0_FLAG_OPTIONAL      (1 << 5)        /**< property value is optional */
#define SPA_POD_PROP0_FLAG_READONLY      (1 << 6)        /**< property is readonly */
#define SPA_POD_PROP0_FLAG_DEPRECATED    (1 << 7)        /**< property is deprecated */
#define SPA_POD_PROP0_FLAG_INFO          (1 << 8)        /**< property is informational and is not
                                                          *  used when filtering */
        uint32_t flags;
        struct spa_pod value;
        /* array with elements of value.size follows,
         * first element is value/default, rest are alternatives */
};

/* v2 iterates object as containing spa_pod */
#define SPA_POD_OBJECT_BODY_FOREACH0(body, size, iter)                                           \
        for ((iter) = SPA_MEMBER((body), sizeof(struct spa_pod_object_body), struct spa_pod);   \
             spa_pod_is_inside(body, size, iter);                                               \
             (iter) = spa_pod_next(iter))

#define SPA_POD_PROP_ALTERNATIVE_FOREACH0(body, _size, iter)                                     \
        for ((iter) = SPA_MEMBER((body), (body)->value.size +                                   \
                                sizeof(struct spa_pod_prop_body0), __typeof__(*iter));           \
             (iter) <= SPA_MEMBER((body), (_size)-(body)->value.size, __typeof__(*iter));       \
             (iter) = SPA_MEMBER((iter), (body)->value.size, __typeof__(*iter)))

#define SPA0_POD_PROP_N_VALUES(b,size)     ((size - sizeof(struct spa_pod_prop_body0)) / (b)->value.size)

static int remap_from_v2(uint32_t type, void *body, uint32_t size, struct pw_impl_client *client,
		struct spa_pod_builder *builder)
{
	int res;

	switch (type) {
	case SPA_TYPE_Id:
		spa_pod_builder_id(builder, pw_protocol_native0_type_from_v2(client, *(int32_t*) body));
		break;

	/** choice was props in v2 */
	case SPA_TYPE_Choice:
	{
		struct spa_pod_prop_body0 *b = body;
		struct spa_pod_frame f;
		void *alt;
		uint32_t key = pw_protocol_native0_type_from_v2(client, b->key);
		enum spa_choice_type type;

		spa_pod_builder_prop(builder, key, 0);

		switch (b->flags & SPA_POD_PROP0_RANGE_MASK) {
		default:
		case SPA_POD_PROP0_RANGE_NONE:
			type = SPA_CHOICE_None;
			break;
		case SPA_POD_PROP0_RANGE_MIN_MAX:
			type = SPA_CHOICE_Range;
			break;
		case SPA_POD_PROP0_RANGE_STEP:
			type = SPA_CHOICE_Step;
			break;
		case SPA_POD_PROP0_RANGE_ENUM:
			type = SPA_CHOICE_Enum;
			break;
		case SPA_POD_PROP0_RANGE_FLAGS:
			type = SPA_CHOICE_Flags;
			break;
		}
		if (!SPA_FLAG_IS_SET(b->flags, SPA_POD_PROP0_FLAG_UNSET) &&
		    SPA0_POD_PROP_N_VALUES(b, size) == 1)
			type = SPA_CHOICE_None;

		spa_pod_builder_push_choice(builder, &f, type, 0);

		if (b->value.type == SPA_TYPE_Id) {
			uint32_t id;
			if ((res = spa_pod_get_id(&b->value, &id)) < 0)
				return res;
			spa_pod_builder_id(builder, pw_protocol_native0_type_from_v2(client, id));
			SPA_POD_PROP_ALTERNATIVE_FOREACH0(b, size, alt)
				if ((res = remap_from_v2(b->value.type, alt, b->value.size, client, builder)) < 0)
					return res;
		} else {
			spa_pod_builder_raw(builder, &b->value, size - sizeof(struct spa_pod));
		}

		spa_pod_builder_pop(builder, &f);

		break;
	}
	case SPA_TYPE_Object:
	{
		struct spa_pod_object_body *b = body;
		struct spa_pod *p;
		struct spa_pod_frame f;
		uint32_t type, count = 0;

		/* type and id are switched */
		type = pw_protocol_native0_type_from_v2(client, b->id),
		spa_pod_builder_push_object(builder, &f, type,
			pw_protocol_native0_type_from_v2(client, b->type));

		/* object contained pods in v2 */
		SPA_POD_OBJECT_BODY_FOREACH0(b, size, p) {
			if (type == SPA_TYPE_OBJECT_Format && count < 2) {
				uint32_t id;
				if (spa_pod_get_id(p, &id) < 0)
					continue;
				id = pw_protocol_native0_type_from_v2(client, id);

				if (count == 0) {
					spa_pod_builder_prop(builder, SPA_FORMAT_mediaType, 0);
					spa_pod_builder_id(builder, id);
				}
				if (count == 1) {
					spa_pod_builder_prop(builder, SPA_FORMAT_mediaSubtype, 0);
					spa_pod_builder_id(builder, id);
				}
				count++;
				continue;
			}
			if ((res = remap_from_v2(p->type,
						SPA_POD_BODY(p),
						p->size,
						client, builder)) < 0)
				return res;
		}
		spa_pod_builder_pop(builder, &f);
		break;
	}
	case SPA_TYPE_Struct:
	{
		struct spa_pod *b = body, *p;
		struct spa_pod_frame f;

		spa_pod_builder_push_struct(builder, &f);
		SPA_POD_FOREACH(b, size, p)
			if ((res = remap_from_v2(p->type, SPA_POD_BODY(p), p->size, client, builder)) < 0)
				return res;
		spa_pod_builder_pop(builder, &f);
		break;
	}
	default:
		break;
	}
	return 0;
}

static int remap_to_v2(struct pw_impl_client *client, const struct spa_type_info *info,
		uint32_t type, void *body, uint32_t size,
		struct spa_pod_builder *builder)
{
	int res;

	switch (type) {
	case SPA_TYPE_Id:
		spa_pod_builder_id(builder, pw_protocol_native0_type_to_v2(client, info, *(int32_t*) body));
		break;

	case SPA_TYPE_Object:
	{
		struct spa_pod_object_body *b = body;
		struct spa_pod_prop *p;
		struct spa_pod_frame f[2];
		uint32_t type;
                const struct spa_type_info *ti, *ii;

		ti = spa_debug_type_find(info, b->type);
		ii = ti ? spa_debug_type_find(ti->values, 0) : NULL;

		if (b->type == SPA_TYPE_COMMAND_Node ||
		    b->type == SPA_TYPE_EVENT_Node) {
			spa_pod_builder_push_object(builder, &f[0], 0,
				pw_protocol_native0_type_to_v2(client, ii ? ii->values : NULL, b->id));
		} else {
			ii = ii ? spa_debug_type_find(ii->values, b->id) : NULL;
			/* type and id are switched */
			type = pw_protocol_native0_type_to_v2(client, info, b->type),
			spa_pod_builder_push_object(builder, &f[0],
				pw_protocol_native0_type_to_v2(client, ii ? ii->values : NULL, b->id), type);
		}


		info = ti ? ti->values : info;

		SPA_POD_OBJECT_BODY_FOREACH(b, size, p) {
			uint32_t key, flags;
			uint32_t n_vals, choice;
			struct spa_pod *values;

                        ii = spa_debug_type_find(info, p->key);

			values = spa_pod_get_values(&p->value, &n_vals, &choice);

			if (b->type == SPA_TYPE_OBJECT_Format &&
			    (p->key == SPA_FORMAT_mediaType ||
			     p->key == SPA_FORMAT_mediaSubtype)) {
				uint32_t val;

				if (spa_pod_get_id(values, &val) < 0)
					continue;
				spa_pod_builder_id(builder,
						pw_protocol_native0_type_to_v2(client, ii ? ii->values : NULL, val));
				continue;
			}

			flags = 0;
			switch(choice) {
			case SPA_CHOICE_None:
				flags |= SPA_POD_PROP0_RANGE_NONE;
				break;
			case SPA_CHOICE_Range:
				flags |= SPA_POD_PROP0_RANGE_MIN_MAX | SPA_POD_PROP0_FLAG_UNSET;
				break;
			case SPA_CHOICE_Step:
				flags |= SPA_POD_PROP0_RANGE_STEP | SPA_POD_PROP0_FLAG_UNSET;
				break;
			case SPA_CHOICE_Enum:
				flags |= SPA_POD_PROP0_RANGE_ENUM | SPA_POD_PROP0_FLAG_UNSET;
				break;
			case SPA_CHOICE_Flags:
				flags |= SPA_POD_PROP0_RANGE_FLAGS | SPA_POD_PROP0_FLAG_UNSET;
				break;
			}

			key = pw_protocol_native0_type_to_v2(client, info, p->key);

			spa_pod_builder_push_choice(builder, &f[1], key, flags);

			if (values->type == SPA_TYPE_Id) {
				uint32_t i, *id = SPA_POD_BODY(values);

				for (i = 0; i < n_vals; i++) {
					spa_pod_builder_id(builder,
						pw_protocol_native0_type_to_v2(client, ii ? ii->values : NULL, id[i]));
				}

			} else {
				spa_pod_builder_raw(builder, values, sizeof(struct spa_pod) + n_vals * values->size);
			}
			spa_pod_builder_pop(builder, &f[1]);
		}
		spa_pod_builder_pop(builder, &f[0]);
		break;
	}
	case SPA_TYPE_Struct:
	{
		struct spa_pod *b = body, *p;
		struct spa_pod_frame f;

		spa_pod_builder_push_struct(builder, &f);
		SPA_POD_FOREACH(b, size, p)
			if ((res = remap_to_v2(client, info, p->type, SPA_POD_BODY(p), p->size, builder)) < 0)
				return res;
		spa_pod_builder_pop(builder, &f);
		break;
	}
	default:
		break;
	}
	return 0;
}




SPA_EXPORT
struct spa_pod * pw_protocol_native0_pod_from_v2(struct pw_impl_client *client, const struct spa_pod *pod)
{
	uint8_t buffer[4096];
	struct spa_pod *copy;
	struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, 4096);
	int res;

	if (pod == NULL)
		return NULL;

	if ((res = remap_from_v2(SPA_POD_TYPE(pod),
					SPA_POD_BODY(pod),
					SPA_POD_BODY_SIZE(pod),
					client, &b)) < 0) {
		errno = -res;
		return NULL;
	}
	copy = spa_pod_copy(b.data);
	return copy;
}

SPA_EXPORT
int pw_protocol_native0_pod_to_v2(struct pw_impl_client *client, const struct spa_pod *pod,
		struct spa_pod_builder *b)
{
	int res;

	if (pod == NULL) {
		spa_pod_builder_none(b);
		return 0;
	}

	if ((res = remap_to_v2(client, pw_type_info(),
				SPA_POD_TYPE(pod),
				SPA_POD_BODY(pod),
				SPA_POD_BODY_SIZE(pod),
				b)) < 0) {
		return -res;
	}
	return 0;
}

static int core_demarshal_create_object(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_parser prs;
	struct spa_pod_frame f;
	uint32_t version, type, new_id, i;
	const char *factory_name, *type_name;
	struct spa_dict props;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
			"s", &factory_name,
			"I", &type,
			"i", &version,
			"i", &props.n_items, NULL) < 0)
		return -EINVAL;

	props.items = alloca(props.n_items * sizeof(struct spa_dict_item));
	for (i = 0; i < props.n_items; i++) {
		if (spa_pod_parser_get(&prs,
					"s", &props.items[i].key,
					"s", &props.items[i].value, NULL) < 0)
			return -EINVAL;
	}
	if (spa_pod_parser_get(&prs, "i", &new_id, NULL) < 0)
		return -EINVAL;

	type_name = pw_protocol_native0_name_from_v2(client, type);
	if (type_name == NULL)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_core_methods, create_object, 0, factory_name,
                                                                      type_name, version,
                                                                      &props, new_id);
}

static int core_demarshal_destroy(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object, *r;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_parser prs;
	uint32_t id;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				"i", &id, NULL) < 0)
		return -EINVAL;

	pw_log_debug("client %p: destroy resource %u", client, id);

	if ((r = pw_impl_client_find_resource(client, id)) == NULL)
		goto no_resource;

	return pw_resource_notify(resource, struct pw_core_methods, destroy, 0, r);

no_resource:
	pw_log_error("client %p: unknown resource %u op:%u", client, id, msg->opcode);
	pw_resource_errorf(resource, -ENOENT, "unknown resource %d op:%u", id, msg->opcode);
	return 0;
}

static int core_demarshal_update_types_server(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct protocol_compat_v2 *compat_v2 = client->compat_v2;
	struct spa_pod_parser prs;
	uint32_t first_id, n_types;
	struct spa_pod_frame f;
	const char **types;
	uint32_t i;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_push_struct(&prs, &f) < 0 ||
	    spa_pod_parser_get(&prs,
			"i", &first_id,
			"i", &n_types,
			NULL) < 0)
		return -EINVAL;

	if (first_id == 0)
		compat_v2->send_types = true;

	types = alloca(n_types * sizeof(char *));
	for (i = 0; i < n_types; i++) {
		if (spa_pod_parser_get(&prs, "s", &types[i], NULL) < 0)
			return -EINVAL;
	}

	for (i = 0; i < n_types; i++, first_id++) {
		uint32_t type_id = pw_protocol_native0_find_type(client, types[i]);
		if (type_id == SPA_ID_INVALID)
			continue;
		if (pw_map_insert_at(&compat_v2->types, first_id, PW_MAP_ID_TO_PTR(type_id)) < 0)
			pw_log_error("can't add type %d->%d for client", first_id, type_id);
        }
	return 0;
}

static void registry_marshal_global(void *object, uint32_t id, uint32_t permissions,
				    const char *type, uint32_t version, const struct spa_dict *props)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items, parent_id;
	uint32_t type_id;
	const char *str;

	type_id = pw_protocol_native0_find_type(client, type);
	if (type_id == SPA_ID_INVALID)
		return;

	b = pw_protocol_native_begin_resource(resource, PW_REGISTRY_V0_EVENT_GLOBAL, NULL);

	n_items = props ? props->n_items : 0;

	parent_id = 0;
	if (props) {
		if (strcmp(type, PW_TYPE_INTERFACE_Port) == 0) {
			if ((str = spa_dict_lookup(props, "node.id")) != NULL)
				parent_id = atoi(str);
		} else if (strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
			if ((str = spa_dict_lookup(props, "device.id")) != NULL)
				parent_id = atoi(str);
		} else if (strcmp(type, PW_TYPE_INTERFACE_Client) == 0 ||
		    strcmp(type, PW_TYPE_INTERFACE_Device) == 0 ||
		    strcmp(type, PW_TYPE_INTERFACE_Factory) == 0) {
			if ((str = spa_dict_lookup(props, "module.id")) != NULL)
				parent_id = atoi(str);
		}
	}

	version = 0;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", id,
			    "i", parent_id,
			    "i", permissions,
			    "I", type_id,
			    "i", version,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", props->items[i].key,
				    "s", props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void registry_marshal_global_remove(void *object, uint32_t id)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;

	b = pw_protocol_native_begin_resource(resource, PW_REGISTRY_V0_EVENT_GLOBAL_REMOVE, NULL);

	spa_pod_builder_add_struct(b, "i", id);

	pw_protocol_native_end_resource(resource, b);
}

static int registry_demarshal_bind(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_parser prs;
	uint32_t id, version, type, new_id;
	const char *type_name;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
			"i", &id,
			"I", &type,
			"i", &version,
			"i", &new_id) < 0)
		return -EINVAL;

	type_name = pw_protocol_native0_name_from_v2(client, type);
	if (type_name == NULL)
		return -EINVAL;

	return pw_resource_notify(resource, struct pw_registry_methods, bind, 0, id, type_name, version, new_id);
}

static void module_marshal_info(void *object, const struct pw_module_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items;

	b = pw_protocol_native_begin_resource(resource, PW_MODULE_V0_EVENT_INFO, NULL);

	n_items = info->props ? info->props->n_items : 0;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", info->change_mask,
			    "s", info->name,
			    "s", info->filename,
			    "s", info->args,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void factory_marshal_info(void *object, const struct pw_factory_info *info)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items, type, version;

	type = pw_protocol_native0_find_type(client, info->type);
	if (type == SPA_ID_INVALID)
		return;

	b = pw_protocol_native_begin_resource(resource, PW_FACTORY_V0_EVENT_INFO, NULL);

	n_items = info->props ? info->props->n_items : 0;

	version = 0;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", info->change_mask,
			    "s", info->name,
			    "I", type,
			    "i", version,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void node_marshal_info(void *object, const struct pw_node_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items;

	b = pw_protocol_native_begin_resource(resource, PW_NODE_V0_EVENT_INFO, NULL);

	n_items = info->props ? info->props->n_items : 0;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", info->change_mask,
			    "s", "node.name",
			    "i", info->max_input_ports,
			    "i", info->n_input_ports,
			    "i", info->max_output_ports,
			    "i", info->n_output_ports,
			    "i", info->state,
			    "s", info->error,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void node_marshal_param(void *object, int seq, uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_NODE_V0_EVENT_PARAM, NULL);

	id = pw_protocol_native0_type_to_v2(client, spa_type_param, id),

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			"I", id,
			"i", index,
			"i", next,
			NULL);
	pw_protocol_native0_pod_to_v2(client, (struct spa_pod *)param, b);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int node_demarshal_enum_params(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				"I", &id,
				"i", &index,
				"i", &num,
				"P", &filter) < 0)
		return -EINVAL;

	id = pw_protocol_native0_type_from_v2(client, id);
	filter = NULL;

        return pw_resource_notify(resource, struct pw_node_methods, enum_params, 0,
                        0, id, index, num, filter);
}

static void port_marshal_info(void *object, const struct pw_port_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items;
	uint64_t change_mask = 0;
	const char *port_name;

	b = pw_protocol_native_begin_resource(resource, PW_PORT_V0_EVENT_INFO, NULL);

	n_items = info->props ? info->props->n_items : 0;

#define PW_PORT_V0_CHANGE_MASK_NAME                (1 << 0)
#define PW_PORT_V0_CHANGE_MASK_PROPS               (1 << 1)
#define PW_PORT_V0_CHANGE_MASK_ENUM_PARAMS         (1 << 2)

	change_mask |= PW_PORT_V0_CHANGE_MASK_NAME;
	if (info->change_mask & PW_PORT_CHANGE_MASK_PROPS)
		change_mask |= PW_PORT_V0_CHANGE_MASK_PROPS;
	if (info->change_mask & PW_PORT_CHANGE_MASK_PARAMS)
		change_mask |= PW_PORT_V0_CHANGE_MASK_ENUM_PARAMS;

	port_name = NULL;
	if (info->props != NULL)
		port_name = spa_dict_lookup(info->props, "port.name");
	if (port_name == NULL)
		port_name = "port.name";

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", change_mask,
			    "s", port_name,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void port_marshal_param(void *object, int seq, uint32_t id, uint32_t index, uint32_t next,
		const struct spa_pod *param)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_builder *b;
	struct spa_pod_frame f;

	b = pw_protocol_native_begin_resource(resource, PW_PORT_V0_EVENT_PARAM, NULL);

	id = pw_protocol_native0_type_to_v2(client, spa_type_param, id),

	spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			"I", id,
			"i", index,
			"i", next,
			NULL);
	pw_protocol_native0_pod_to_v2(client, (struct spa_pod *)param, b);
	spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static int port_demarshal_enum_params(void *object, const struct pw_protocol_native_message *msg)
{
	struct pw_resource *resource = object;
	struct pw_impl_client *client = pw_resource_get_client(resource);
	struct spa_pod_parser prs;
	uint32_t id, index, num;
	struct spa_pod *filter;

	spa_pod_parser_init(&prs, msg->data, msg->size);
	if (spa_pod_parser_get_struct(&prs,
				"I", &id,
				"i", &index,
				"i", &num,
				"P", &filter) < 0)
		return -EINVAL;

	id = pw_protocol_native0_type_from_v2(client, id);
	filter = NULL;

        return pw_resource_notify(resource, struct pw_port_methods, enum_params, 0,
                        0, id, index, num, filter);
}

static void client_marshal_info(void *object, const struct pw_client_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items;

	b = pw_protocol_native_begin_resource(resource, PW_CLIENT_V0_EVENT_INFO, NULL);

	n_items = info->props ? info->props->n_items : 0;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", info->change_mask,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static void client_marshal_permissions(void *object, uint32_t index, uint32_t n_permissions,
                const struct pw_permission *permissions)
{
}


static void link_marshal_info(void *object, const struct pw_link_info *info)
{
	struct pw_resource *resource = object;
	struct spa_pod_builder *b;
	struct spa_pod_frame f;
	uint32_t i, n_items;

	b = pw_protocol_native_begin_resource(resource, PW_LINK_V0_EVENT_INFO, NULL);

	n_items = info->props ? info->props->n_items : 0;

        spa_pod_builder_push_struct(b, &f);
	spa_pod_builder_add(b,
			    "i", info->id,
			    "l", info->change_mask,
			    "i", info->output_node_id,
			    "i", info->output_port_id,
			    "i", info->input_node_id,
			    "i", info->input_port_id,
			    "P", info->format,
			    "i", n_items, NULL);

	for (i = 0; i < n_items; i++) {
		spa_pod_builder_add(b,
				    "s", info->props->items[i].key,
				    "s", info->props->items[i].value, NULL);
	}
        spa_pod_builder_pop(b, &f);

	pw_protocol_native_end_resource(resource, b);
}

static const struct pw_protocol_native_demarshal pw_protocol_native_core_method_demarshal[PW_CORE_V0_METHOD_NUM] = {
	[PW_CORE_V0_METHOD_HELLO] = { &core_demarshal_hello, 0, },
	[PW_CORE_V0_METHOD_UPDATE_TYPES] = { &core_demarshal_update_types_server, 0, },
	[PW_CORE_V0_METHOD_SYNC] = { &core_demarshal_sync, 0, },
	[PW_CORE_V0_METHOD_GET_REGISTRY] = { &core_demarshal_get_registry, 0, },
	[PW_CORE_V0_METHOD_CLIENT_UPDATE] = { &core_demarshal_client_update, 0, },
	[PW_CORE_V0_METHOD_PERMISSIONS] = { &core_demarshal_permissions, 0, },
	[PW_CORE_V0_METHOD_CREATE_OBJECT] = { &core_demarshal_create_object, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP, },
	[PW_CORE_V0_METHOD_DESTROY] = { &core_demarshal_destroy, 0, }
};

static const struct pw_core_events pw_protocol_native_core_event_marshal = {
	PW_VERSION_CORE_EVENTS,
	.info = &core_marshal_info,
	.done = &core_marshal_done,
	.error = &core_marshal_error,
	.remove_id = &core_marshal_remove_id,
};

static const struct pw_protocol_marshal pw_protocol_native_core_marshal = {
	PW_TYPE_INTERFACE_Core,
	PW_VERSION_CORE_V0,
	PW_CORE_V0_METHOD_NUM,
	PW_CORE_EVENT_NUM,
	0,
	NULL,
	pw_protocol_native_core_method_demarshal,
	&pw_protocol_native_core_event_marshal,
	NULL
};

static const struct pw_protocol_native_demarshal pw_protocol_native_registry_method_demarshal[] = {
	[PW_REGISTRY_V0_METHOD_BIND] = { &registry_demarshal_bind, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP, },
};

static const struct pw_registry_events pw_protocol_native_registry_event_marshal = {
	PW_VERSION_REGISTRY_EVENTS,
	.global = &registry_marshal_global,
	.global_remove = &registry_marshal_global_remove,
};

static const struct pw_protocol_marshal pw_protocol_native_registry_marshal = {
	PW_TYPE_INTERFACE_Registry,
	PW_VERSION_REGISTRY_V0,
	PW_REGISTRY_V0_METHOD_NUM,
	PW_REGISTRY_EVENT_NUM,
	0,
	NULL,
	pw_protocol_native_registry_method_demarshal,
	&pw_protocol_native_registry_event_marshal,
	NULL
};

static const struct pw_module_events pw_protocol_native_module_event_marshal = {
	PW_VERSION_MODULE_EVENTS,
	.info = &module_marshal_info,
};

static const struct pw_protocol_marshal pw_protocol_native_module_marshal = {
	PW_TYPE_INTERFACE_Module,
	PW_VERSION_MODULE_V0,
	0,
	PW_MODULE_EVENT_NUM,
	0,
	NULL, NULL,
	&pw_protocol_native_module_event_marshal,
	NULL
};

static const struct pw_factory_events pw_protocol_native_factory_event_marshal = {
	PW_VERSION_FACTORY_EVENTS,
	.info = &factory_marshal_info,
};

static const struct pw_protocol_marshal pw_protocol_native_factory_marshal = {
	PW_TYPE_INTERFACE_Factory,
	PW_VERSION_FACTORY_V0,
	0,
	PW_FACTORY_EVENT_NUM,
	0,
	NULL, NULL,
	&pw_protocol_native_factory_event_marshal,
	NULL,
};

static const struct pw_protocol_native_demarshal pw_protocol_native_node_method_demarshal[] = {
	[PW_NODE_V0_METHOD_ENUM_PARAMS] = { &node_demarshal_enum_params, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP, },
};

static const struct pw_node_events pw_protocol_native_node_event_marshal = {
	PW_VERSION_NODE_EVENTS,
	.info = &node_marshal_info,
	.param = &node_marshal_param,
};

static const struct pw_protocol_marshal pw_protocol_native_node_marshal = {
	PW_TYPE_INTERFACE_Node,
	PW_VERSION_NODE_V0,
	PW_NODE_V0_METHOD_NUM,
	PW_NODE_EVENT_NUM,
	0,
	NULL,
	pw_protocol_native_node_method_demarshal,
	&pw_protocol_native_node_event_marshal,
	NULL
};


static const struct pw_protocol_native_demarshal pw_protocol_native_port_method_demarshal[] = {
	[PW_PORT_V0_METHOD_ENUM_PARAMS] = { &port_demarshal_enum_params, 0, PW_PROTOCOL_NATIVE_FLAG_REMAP, },
};

static const struct pw_port_events pw_protocol_native_port_event_marshal = {
	PW_VERSION_PORT_EVENTS,
	.info = &port_marshal_info,
	.param = &port_marshal_param,
};

static const struct pw_protocol_marshal pw_protocol_native_port_marshal = {
	PW_TYPE_INTERFACE_Port,
	PW_VERSION_PORT_V0,
	PW_PORT_V0_METHOD_NUM,
	PW_PORT_EVENT_NUM,
	0,
	NULL,
	pw_protocol_native_port_method_demarshal,
	&pw_protocol_native_port_event_marshal,
	NULL
};

static const struct pw_client_events pw_protocol_native_client_event_marshal = {
	PW_VERSION_CLIENT_EVENTS,
	.info = &client_marshal_info,
	.permissions = &client_marshal_permissions,
};

static const struct pw_protocol_marshal pw_protocol_native_client_marshal = {
	PW_TYPE_INTERFACE_Client,
	PW_VERSION_CLIENT_V0,
	0,
	PW_CLIENT_EVENT_NUM,
	0,
	NULL, NULL,
	&pw_protocol_native_client_event_marshal,
	NULL,
};

static const struct pw_link_events pw_protocol_native_link_event_marshal = {
	PW_VERSION_LINK_EVENTS,
	.info = &link_marshal_info,
};

static const struct pw_protocol_marshal pw_protocol_native_link_marshal = {
	PW_TYPE_INTERFACE_Link,
	PW_VERSION_LINK_V0,
	0,
	PW_LINK_EVENT_NUM,
	0,
	NULL, NULL,
	&pw_protocol_native_link_event_marshal,
	NULL
};

void pw_protocol_native0_init(struct pw_protocol *protocol)
{
	pw_protocol_add_marshal(protocol, &pw_protocol_native_core_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_registry_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_module_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_node_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_port_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_factory_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_client_marshal);
	pw_protocol_add_marshal(protocol, &pw_protocol_native_link_marshal);
}
