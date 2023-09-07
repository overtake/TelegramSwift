/* PipeWire
 *
 * Copyright © 2021 Wim Taymans
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

#include <signal.h>
#include <getopt.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>
#if HAVE_PWD_H
#include <pwd.h>
#endif
#ifdef __FreeBSD__
#define O_PATH 0
#endif

#include <spa/utils/result.h>
#include <spa/utils/json.h>

#include <pipewire/impl.h>

#define NAME "config"

static int make_path(char *path, int size, const char *paths[])
{
	int i, len;
	char *p = path;
	for (i = 0; paths[i] != NULL; i++) {
		len = snprintf(p, size, "%s%s", i == 0 ? "" : "/", paths[i]);
		if (len < 0)
			return -errno;
		if (len >= size)
			return -ENOSPC;
		p += len;
		size -= len;
	}
	return 0;
}

static int get_read_path(char *path, size_t size, const char *prefix, const char *name)
{
	const char *dir;
	char buffer[4096];

	if (prefix[0] == '/') {
		const char *paths[] = { prefix, name, NULL };
		if (make_path(path, size, paths) == 0 &&
		    access(path, R_OK) == 0)
			return 1;
		return -ENOENT;
	}

	dir = getenv("XDG_CONFIG_HOME");
	if (dir != NULL) {
		const char *paths[] = { dir, "pipewire", prefix, name, NULL };
		if (make_path(path, size, paths) == 0 &&
		    access(path, R_OK) == 0)
			return 1;
	}
	dir = getenv("HOME");
	if (dir == NULL) {
		struct passwd pwd, *result = NULL;
		if (getpwuid_r(getuid(), &pwd, buffer, sizeof(buffer), &result) == 0)
			dir = result ? result->pw_dir : NULL;
	}
	if (dir != NULL) {
		const char *paths[] = { dir, ".config", "pipewire", prefix, name, NULL };
		if (make_path(path, size, paths) == 0 &&
		    access(path, R_OK) == 0)
			return 1;
	}
	dir = getenv("PIPEWIRE_CONFIG_DIR");
	if (dir == NULL)
		dir = PIPEWIRE_CONFIG_DIR;
	if (dir != NULL) {
		const char *paths[] = { dir, prefix, name, NULL };
		if (make_path(path, size, paths) == 0 &&
		    access(path, R_OK) == 0)
			return 1;
	}
	return 0;
}

static int ensure_path(char *path, int size, const char *paths[])
{
	int i, len, res, mode;
	char *p = path;

	for (i = 0; paths[i] != NULL; i++) {
		len = snprintf(p, size, "%s/", paths[i]);
		if (len < 0)
			return -errno;
		if (len >= size)
			return -ENOSPC;

		p += len;
		size -= len;

		mode = X_OK;
		if (paths[i+1] == NULL)
			mode |= R_OK | W_OK;

		if ((res = access(path, mode)) < 0) {
			if (errno != ENOENT)
				return -errno;
			if ((res = mkdir(path, 0700)) < 0) {
				pw_log_info("Can't create directory %s: %m", path);
                                return -errno;
			}
			if ((res = access(path, mode)) < 0)
				return -errno;

			pw_log_info("created directory %s", path);
		}
	}
	return 0;
}

static int open_write_dir(char *path, int size, const char *prefix)
{
	const char *dir;
	char buffer[4096];
	int res;

	if (prefix != NULL && prefix[0] == '/') {
		const char *paths[] = { prefix, NULL };
		if (ensure_path(path, size, paths) == 0)
			goto found;
	}
	dir = getenv("XDG_CONFIG_HOME");
	if (dir != NULL) {
		const char *paths[] = { dir, "pipewire", prefix, NULL };
		if (ensure_path(path, size, paths) == 0)
			goto found;
	}
	dir = getenv("HOME");
	if (dir == NULL) {
		struct passwd pwd, *result = NULL;
		if (getpwuid_r(getuid(), &pwd, buffer, sizeof(buffer), &result) == 0)
			dir = result ? result->pw_dir : NULL;
	}
	if (dir != NULL) {
		const char *paths[] = { dir, ".config", "pipewire", prefix, NULL };
		if (ensure_path(path, size, paths) == 0)
			goto found;
	}
	return -ENOENT;
found:
	if ((res = open(path, O_CLOEXEC | O_DIRECTORY | O_PATH)) < 0) {
		pw_log_error("Can't open state directory %s: %m", path);
		return -errno;
	}
        return res;
}

SPA_EXPORT
int pw_conf_save_state(const char *prefix, const char *name, struct pw_properties *conf)
{
	const struct spa_dict_item *it;
	char path[PATH_MAX];
	char *tmp_name;
	int res, sfd, fd, count = 0;
	FILE *f;

	if ((sfd = open_write_dir(path, sizeof(path), prefix)) < 0)
		return sfd;

	tmp_name = alloca(strlen(name)+5);
	sprintf(tmp_name, "%s.tmp", name);
	if ((fd = openat(sfd, tmp_name,  O_CLOEXEC | O_CREAT | O_WRONLY | O_TRUNC, 0600)) < 0) {
		pw_log_error("can't open file '%s': %m", tmp_name);
		res = -errno;
		goto error;
	}

	f = fdopen(fd, "w");
	fprintf(f, "{");
	spa_dict_for_each(it, &conf->dict) {
		char key[1024];

		if (spa_json_encode_string(key, sizeof(key)-1, it->key) >= (int)sizeof(key)-1)
			continue;

		fprintf(f, "%s\n  %s: %s", count++ == 0 ? "" : ",", key, it->value);
	}
	fprintf(f, "%s}", count == 0 ? " " : "\n");
	fclose(f);

	if (renameat(sfd, tmp_name, sfd, name) < 0) {
		pw_log_error("can't rename temp file '%s': %m", tmp_name);
		res = -errno;
		goto error;
	}
	res = 0;
	pw_log_info(NAME" %p: saved state '%s%s'", conf, path, name);
error:
	close(sfd);
	return res;
}

static int conf_load(const char *prefix, const char *name, struct pw_properties *conf)
{
	char path[PATH_MAX], *data;
	struct stat sbuf;
	int fd;

	if (prefix == NULL) {
		prefix = name;
		name = NULL;
	}

	if (get_read_path(path, sizeof(path), prefix, name) == 0) {
		pw_log_debug(NAME" %p: can't load config '%s': %m", conf, path);
		return -ENOENT;
	}
	if ((fd = open(path,  O_CLOEXEC | O_RDONLY)) < 0)  {
		pw_log_warn(NAME" %p: error loading config '%s': %m", conf, path);
		return -errno;
	}

	pw_log_info(NAME" %p: loading config '%s'", conf, path);
	if (fstat(fd, &sbuf) < 0)
		goto error_close;
	if ((data = mmap(NULL, sbuf.st_size, PROT_READ, MAP_PRIVATE, fd, 0)) == MAP_FAILED)
		goto error_close;
	close(fd);

	pw_properties_update_string(conf, data, sbuf.st_size);
	munmap(data, sbuf.st_size);

	return 0;

error_close:
	close(fd);
	return -errno;
}

SPA_EXPORT
int pw_conf_load_conf(const char *prefix, const char *name, struct pw_properties *conf)
{
	return conf_load(prefix, name, conf);
}

SPA_EXPORT
int pw_conf_load_state(const char *prefix, const char *name, struct pw_properties *conf)
{
	return conf_load(prefix, name, conf);
}

/* context.spa-libs = {
 *  <factory-name regex> = <library-name>
 * }
 */
