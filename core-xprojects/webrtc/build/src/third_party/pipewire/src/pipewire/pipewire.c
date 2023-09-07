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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <unistd.h>
#include <limits.h>
#include <stdio.h>
#ifndef __FreeBSD__
#include <sys/prctl.h>
#endif
#include <pwd.h>
#include <errno.h>
#include <dlfcn.h>

#include <locale.h>
#include <libintl.h>

#include <spa/utils/names.h>
#include <spa/support/cpu.h>
#include <spa/support/i18n.h>

#include "pipewire.h"
#include "private.h"

#define MAX_SUPPORT	32

#define SUPPORTLIB	"support/libspa-support"

static struct spa_i18n *_pipewire_i18n = NULL;

struct plugin {
	struct spa_list link;
	char *filename;
	void *hnd;
	spa_handle_factory_enum_func_t enum_func;
	struct spa_list handles;
	int ref;
};

struct handle {
	struct spa_list link;
	struct plugin *plugin;
	char *factory_name;
	int ref;
	struct spa_handle handle SPA_ALIGNED(8);
};

struct registry {
	struct spa_list plugins;
};

struct support {
	char **categories;
	const char *plugin_dir;
	const char *support_lib;
	struct registry *registry;
	char *i18n_domain;
	struct spa_interface i18n_iface;
	struct spa_support support[MAX_SUPPORT];
	uint32_t n_support;
	unsigned int in_valgrind:1;
};

static struct registry global_registry;
static struct support global_support;

static struct plugin *
find_plugin(struct registry *registry, const char *filename)
{
	struct plugin *p;
	spa_list_for_each(p, &registry->plugins, link) {
		if (!strcmp(p->filename, filename))
			return p;
	}
	return NULL;
}

static struct plugin *
open_plugin(struct registry *registry,
	    const char *path, const char *lib)
{
	struct plugin *plugin;
	char *filename;
	void *hnd;
	spa_handle_factory_enum_func_t enum_func;
	int res;

        if ((filename = spa_aprintf("%s/%s.so", path, lib)) == NULL) {
		res = -errno;
		goto error_out;
	}

	if ((plugin = find_plugin(registry, filename)) != NULL) {
		free(filename);
		plugin->ref++;
		return plugin;
	}

        if ((hnd = dlopen(filename, RTLD_NOW)) == NULL) {
		res = -ENOENT;
		pw_log_debug("can't load %s: %s", filename, dlerror());
		goto error_free_filename;
        }
        if ((enum_func = dlsym(hnd, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME)) == NULL) {
		res = -ENOSYS;
		pw_log_debug("can't find enum function: %s", dlerror());
		goto error_dlclose;
        }

	if ((plugin = calloc(1, sizeof(struct plugin))) == NULL) {
		res = -errno;
		goto error_dlclose;
	}

	pw_log_debug("loaded plugin:'%s'", filename);
	plugin->ref = 1;
	plugin->filename = filename;
	plugin->hnd = hnd;
	plugin->enum_func = enum_func;
	spa_list_init(&plugin->handles);

	spa_list_append(&registry->plugins, &plugin->link);

	return plugin;

error_dlclose:
	dlclose(hnd);
error_free_filename:
        free(filename);
error_out:
	errno = -res;
	return NULL;
}

static void
unref_plugin(struct plugin *plugin)
{
	if (--plugin->ref == 0) {
		spa_list_remove(&plugin->link);
		pw_log_debug("unloaded plugin:'%s'", plugin->filename);
		if (!global_support.in_valgrind)
			dlclose(plugin->hnd);
		free(plugin->filename);
		free(plugin);
	}
}

static const struct spa_handle_factory *find_factory(struct plugin *plugin, const char *factory_name)
{
	int res = -ENOENT;
	uint32_t index;
        const struct spa_handle_factory *factory;

        for (index = 0;;) {
                if ((res = plugin->enum_func(&factory, &index)) <= 0) {
                        if (res == 0)
				break;
                        goto out;
                }
		if (factory->version < 1) {
			pw_log_warn("factory version %d < 1 not supported",
					factory->version);
			continue;
		}
                if (strcmp(factory->name, factory_name) == 0)
                        return factory;
	}
	res = -ENOENT;
out:
	pw_log_debug("can't find factory %s: %s", factory_name, spa_strerror(res));
	errno = -res;
	return NULL;
}

static void unref_handle(struct handle *handle)
{
	if (--handle->ref == 0) {
		spa_list_remove(&handle->link);
		pw_log_debug("clear handle '%s'", handle->factory_name);
		spa_handle_clear(&handle->handle);
		unref_plugin(handle->plugin);
		free(handle->factory_name);
		free(handle);
	}
}

