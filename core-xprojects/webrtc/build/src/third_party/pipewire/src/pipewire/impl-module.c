/* PipeWire
 * Copyright © 2016 Axis Communications <dev-gstreamer@axis.com>
 *	@author Linus Svensson <linus.svensson@axis.com>
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

#include <stdio.h>
#include <dlfcn.h>
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>

#include "pipewire/impl.h"
#include "pipewire/private.h"

#define NAME "module"

/** \cond */
struct impl {
	struct pw_impl_module this;
	void *hnd;
};

#define pw_module_resource_info(r,...)	pw_resource_call(r,struct pw_module_events,info,0,__VA_ARGS__)


/** \endcond */

static char *find_module(const char *path, const char *name)
{
	char *filename;
	struct dirent *entry;
	struct stat s;
	DIR *dir;
	int res;

	filename = spa_aprintf("%s/%s.so", path, name);
	if (filename == NULL)
		return NULL;

	if (stat(filename, &s) == 0 && S_ISREG(s.st_mode)) {
		/* found a regular file with name */
		return filename;
	}

	free(filename);
	filename = NULL;

	/* now recurse down in subdirectories and look for it there */

	dir = opendir(path);
	if (dir == NULL) {
		res = -errno;
		pw_log_warn("could not open %s: %m", path);
		errno = -res;
		return NULL;
	}

	while ((entry = readdir(dir))) {
		char *newpath;

		if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
			continue;

		newpath = spa_aprintf("%s/%s", path, entry->d_name);
		if (newpath == NULL)
			break;

		if (stat(newpath, &s) == 0 && S_ISDIR(s.st_mode)) {
			filename = find_module(newpath, name);
		}
		free(newpath);

		if (filename != NULL)
			break;
	}

	closedir(dir);

	return filename;
}

static int
global_bind(void *_data, struct pw_impl_client *client, uint32_t permissions,
		 uint32_t version, uint32_t id)
{
	struct pw_impl_module *this = _data;
	struct pw_global *global = this->global;
	struct pw_resource *resource;

	resource = pw_resource_new(client, id, permissions, global->type, version, 0);
	if (resource == NULL)
		goto error_resource;

	pw_log_debug(NAME" %p: bound to %d", this, resource->id);
	pw_global_add_resource(global, resource);

	this->info.change_mask = PW_MODULE_CHANGE_MASK_ALL;
	pw_module_resource_info(resource, &this->info);
	this->info.change_mask = 0;

	return 0;

error_resource:
	pw_log_error(NAME" %p: can't create module resource: %m", this);
	return -errno;
}

static void global_destroy(void *object)
{
	struct pw_impl_module *module = object;
	spa_hook_remove(&module->global_listener);
	module->global = NULL;
	pw_impl_module_destroy(module);
}

static const struct pw_global_events global_events = {
	PW_VERSION_GLOBAL_EVENTS,
	.destroy = global_destroy,
};

/** Load a module
 *
 * \param context a \ref pw_context
 * \param name name of the module to load
 * \param args A string with arguments for the module
 * \param[out] error Return location for an error string, or NULL
 * \return A \ref pw_impl_module if the module could be loaded, or NULL on failure.
 *
 * \memberof pw_impl_module
 */
SPA_EXPORT
struct pw_impl_module *
pw_context_load_module(struct pw_context *context,
	       const char *name, const char *args,
	       struct pw_properties *properties)
{
	struct pw_impl_module *this;
	struct impl *impl;
	void *hnd;
	char *filename = NULL;
	const char *module_dir;
	int res;
	pw_impl_module_init_func_t init_func;

	module_dir = getenv("PIPEWIRE_MODULE_DIR");
	if (module_dir != NULL) {
		char **l;
		int i, n_paths;

		pw_log_debug("PIPEWIRE_MODULE_DIR set to: %s", module_dir);

		l = pw_split_strv(module_dir, "/", 0, &n_paths);
		for (i = 0; l[i] != NULL; i++) {
			filename = find_module(l[i], name);
			if (filename != NULL)
				break;
		}
		pw_free_strv(l);
	} else {
		pw_log_debug("moduledir set to: %s", MODULEDIR);

		filename = find_module(MODULEDIR, name);
	}

	if (filename == NULL)
		goto error_not_found;

	pw_log_debug("trying to load module: %s (%s) args(%s)", name, filename, args);

	hnd = dlopen(filename, RTLD_NOW | RTLD_LOCAL);
	if (hnd == NULL)
		goto error_open_failed;

	if ((init_func = dlsym(hnd, PIPEWIRE_SYMBOL_MODULE_INIT)) == NULL)
		goto error_no_pw_module;

	if (properties == NULL)
		properties = pw_properties_new(NULL, NULL);
	if (properties == NULL)
		goto error_no_mem;

	impl = calloc(1, sizeof(struct impl));
	if (impl == NULL)
		goto error_no_mem;

	impl->hnd = hnd;
	hnd = NULL;

