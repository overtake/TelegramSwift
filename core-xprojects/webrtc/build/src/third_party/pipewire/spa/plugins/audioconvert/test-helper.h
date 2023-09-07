#include <dlfcn.h>

#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/utils/result.h>
#include <spa/support/cpu.h>
#include <spa/utils/names.h>

static inline const struct spa_handle_factory *get_factory(spa_handle_factory_enum_func_t enum_func,
		const char *name, uint32_t version)
{
	uint32_t i;
	int res;
	const struct spa_handle_factory *factory;

	for (i = 0;;) {
		if ((res = enum_func(&factory, &i)) <= 0) {
			if (res < 0)
				errno = -res;
			break;
		}
		if (factory->version >= version &&
		    !strcmp(factory->name, name))
			return factory;
	}
	return NULL;
}

static inline struct spa_handle *load_handle(const struct spa_support *support,
		uint32_t n_support, const char *lib, const char *name)
{
	int res, len;
	void *hnd;
	spa_handle_factory_enum_func_t enum_func;
	const struct spa_handle_factory *factory;
	struct spa_handle *handle;
	const char *str;
	char *path;

	if ((str = getenv("SPA_PLUGIN_DIR")) == NULL)
		str = PLUGINDIR;

	len = strlen(str) + strlen(lib) + 2;
	path = alloca(len);
	snprintf(path, len, "%s/%s", str, lib);

	if ((hnd = dlopen(path, RTLD_NOW)) == NULL) {
		fprintf(stderr, "can't load %s: %s\n", lib, dlerror());
		res = -ENOENT;
		goto error;
	}
	if ((enum_func = dlsym(hnd, SPA_HANDLE_FACTORY_ENUM_FUNC_NAME)) == NULL) {
		fprintf(stderr, "can't find enum function\n");
		res = -ENXIO;
		goto error_close;
	}

	if ((factory = get_factory(enum_func, name, SPA_VERSION_HANDLE_FACTORY)) == NULL) {
		fprintf(stderr, "can't find factory\n");
		res = -ENOENT;
		goto error_close;
	}
	handle = calloc(1, spa_handle_factory_get_size(factory, NULL));
	if ((res = spa_handle_factory_init(factory, handle,
					NULL, support, n_support)) < 0) {
		fprintf(stderr, "can't make factory instance: %d\n", res);
		goto error_close;
	}
	return handle;

error_close:
	dlclose(hnd);
error:
	errno = -res;
	return NULL;
}

static inline uint32_t get_cpu_flags(void)
{
	struct spa_handle *handle;
	uint32_t flags;
	void *iface;
	int res;

	handle = load_handle(NULL, 0, "support/libspa-support.so", SPA_NAME_SUPPORT_CPU);
	if (handle == NULL)
		return 0;
	if ((res = spa_handle_get_interface(handle, SPA_TYPE_INTERFACE_CPU, &iface)) < 0) {
		fprintf(stderr, "can't get CPU interface %s\n", spa_strerror(res));
		return 0;
	}
	flags = spa_cpu_get_flags((struct spa_cpu*)iface);

	free(handle);

	return flags;
}
