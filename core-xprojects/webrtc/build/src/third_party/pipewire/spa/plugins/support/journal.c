/* Spa
 *
 * Copyright © 2020 Sergey Bugaev
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
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <limits.h>
#include <syslog.h>
#include <sys/stat.h>

#include <spa/support/log.h>
#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/utils/names.h>

#include <systemd/sd-journal.h>

#define NAME "journal"

#define DEFAULT_LOG_LEVEL SPA_LOG_LEVEL_INFO

struct impl {
	struct spa_handle handle;
	struct spa_log log;

	/* if non-null, we'll additionally forward all logging to there */
	struct spa_log *chain_log;
};

static SPA_PRINTF_FUNC(6,0) void
impl_log_logv(void *object,
	      enum spa_log_level level,
	      const char *file,
	      int line,
	      const char *func,
	      const char *fmt,
	      va_list args)
{
	struct impl *impl = object;
	char line_buffer[32];
	char file_buffer[strlen("CODE_FILE=") + strlen(file) + 1];
	char message_buffer[LINE_MAX];
	int priority;

	if (impl->chain_log != NULL) {
		va_list args_copy;
		va_copy(args_copy, args);
		spa_interface_call(&impl->chain_log->iface,
				   struct spa_log_methods, logv, 0,
				   level, file, line, func, fmt, args_copy);
		va_end(args_copy);
	}

	/* convert SPA log level to syslog priority */
	switch (level) {
	case SPA_LOG_LEVEL_ERROR:
		priority = LOG_ERR;
		break;
	case SPA_LOG_LEVEL_WARN:
		priority = LOG_WARNING;
		break;
	case SPA_LOG_LEVEL_INFO:
		priority = LOG_INFO;
		break;
	case SPA_LOG_LEVEL_DEBUG:
	case SPA_LOG_LEVEL_TRACE:
	default:
		priority = LOG_DEBUG;
		break;
	}

	/* we'll be using the low-level journal API, which expects us to provide
	 * the location explicitly. line and file are to be passed as preformatted
	 * entries, whereas the function name is passed as-is, and converted into
	 * a field inside sd_journal_send_with_location(). */
	snprintf(line_buffer, sizeof(line_buffer), "CODE_LINE=%d", line);
	snprintf(file_buffer, sizeof(file_buffer), "CODE_FILE=%s", file);
	vsnprintf(message_buffer, sizeof(message_buffer), fmt, args);

	sd_journal_send_with_location(file_buffer, line_buffer, func,
				      "MESSAGE=%s", message_buffer,
				      "PRIORITY=%i", priority,
				      NULL);
}

static SPA_PRINTF_FUNC(6,7) void
impl_log_log(void *object,
	     enum spa_log_level level,
	     const char *file,
	     int line,
	     const char *func,
	     const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	impl_log_logv(object, level, file, line, func, fmt, args);
	va_end(args);
}

static const struct spa_log_methods impl_log = {
	SPA_VERSION_LOG_METHODS,
	.log = impl_log_log,
	.logv = impl_log_logv,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_Log) == 0)
		*interface = &this->log;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	return 0;
}

static size_t
impl_get_size(const struct spa_handle_factory *factory,
	      const struct spa_dict *params)
{
	return sizeof(struct impl);
}

/** Determine if our stderr goes straight to the journal */
static int
stderr_is_connected_to_journal(void)
{
	const char *journal_stream;
	unsigned long long journal_device, journal_inode;
	struct stat stderr_stat;

	/* when a service's stderr is connected to the journal, systemd sets
	 * JOURNAL_STREAM in the environment of that service to device:inode
	 * of its stderr. if the variable is not set, clearly our stderr is
	 * not connected to the journal */
	journal_stream = getenv("JOURNAL_STREAM");
	if (journal_stream == NULL)
		return 0;

	/* if it *is* set, that doesn't immediately mean that *our* stderr
	 * is (still) connected to the journal. to know for sure, we have to
	 * compare our actual stderr to the stream systemd has created for
	 * the service we're a part of */

	if (sscanf(journal_stream, "%llu:%llu", &journal_device, &journal_inode) != 2)
		return 0;

	if (fstat(STDERR_FILENO, &stderr_stat) < 0)
		return 0;

	return stderr_stat.st_dev == journal_device && stderr_stat.st_ino == journal_inode;
}

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *impl;
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	impl = (struct impl *) handle;

	impl->log.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_Log,
			SPA_VERSION_LOG,
			&impl_log, impl);
	impl->log.level = DEFAULT_LOG_LEVEL;

	if (info) {
		if ((str = spa_dict_lookup(info, SPA_KEY_LOG_LEVEL)) != NULL)
			impl->log.level = atoi(str);
	}

	/* if our stderr goes to the journal, there's no point in logging both
	 * via the native journal API and by printing to stderr, that would just
	 * result in message duplication */
	if (stderr_is_connected_to_journal())
		impl->chain_log = NULL;
	else
		impl->chain_log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	spa_log_debug(&impl->log, NAME " %p: initialized", impl);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_Log,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	switch (*index) {
	case 0:
		*info = &impl_interfaces[*index];
		break;
	default:
		return 0;
	}
	(*index)++;

	return 1;
}

static const struct spa_handle_factory journal_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	.name = SPA_NAME_SUPPORT_LOG,
	.info = NULL,
	.get_size = impl_get_size,
	.init = impl_init,
	.enum_interface_info = impl_enum_interface_info,
};


SPA_EXPORT
int spa_handle_factory_enum(const struct spa_handle_factory **factory, uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	switch (*index) {
	case 0:
		*factory = &journal_factory;
		break;
	default:
		return 0;
	}
	(*index)++;
	return 1;
}