	this = &impl->this;
	this->context = context;
	this->properties = properties;
	properties = NULL;

	spa_hook_list_init(&this->listener_list);

	pw_properties_set(this->properties, PW_KEY_MODULE_NAME, name);

	this->info.name = name ? strdup(name) : NULL;
	this->info.filename = filename;
	filename = NULL;
	this->info.args = args ? strdup(args) : NULL;

	this->global = pw_global_new(context,
				     PW_TYPE_INTERFACE_Module,
				     PW_VERSION_MODULE,
				     pw_properties_new(
					     PW_KEY_MODULE_NAME, name,
					     NULL),
				     global_bind,
				     this);

	if (this->global == NULL)
		goto error_no_global;

	spa_list_append(&context->module_list, &this->link);

	this->info.id = this->global->id;
	pw_properties_setf(this->properties, PW_KEY_OBJECT_ID, "%d", this->info.id);
	this->info.props = &this->properties->dict;

	pw_impl_module_emit_initialized(this);

	pw_global_add_listener(this->global, &this->global_listener, &global_events, this);

	if ((res = init_func(this, args)) < 0)
		goto error_init_failed;

	pw_global_register(this->global);

	pw_impl_module_emit_registered(this);

	pw_log_debug(NAME" %p: loaded module: %s", this, this->info.name);

	return this;

error_not_found:
	res = -ENOENT;
	pw_log_error("No module \"%s\" was found", name);
	goto error_cleanup;
error_open_failed:
	res = -ENOENT;
	pw_log_error("Failed to open module: \"%s\" %s", filename, dlerror());
	goto error_free_filename;
error_no_pw_module:
	res = -ENOSYS;
	pw_log_error("\"%s\": is not a pipewire module", filename);
	goto error_close;
error_no_mem:
	res = -errno;
	pw_log_error("can't allocate module: %m");
	goto error_close;
error_no_global:
	res = -errno;
	pw_log_error("\"%s\": failed to create global: %m", this->info.filename);
	goto error_free_module;
error_init_failed:
	pw_log_debug("\"%s\": failed to initialize: %s", this->info.filename, spa_strerror(res));
	goto error_free_module;

error_free_module:
	pw_impl_module_destroy(this);
error_close:
	if (hnd)
		dlclose(hnd);
error_free_filename:
	if (filename)
		free(filename);
error_cleanup:
	if (properties)
		pw_properties_free(properties);
	errno = -res;
	return NULL;
}

/** Destroy a module
 * \param module the module to destroy
 * \memberof pw_impl_module
 */
SPA_EXPORT
void pw_impl_module_destroy(struct pw_impl_module *module)
{
	struct impl *impl = SPA_CONTAINER_OF(module, struct impl, this);

	pw_log_debug(NAME" %p: destroy", module);
	pw_impl_module_emit_destroy(module);

	if (module->global) {
		spa_list_remove(&module->link);
		spa_hook_remove(&module->global_listener);
		pw_global_destroy(module->global);
	}

	pw_log_debug(NAME" %p: free", module);
	pw_impl_module_emit_free(module);
	free((char *) module->info.name);
	free((char *) module->info.filename);
	free((char *) module->info.args);

	pw_properties_free(module->properties);

	spa_hook_list_clean(&module->listener_list);

	if (!pw_in_valgrind() && dlclose(impl->hnd) != 0)
		pw_log_warn(NAME" %p: dlclose failed: %s", module, dlerror());
	free(impl);
}

SPA_EXPORT
struct pw_context *
pw_impl_module_get_context(struct pw_impl_module *module)
{
	return module->context;
}

SPA_EXPORT
struct pw_global * pw_impl_module_get_global(struct pw_impl_module *module)
{
	return module->global;
}

SPA_EXPORT
const struct pw_properties *pw_impl_module_get_properties(struct pw_impl_module *module)
{
	return module->properties;
}

SPA_EXPORT
int pw_impl_module_update_properties(struct pw_impl_module *module, const struct spa_dict *dict)
{
	struct pw_resource *resource;
	int changed;

	changed = pw_properties_update(module->properties, dict);
	module->info.props = &module->properties->dict;

	pw_log_debug(NAME" %p: updated %d properties", module, changed);

	if (!changed)
		return 0;

	module->info.change_mask |= PW_MODULE_CHANGE_MASK_PROPS;
	if (module->global)
		spa_list_for_each(resource, &module->global->resource_list, link)
			pw_module_resource_info(resource, &module->info);
	module->info.change_mask = 0;

	return changed;
}

SPA_EXPORT
const struct pw_module_info *
pw_impl_module_get_info(struct pw_impl_module *module)
{
	return &module->info;
}

SPA_EXPORT
void pw_impl_module_add_listener(struct pw_impl_module *module,
			    struct spa_hook *listener,
			    const struct pw_impl_module_events *events,
			    void *data)
{
	spa_hook_list_append(&module->listener_list, listener, events, data);
}