static void configure_debug(struct support *support, const char *str)
{
	char **level;
	int n_tokens;

	level = pw_split_strv(str, ":", INT_MAX, &n_tokens);
	if (n_tokens > 0)
		pw_log_set_level(atoi(level[0]));

	if (n_tokens > 1)
		support->categories = pw_split_strv(level[1], ",", INT_MAX, &n_tokens);

	if (level)
		pw_free_strv(level);
}

SPA_EXPORT
uint32_t pw_get_support(struct spa_support *support, uint32_t max_support)
{
	uint32_t i, n = SPA_MIN(global_support.n_support, max_support);
	for (i = 0; i < n; i++)
		support[i] = global_support.support[i];
	return n;
}

SPA_EXPORT
struct spa_handle *pw_load_spa_handle(const char *lib,
		const char *factory_name,
		const struct spa_dict *info,
		uint32_t n_support,
		const struct spa_support support[])
{
	struct support *sup = &global_support;
	struct plugin *plugin;
	struct handle *handle;
	const struct spa_handle_factory *factory;
	int res;

	if (factory_name == NULL) {
		res = -EINVAL;
		goto error_out;
	}

	if (lib == NULL)
		lib = sup->support_lib;

	pw_log_debug("load lib:'%s' factory-name:'%s'", lib, factory_name);

	if ((plugin = open_plugin(sup->registry, sup->plugin_dir, lib)) == NULL) {
		res = -errno;
		goto error_out;
	}

	factory = find_factory(plugin, factory_name);
	if (factory == NULL) {
		res = -errno;
		goto error_unref_plugin;
	}

	handle = calloc(1, sizeof(struct handle) + spa_handle_factory_get_size(factory, info));
	if (handle == NULL) {
		res = -errno;
		goto error_unref_plugin;
	}

	if ((res = spa_handle_factory_init(factory,
					&handle->handle, info,
					support, n_support)) < 0) {
		pw_log_debug("can't make factory instance '%s': %d (%s)",
				factory_name, res, spa_strerror(res));
		goto error_free_handle;
	}

	handle->ref = 1;
	handle->plugin = plugin;
	handle->factory_name = strdup(factory_name);
	spa_list_append(&plugin->handles, &handle->link);

	return &handle->handle;

error_free_handle:
	free(handle);
error_unref_plugin:
	unref_plugin(plugin);
error_out:
	errno = -res;
	return NULL;
}

static struct handle *find_handle(struct spa_handle *handle)
{
	struct registry *registry = global_support.registry;
	struct plugin *p;
	struct handle *h;

	spa_list_for_each(p, &registry->plugins, link) {
		spa_list_for_each(h, &p->handles, link) {
			if (&h->handle == handle)
				return h;
		}
	}
	return NULL;
}

SPA_EXPORT
int pw_unload_spa_handle(struct spa_handle *handle)
{
	struct handle *h;

	if ((h = find_handle(handle)) == NULL)
		return -ENOENT;

	unref_handle(h);

	return 0;
}

static void *add_interface(struct support *support,
		const char *factory_name,
		const char *type,
		const struct spa_dict *info)
{
	struct spa_handle *handle;
	void *iface = NULL;
	int res = -ENOENT;

	handle = pw_load_spa_handle(support->support_lib,
			factory_name, info,
			support->n_support, support->support);

	if (handle == NULL ||
	    (res = spa_handle_get_interface(handle, type, &iface)) < 0) {
			pw_log_error("can't get %s interface %d", type, res);
	} else {
		support->support[support->n_support++] =
			SPA_SUPPORT_INIT(type, iface);
	}
	return iface;
}

SPA_EXPORT
int pw_set_domain(const char *domain)
{
	struct support *support = &global_support;
	free(support->i18n_domain);
	if (domain == NULL)
		support->i18n_domain = NULL;
	else if ((support->i18n_domain = strdup(domain)) == NULL)
		return -errno;
	return 0;
}
SPA_EXPORT
const char *pw_get_domain(void)
{
	struct support *support = &global_support;
	return support->i18n_domain;
}

static const char *i18n_text(void *object, const char *msgid)
{
	struct support *support = object;
	return dgettext(support->i18n_domain, msgid);
}

static const char *i18n_ntext(void *object, const char *msgid, const char *msgid_plural,
		unsigned long int n)
{
	struct support *support = object;
	return dngettext(support->i18n_domain, msgid, msgid_plural, n);
}

static void init_i18n(struct support *support)
{
	/* Load locale from the environment. */
	setlocale(LC_ALL, "");
	/* Set LC_NUMERIC to C so that floating point strings are consistently
	 * formatted and parsed across locales. */
	setlocale(LC_NUMERIC, "C");
	bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR);
	bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8");
	pw_set_domain(GETTEXT_PACKAGE);
}

