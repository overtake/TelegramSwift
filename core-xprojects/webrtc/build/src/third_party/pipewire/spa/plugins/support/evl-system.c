/* Spa
 *
 * Copyright © 2019 Wim Taymans
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

#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/eventfd.h>
#include <sys/signalfd.h>

#include <evl/evl.h>
#include <evl/timer.h>

#include <spa/support/log.h>
#include <spa/support/system.h>
#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/utils/result.h>

#define NAME "evl-system"

#define MAX_POLL	512

struct poll_entry {
	int pfd;
	int fd;
	uint32_t events;
	void *data;
};

struct impl {
	struct spa_handle handle;
	struct spa_system system;

        struct spa_log *log;

	struct poll_entry entries[MAX_POLL];
	uint32_t n_entries;

	uint32_t n_xbuf;
	int attached;
	int pid;
};

static ssize_t impl_read(void *object, int fd, void *buf, size_t count)
{
	return oob_read(fd, buf, count);
}

static ssize_t impl_write(void *object, int fd, const void *buf, size_t count)
{
	return oob_write(fd, buf, count);
}

static int impl_ioctl(void *object, int fd, unsigned long request, ...)
{
	int res;
	va_list ap;
	long arg;

	va_start(ap, request);
	arg = va_arg(ap, long);
	res = oob_ioctl(fd, request, arg);
	va_end(ap);

	return res;
}

static int impl_close(void *object, int fd)
{
	return close(fd);
}

static inline int clock_id_to_evl(int clockid)
{
	switch(clockid) {
	case CLOCK_MONOTONIC:
		return EVL_CLOCK_MONOTONIC;
	case CLOCK_REALTIME:
		return EVL_CLOCK_REALTIME;
	default:
		return -clockid;
	}
}

/* clock */
static int impl_clock_gettime(void *object,
			int clockid, struct timespec *value)
{
	return evl_read_clock(clock_id_to_evl(clockid), value);
}

static int impl_clock_getres(void *object,
			int clockid, struct timespec *res)
{
	return evl_get_clock_resolution(clock_id_to_evl(clockid), res);
}

/* poll */
static int impl_pollfd_create(void *object, int flags)
{
	int retval;
	retval = evl_new_poll();
	return retval;
}

static inline struct poll_entry *find_entry(struct impl *impl, int pfd, int fd)
{
	uint32_t i;
	for (i = 0; i < impl->n_entries; i++) {
		struct poll_entry *e = &impl->entries[i];
		if (e->pfd == pfd && e->fd == fd)
			return e;
	}
	return NULL;
}

static int impl_pollfd_add(void *object, int pfd, int fd, uint32_t events, void *data)
{
	struct impl *impl = object;
	struct poll_entry *e;

	if (impl->n_entries == MAX_POLL)
		return -ENOSPC;

	e = &impl->entries[impl->n_entries++];
	e->pfd = pfd;
	e->fd = fd;
	e->events = events;
	e->data = data;
	return evl_add_pollfd(pfd, fd, e->events);
}

static int impl_pollfd_mod(void *object, int pfd, int fd, uint32_t events, void *data)
{
	struct impl *impl = object;
	struct poll_entry *e;

	e = find_entry(impl, pfd, fd);
	if (e == NULL)
		return -ENOENT;

	e->events = events;
	e->data = data;
	return evl_mod_pollfd(pfd, fd, e->events);
}

static int impl_pollfd_del(void *object, int pfd, int fd)
{
	struct impl *impl = object;
	struct poll_entry *e;

	e = find_entry(impl, pfd, fd);
	if (e == NULL)
		return -ENOENT;

	e->pfd = -1;
	e->fd = -1;
	return evl_del_pollfd(pfd, fd);
}

static int impl_pollfd_wait(void *object, int pfd,
		struct spa_poll_event *ev, int n_ev, int timeout)
{
	struct impl *impl = object;
	struct evl_poll_event pollset[n_ev];
	struct timespec tv;
	int i, j, res;

	if (impl->attached == 0) {
		res = evl_attach_self("evl-thread-%d-%p", impl->pid, impl);
		if (res < 0)
			return res;
		impl->attached = res;
	}

	if (timeout == -1) {
		tv.tv_sec = 0;
		tv.tv_nsec = 0;
	} else {
		tv.tv_sec = timeout / SPA_MSEC_PER_SEC;
		tv.tv_nsec = (timeout % SPA_MSEC_PER_SEC) * SPA_NSEC_PER_MSEC;
	}
	res = evl_timedpoll(pfd, pollset, n_ev, &tv);
	if (SPA_UNLIKELY(res < 0))
		return res;

        for (i = 0, j = 0; i < res; i++) {
		struct poll_entry *e;

		e = find_entry(impl, pfd, pollset[i].fd);
		if (e == NULL)
			continue;

		ev[j].events = pollset[i].events;
		ev[j].data = e->data;
		j++;
	}
	return j;
}

/* timers */
static int impl_timerfd_create(void *object, int clockid, int flags)
{
	int cid;

	switch (clockid) {
	case CLOCK_MONOTONIC:
		cid = EVL_CLOCK_MONOTONIC;
		break;
	default:
		return -ENOTSUP;
	}
	return evl_new_timer(cid);
}

