/* PipeWire
 *
 * Copyright © 2019 Collabora Ltd.
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

#include "config.h"

#include <pipewire/impl.h>

/* client-endpoint.c */
int client_endpoint_factory_init(struct pw_impl_module *module);
/* client-session.c */
int client_session_factory_init(struct pw_impl_module *module);

int session_factory_init(struct pw_impl_module *module);
int endpoint_factory_init(struct pw_impl_module *module);
int endpoint_stream_factory_init(struct pw_impl_module *module);
int endpoint_link_factory_init(struct pw_impl_module *module);

/* protocol-native.c */
int pw_protocol_native_ext_session_manager_init(struct pw_context *context);

static const struct spa_dict_item module_props[] = {
	{ PW_KEY_MODULE_AUTHOR, "George Kiagiadakis <george.kiagiadakis@collabora.com>" },
	{ PW_KEY_MODULE_DESCRIPTION, "Implements objects for session management" },
	{ PW_KEY_MODULE_VERSION, PACKAGE_VERSION },
};

SPA_EXPORT
int pipewire__module_init(struct pw_impl_module *module, const char *args)
{
	struct pw_context *context = pw_impl_module_get_context(module);
	int res;

	if ((res = pw_protocol_native_ext_session_manager_init(context)) < 0)
		return res;

	client_endpoint_factory_init(module);
	client_session_factory_init(module);
	session_factory_init(module);
	endpoint_factory_init(module);
	endpoint_stream_factory_init(module);
	endpoint_link_factory_init(module);

	pw_impl_module_update_properties(module, &SPA_DICT_INIT_ARRAY(module_props));

	return 0;
}