static void *add_i18n(struct support *support)
{
	static struct spa_i18n_methods i18n_methods = {
		SPA_VERSION_I18N_METHODS,
		.text = i18n_text,
		.ntext = i18n_ntext,
	};
	support->i18n_iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_I18N,
			SPA_VERSION_I18N,
			&i18n_methods, support);
	_pipewire_i18n = (struct spa_i18n*) &support->i18n_iface;

	support->support[support->n_support++] =
		SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_I18N, _pipewire_i18n);

	return 0;
}

SPA_EXPORT
const char *pw_gettext(const char *msgid)
{
	return spa_i18n_text(_pipewire_i18n, msgid);
}
SPA_EXPORT
const char *pw_ngettext(const char *msgid, const char *msgid_plural, unsigned long int n)
{
	return spa_i18n_ntext(_pipewire_i18n, msgid, msgid_plural, n);
}

#ifdef HAVE_SYSTEMD
static struct spa_log *load_journal_logger(struct support *support)
{
	struct spa_handle *handle;
	void *iface = NULL;
	int res = -ENOENT;
	struct spa_dict info;
	struct spa_dict_item items[1];
	char level[32];
	uint32_t i;

	/* is the journal even available? */
	if (access("/run/systemd/journal/socket", F_OK) != 0)
		return NULL;

	snprintf(level, sizeof(level), "%d", pw_log_level);
	items[0] = SPA_DICT_ITEM_INIT(SPA_KEY_LOG_LEVEL, level);
	info = SPA_DICT_INIT(items, 1);

	handle = pw_load_spa_handle("support/libspa-journal",
				    SPA_NAME_SUPPORT_LOG, &info,
				    support->n_support, support->support);

	if (handle == NULL ||
	    (res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_Log, &iface)) < 0) {
			pw_log_error("can't get log interface %d", res);
	} else {
		/* look for an existing logger, and
		 * replace it with the journal logger */
		for (i = 0; i < support->n_support; i++) {
			if (strcmp(support->support[i].type, SPA_TYPE_INTERFACE_Log) == 0) {
				support->support[i].data = iface;
				break;
			}
		}
	}

	return (struct spa_log *) iface;
}
#endif

/** Initialize PipeWire
 *
 * \param argc pointer to argc
 * \param argv pointer to argv
 *
 * Initialize the PipeWire system, parse and modify any parameters given
 * by \a argc and \a argv and set up debugging.
 *
 * The environment variable \a PIPEWIRE_DEBUG
 *
 * \memberof pw_pipewire
 */
SPA_EXPORT
void pw_init(int *argc, char **argv[])
{
	const char *str;
	struct spa_dict_item items[5];
	uint32_t n_items;
	struct spa_dict info;
	struct support *support = &global_support;
	struct spa_log *log;
	char level[32];

	if (support->registry != NULL)
		return;

	if ((str = getenv("VALGRIND")))
		support->in_valgrind = pw_properties_parse_bool(str);

	if ((str = getenv("PIPEWIRE_DEBUG")))
		configure_debug(support, str);

	init_i18n(support);

	if ((str = getenv("SPA_PLUGIN_DIR")) == NULL)
		str = PLUGINDIR;
	support->plugin_dir = str;

	if ((str = getenv("SPA_SUPPORT_LIB")) == NULL)
		str = SUPPORTLIB;
	support->support_lib = str;

	spa_list_init(&global_registry.plugins);
	support->registry = &global_registry;

	if (pw_log_is_default()) {
		n_items = 0;
		if (getenv("NO_COLOR") == NULL)
			items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_LOG_COLORS, "true");
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_LOG_TIMESTAMP, "true");
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_LOG_LINE, "true");
		snprintf(level, sizeof(level), "%d", pw_log_level);
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_LOG_LEVEL, level);
		if ((str = getenv("PIPEWIRE_LOG")) != NULL)
			items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_LOG_FILE, str);
		info = SPA_DICT_INIT(items, n_items);

		log = add_interface(support, SPA_NAME_SUPPORT_LOG, SPA_TYPE_INTERFACE_Log, &info);
		if (log)
			pw_log_set(log);

#ifdef HAVE_SYSTEMD
		if ((str = getenv("PIPEWIRE_LOG_SYSTEMD")) == NULL ||
				strcmp(str, "true") == 0 || atoi(str) != 0) {
			log = load_journal_logger(support);
			if (log)
				pw_log_set(log);
		}