static int parse_spa_libs(struct pw_context *context, char *str)
{
	struct spa_json it[2];
	char key[512], value[512];

	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_object(&it[0], &it[1]) < 0)
		return -EINVAL;

	while (spa_json_get_string(&it[1], key, sizeof(key)-1) > 0) {
		const char *val;
		if (key[0] == '#') {
			if (spa_json_next(&it[1], &val) <= 0)
				break;
		}
		else if (spa_json_get_string(&it[1], value, sizeof(value)-1) > 0) {
			pw_context_add_spa_lib(context, key, value);
		}
	}
	return 0;
}

static int load_module(struct pw_context *context, const char *key, const char *args, const char *flags)
{
	if (pw_context_load_module(context, key, args, NULL) == NULL) {
		if (errno == ENOENT && flags && strstr(flags, "ifexists") != NULL) {
			pw_log_debug(NAME" %p: skipping unavailable module %s",
					context, key);
		} else if (flags == NULL || strstr(flags, "nofail") == NULL) {
			pw_log_error(NAME" %p: could not load mandatory module \"%s\": %m",
					context, key);
			return -errno;
		} else {
			pw_log_info(NAME" %p: could not load optional module \"%s\": %m",
					context, key);
		}
	}
	return 0;
}

/*
 * context.modules = [
 *   {   name = <module-name>
 *       [ args = { <key> = <value> ... } ]
 *       [ flags = [ [ ifexists ] [ nofail ] ]
 *   }
 * ]
 */
static int parse_modules(struct pw_context *context, char *str)
{
	struct spa_json it[3];
	char key[512];
	int res = 0;

	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_array(&it[0], &it[1]) < 0)
		return -EINVAL;

	while (spa_json_enter_object(&it[1], &it[2]) > 0) {
		char *name = NULL, *args = NULL, *flags = NULL;

		while (spa_json_get_string(&it[2], key, sizeof(key)-1) > 0) {
			const char *val;
			int len;

			if ((len = spa_json_next(&it[2], &val)) <= 0)
				break;

			if (strcmp(key, "name") == 0) {
				name = (char*)val;
				spa_json_parse_string(val, len, name);
			} else if (strcmp(key, "args") == 0) {
				if (spa_json_is_container(val, len))
					len = spa_json_container_len(&it[2], val, len);

				args = (char*)val;
				spa_json_parse_string(val, len, args);
			} else if (strcmp(key, "flags") == 0) {
				if (spa_json_is_container(val, len))
					len = spa_json_container_len(&it[2], val, len);
				flags = (char*)val;
				spa_json_parse_string(val, len, flags);
			}
		}
		if (name != NULL)
			res = load_module(context, name, args, flags);

		if (res < 0)
			break;
	}
	return res;
}