static int impl_timerfd_settime(void *object,
			int fd, int flags,
			const struct itimerspec *new_value,
			struct itimerspec *old_value)
{
	struct itimerspec val = *new_value;

	if (!(flags & SPA_FD_TIMER_ABSTIME)) {
		struct timespec now;

		evl_read_clock(EVL_CLOCK_MONOTONIC, &now);
		val.it_value.tv_sec += now.tv_sec;
		val.it_value.tv_nsec += now.tv_nsec;
		if (val.it_value.tv_nsec >= 1000000000) {
			val.it_value.tv_sec++;
			val.it_value.tv_nsec -= 1000000000;
		}
	}
	return evl_set_timer(fd, &val, old_value);
}

static int impl_timerfd_gettime(void *object,
			int fd, struct itimerspec *curr_value)
{
	return evl_get_timer(fd, curr_value);

}
static int impl_timerfd_read(void *object, int fd, uint64_t *expirations)
{
	uint32_t ticks;
	if (oob_read(fd, &ticks, sizeof(ticks)) != sizeof(ticks))
		return -errno;
	*expirations = ticks;
	return 0;
}

/* events */
static int impl_eventfd_create(void *object, int flags)
{
	struct impl *impl = object;
	int res;

	res = evl_new_xbuf(1024, 1024, "xbuf-%d-%p-%d", impl->pid, impl, impl->n_xbuf);
	if (res < 0)
		return res;

	impl->n_xbuf++;

	if (flags & SPA_FD_NONBLOCK)
		fcntl(res, F_SETFL, fcntl(res, F_GETFL) | O_NONBLOCK);

	return res;
}

static int impl_eventfd_write(void *object, int fd, uint64_t count)
{
	if (write(fd, &count, sizeof(uint64_t)) != sizeof(uint64_t))
		return -errno;
	return 0;
}

static int impl_eventfd_read(void *object, int fd, uint64_t *count)
{
	if (oob_read(fd, count, sizeof(uint64_t)) != sizeof(uint64_t))
		return -errno;
	return 0;
}

/* signals */
static int impl_signalfd_create(void *object, int signal, int flags)
{
	sigset_t mask;
	int res, fl = 0;

	if (flags & SPA_FD_CLOEXEC)
		fl |= SFD_CLOEXEC;
	if (flags & SPA_FD_NONBLOCK)
		fl |= SFD_NONBLOCK;

	sigemptyset(&mask);
	sigaddset(&mask, signal);
	res = signalfd(-1, &mask, fl);
	sigprocmask(SIG_BLOCK, &mask, NULL);

	return res;
}

static int impl_signalfd_read(void *object, int fd, int *signal)
{
	struct signalfd_siginfo signal_info;
	int len;

	len = read(fd, &signal_info, sizeof signal_info);
	if (!(len == -1 && errno == EAGAIN) && len != sizeof signal_info)
		return -errno;

	*signal = signal_info.ssi_signo;

	return 0;
}

static const struct spa_system_methods impl_system = {
	SPA_VERSION_SYSTEM_METHODS,
	.read = impl_read,
	.write = impl_write,
	.ioctl = impl_ioctl,
	.close = impl_close,
	.clock_gettime = impl_clock_gettime,
	.clock_getres = impl_clock_getres,
	.pollfd_create = impl_pollfd_create,
	.pollfd_add = impl_pollfd_add,
	.pollfd_mod = impl_pollfd_mod,
	.pollfd_del = impl_pollfd_del,
	.pollfd_wait = impl_pollfd_wait,
	.timerfd_create = impl_timerfd_create,
	.timerfd_settime = impl_timerfd_settime,
	.timerfd_gettime = impl_timerfd_gettime,
	.timerfd_read = impl_timerfd_read,
	.eventfd_create = impl_eventfd_create,
	.eventfd_write = impl_eventfd_write,
	.eventfd_read = impl_eventfd_read,
	.signalfd_create = impl_signalfd_create,
	.signalfd_read = impl_signalfd_read,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *impl;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	impl = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_System) == 0)
		*interface = &impl->system;
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

static int
impl_init(const struct spa_handle_factory *factory,
	  struct spa_handle *handle,
	  const struct spa_dict *info,
	  const struct spa_support *support,
	  uint32_t n_support)
{
	struct impl *impl;
	int res;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	impl = (struct impl *) handle;
	impl->system.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_System,
			SPA_VERSION_SYSTEM,
			&impl_system, impl);

	impl->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	impl->pid = getpid();

	if ((res = evl_attach_self("evl-system-%d-%p", impl->pid, impl)) < 0) {
		spa_log_error(impl->log, NAME " %p: init failed: %s", impl, spa_strerror(res));
		return res;
	}

	spa_log_debug(impl->log, NAME " %p: initialized", impl);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_System,},
};

static int
impl_enum_interface_info(const struct spa_handle_factory *factory,
			 const struct spa_interface_info **info,
			 uint32_t *index)
{
	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(info != NULL, -EINVAL);
	spa_return_val_if_fail(index != NULL, -EINVAL);

	if (*index >= SPA_N_ELEMENTS(impl_interfaces))
		return 0;

	*info = &impl_interfaces[(*index)++];
	return 1;
}

const struct spa_handle_factory spa_support_evl_system_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_SUPPORT_SYSTEM,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info
};