#endif
	} else {
		support->support[support->n_support++] =
			SPA_SUPPORT_INIT(SPA_TYPE_INTERFACE_Log, pw_log_get());
	}

	n_items = 0;
	if ((str = getenv("PIPEWIRE_CPU")))
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_CPU_FORCE, str);
	if ((str = getenv("PIPEWIRE_VM")))
		items[n_items++] = SPA_DICT_ITEM_INIT(SPA_KEY_CPU_VM_TYPE, str);
	info = SPA_DICT_INIT(items, n_items);

	add_interface(support, SPA_NAME_SUPPORT_CPU, SPA_TYPE_INTERFACE_CPU, &info);

	add_i18n(support);

	pw_log_info("version %s", pw_get_library_version());
}

SPA_EXPORT
void pw_deinit(void)
{
	struct support *support = &global_support;
	struct registry *registry = &global_registry;
	struct plugin *p;

	pw_log_set(NULL);
	spa_list_consume(p, &registry->plugins, link) {
		struct handle *h;
		p->ref++;
		spa_list_consume(h, &p->handles, link)
			unref_handle(h);
		unref_plugin(p);
	}
	if (support->categories)
		pw_free_strv(support->categories);
	free(support->i18n_domain);
	spa_zero(global_support);
	spa_zero(global_registry);

}

/** Check if a debug category is enabled
 *
 * \param name the name of the category to check
 * \return true if enabled
 *
 * Debugging categories can be enabled by using the PIPEWIRE_DEBUG
 * environment variable
 *
 * \memberof pw_pipewire
 */
SPA_EXPORT
bool pw_debug_is_category_enabled(const char *name)
{
	int i;

	if (global_support.categories == NULL)
		return false;

	for (i = 0; global_support.categories[i]; i++) {
		if (strcmp(global_support.categories[i], name) == 0)
			return true;
	}
	return false;
}

/** Get the application name \memberof pw_pipewire */
SPA_EXPORT
const char *pw_get_application_name(void)
{
	errno = ENOTSUP;
	return NULL;
}

/** Get the program name \memberof pw_pipewire */
SPA_EXPORT
const char *pw_get_prgname(void)
{
	static char prgname[PATH_MAX];
	spa_memzero(prgname, sizeof(prgname));
#if defined(__linux__) || defined(__FreeBSD_kernel__)
	{
		ssize_t len;
		if ((len = readlink("/proc/self/exe", prgname, sizeof(prgname)-1)) > 0)
			return strrchr(prgname, '/') + 1;
	}
#endif
#if defined __FreeBSD__
	{
		ssize_t len;
		spa_memzero(prgname, sizeof(prgname));
		if ((len = readlink("/proc/curproc/file", prgname, sizeof(prgname)-1)) > 0)
			return strrchr(prgname, '/') + 1;
	}
#endif
#ifndef __FreeBSD__
	{
		if (prctl(PR_GET_NAME, (unsigned long) prgname, 0, 0, 0) == 0)
			return prgname;
	}
#endif
	snprintf(prgname, sizeof(prgname), "pid-%d", getpid());
	return prgname;
}

/** Get the user name \memberof pw_pipewire */
SPA_EXPORT
const char *pw_get_user_name(void)
{
	struct passwd *pw;

	if ((pw = getpwuid(getuid())))
		return pw->pw_name;

	return NULL;
}

/** Get the host name \memberof pw_pipewire */
SPA_EXPORT
const char *pw_get_host_name(void)
{
	static char hname[256];

	if (gethostname(hname, 256) < 0)
		return NULL;

	hname[255] = 0;
	return hname;
}

SPA_EXPORT
bool pw_in_valgrind(void)
{
	return global_support.in_valgrind;
}

/** Get the client name
 *
 * Make a new PipeWire client name that can be used to construct a remote.
 *
 * \memberof pw_pipewire
 */
SPA_EXPORT
const char *pw_get_client_name(void)
{
	const char *cc;
	static char cname[256];

	if ((cc = pw_get_application_name()))
		return cc;
	else if ((cc = pw_get_prgname()))
		return cc;
	else {
		if (snprintf(cname, sizeof(cname), "pipewire-pid-%zd", (size_t) getpid()) < 0)
			return NULL;
		return cname;
	}
}

/** Reverse the direction \memberof pw_pipewire */
SPA_EXPORT
enum pw_direction pw_direction_reverse(enum pw_direction direction)
{
	if (direction == PW_DIRECTION_INPUT)
		return PW_DIRECTION_OUTPUT;
	else if (direction == PW_DIRECTION_OUTPUT)
		return PW_DIRECTION_INPUT;
	return direction;
}

/** Get the currently running version */
SPA_EXPORT
const char* pw_get_library_version(void)
{
	return pw_get_headers_version();
}

static const struct spa_type_info type_info[] = {
	{ SPA_ID_INVALID, SPA_ID_INVALID, "spa_types", spa_types },
	{ 0, 0, NULL, NULL },
};

SPA_EXPORT
const struct spa_type_info * pw_type_info(void)
{
	return type_info;
}