static int create_object(struct pw_context *context, const char *key, const char *args, const char *flags)
{
	struct pw_impl_factory *factory;
	void *obj;

	pw_log_debug("find factory %s", key);
	factory = pw_context_find_factory(context, key);
	if (factory == NULL) {
		if (flags && strstr(flags, "nofail") != NULL)
			return 0;
		pw_log_error("can't find factory %s", key);
		return -ENOENT;
	}
	pw_log_debug("create object with args %s", args);
	obj = pw_impl_factory_create_object(factory,
			NULL, NULL, 0,
			args ? pw_properties_new_string(args) : NULL,
			SPA_ID_INVALID);
	if (obj == NULL) {
		if (flags && strstr(flags, "nofail") != NULL)
			return 0;
		pw_log_error("can't create object from factory %s: %m", key);
		return -errno;
	}
	return 0;
}

/*
 * context.objects = [
 *   {   factory = <factory-name>
 *       [ args  = { <key> = <value> ... } ]
 *       [ flags = [ [ nofail ] ] ]
 *   }
 * ]
 */
static int parse_objects(struct pw_context *context, char *str)
{
	struct spa_json it[3];
	char key[512];
	int res = 0;

	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_array(&it[0], &it[1]) < 0)
		return -EINVAL;

	while (spa_json_enter_object(&it[1], &it[2]) > 0) {
		char *factory = NULL, *args = NULL, *flags = NULL;

		while (spa_json_get_string(&it[2], key, sizeof(key)-1) > 0) {
			const char *val;
			int len;

			if ((len = spa_json_next(&it[2], &val)) <= 0)
				break;

			if (strcmp(key, "factory") == 0) {
				factory = (char*)val;
				spa_json_parse_string(val, len, factory);
			} else if (strcmp(key, "args") == 0) {
				if (spa_json_is_container(val, len))
					len = spa_json_container_len(&it[2], val, len);

				args = (char*)val;
				spa_json_parse_string(val, len, args);
			} else if (strcmp(key, "flags") == 0) {
				if (spa_json_is_container(val, len))
					len = spa_json_container_len(&it[2], val, len);

				flags = (char*)val;
				spa_json_parse_string(val, len, flags);
			}
		}
		if (factory != NULL)
			res = create_object(context, factory, args, flags);

		if (res < 0)
			break;
	}
	return res;
}

static int do_exec(struct pw_context *context, const char *key, const char *args)
{
	int pid, res, n_args;

	pid = fork();

	if (pid == 0) {
		char *cmd, **argv;

		cmd = spa_aprintf("%s %s", key, args ? args : "");
		argv = pw_split_strv(cmd, " \t", INT_MAX, &n_args);
		free(cmd);

		pw_log_info("exec %s '%s'", key, args);
		res = execvp(key, argv);
		pw_free_strv(argv);

		if (res == -1) {
			res = -errno;
			pw_log_error("execvp error '%s': %m", key);
			return res;
		}
	}
	else {
		int status;
		res = waitpid(pid, &status, WNOHANG);
		pw_log_info("exec got pid %d res:%d status:%d", pid, res, status);
	}
	return 0;
}

/*
 * context.exec = [
 *   { path = <program-name>
 *     [ args = "<arguments>" ]
 *   }
 * ]
 */
static int parse_exec(struct pw_context *context, char *str)
{
	struct spa_json it[3];
	char key[512];
	int res = 0;

	spa_json_init(&it[0], str, strlen(str));
	if (spa_json_enter_array(&it[0], &it[1]) < 0)
		return -EINVAL;

	while (spa_json_enter_object(&it[1], &it[2]) > 0) {
		char *path = NULL, *args = NULL;

		while (spa_json_get_string(&it[2], key, sizeof(key)-1) > 0) {
			const char *val;
			int len;

			if ((len = spa_json_next(&it[2], &val)) <= 0)
				break;

			if (strcmp(key, "path") == 0) {
				path = (char*)val;
				spa_json_parse_string(val, len, path);
			} else if (strcmp(key, "args") == 0) {
				args = (char*)val;
				spa_json_parse_string(val, len, args);
			}
		}
		if (path != NULL)
			res = do_exec(context, path, args);

		if (res < 0)
			break;
	}
	return res;
}

SPA_EXPORT
int pw_context_parse_conf_section(struct pw_context *context,
		struct pw_properties *conf, const char *section)
{
	const char *str;
	char *s;
	int res;

	if ((str = pw_properties_get(conf, section)) == NULL)
		return -ENOENT;

	s = strdup(str);

	if (strcmp(section, "context.spa-libs") == 0)
		res = parse_spa_libs(context, s);
	else if (strcmp(section, "context.modules") == 0)
		res = parse_modules(context, s);
	else if (strcmp(section, "context.objects") == 0)
		res = parse_objects(context, s);
	else if (strcmp(section, "context.exec") == 0)
		res = parse_exec(context, s);
	else
		res = -EINVAL;

	free(s);

	return res;
}
