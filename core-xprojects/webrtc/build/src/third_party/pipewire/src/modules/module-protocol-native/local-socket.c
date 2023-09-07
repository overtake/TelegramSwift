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

#include "config.h"

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/file.h>
#if HAVE_PWD_H
#include <pwd.h>
#endif

#include <pipewire/pipewire.h>

#define DEFAULT_SYSTEM_RUNTIME_DIR "/run/pipewire"

static const char *
get_remote(const struct spa_dict *props)
{
	const char *name = NULL;

	if (props)
		name = spa_dict_lookup(props, PW_KEY_REMOTE_NAME);
	if (name == NULL || name[0] == '\0')
		name = getenv("PIPEWIRE_REMOTE");
	if (name == NULL || name[0] == '\0')
		name = PW_DEFAULT_REMOTE;
	return name;
}

static const char *
get_runtime_dir(void)
{
	const char *runtime_dir;

	runtime_dir = getenv("PIPEWIRE_RUNTIME_DIR");
	if (runtime_dir == NULL)
		runtime_dir = getenv("XDG_RUNTIME_DIR");
	if (runtime_dir == NULL)
		runtime_dir = getenv("HOME");
	if (runtime_dir == NULL)
		runtime_dir = getenv("USERPROFILE");
	if (runtime_dir == NULL) {
		struct passwd pwd, *result = NULL;
		char buffer[4096];
		if (getpwuid_r(getuid(), &pwd, buffer, sizeof(buffer), &result) == 0)
			runtime_dir = result ? result->pw_dir : NULL;
	}
	return runtime_dir;
}

static const char *
get_system_dir(void)
{
	return DEFAULT_SYSTEM_RUNTIME_DIR;
}

static int try_connect(struct pw_protocol_client *client,
		const char *runtime_dir, const char *name,
		void (*done_callback) (void *data, int res),
		void *data)
{
	struct sockaddr_un addr;
	socklen_t size;
	int res, name_size, fd;

	pw_log_info("connecting to '%s' runtime_dir:%s", name, runtime_dir);

	if ((fd = socket(PF_LOCAL, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0)) < 0) {
		res = -errno;
		goto error;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_LOCAL;
	if (runtime_dir == NULL)
		name_size = snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", name) + 1;
	else
		name_size = snprintf(addr.sun_path, sizeof(addr.sun_path), "%s/%s", runtime_dir, name) + 1;

	if (name_size > (int) sizeof addr.sun_path) {
		if (runtime_dir == NULL)
			pw_log_error("client %p: socket path \"%s\" plus null terminator exceeds %i bytes",
				client, name, (int) sizeof(addr.sun_path));
		else
			pw_log_error("client %p: socket path \"%s/%s\" plus null terminator exceeds %i bytes",
				client, runtime_dir, name, (int) sizeof(addr.sun_path));
		res = -ENAMETOOLONG;
		goto error_close;
	};

	size = offsetof(struct sockaddr_un, sun_path) + name_size;

	if (connect(fd, (struct sockaddr *) &addr, size) < 0) {
		pw_log_debug("connect to '%s' failed: %m", name);
		if (errno == ENOENT)
			errno = EHOSTDOWN;
		if (errno == EAGAIN) {
			pw_log_info("client %p: connect pending, fd %d", client, fd);
		} else {
			res = -errno;
			goto error_close;
		}
	}

	res = pw_protocol_client_connect_fd(client, fd, true);

	if (done_callback)
		done_callback(data, res);

	return res;

error_close:
	close(fd);
error:
	return res;
}

int pw_protocol_native_connect_local_socket(struct pw_protocol_client *client,
					    const struct spa_dict *props,
					    void (*done_callback) (void *data, int res),
					    void *data)
{
	const char *runtime_dir, *name;
	int res;

	name = get_remote(props);
	if (name == NULL)
		return -EINVAL;

	if (name[0] == '/') {
		res = try_connect(client, NULL, name, done_callback, data);
	} else {
		runtime_dir = get_runtime_dir();
		if (runtime_dir != NULL) {
			res = try_connect(client, runtime_dir, name, done_callback, data);
			if (res >= 0)
				goto exit;
		}
		runtime_dir = get_system_dir();
		if (runtime_dir != NULL)
			res = try_connect(client, runtime_dir, name, done_callback, data);
	}
exit:
	return res;
}
