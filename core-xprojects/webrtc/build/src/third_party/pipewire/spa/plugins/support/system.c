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
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <sys/timerfd.h>
#include <sys/eventfd.h>
#include <sys/signalfd.h>

#include <spa/support/log.h>
#include <spa/support/system.h>
#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/utils/names.h>

#define NAME "system"

#ifndef TFD_TIMER_CANCEL_ON_SET
#  define TFD_TIMER_CANCEL_ON_SET (1 << 1)
#endif

struct impl {
	struct spa_handle handle;
	struct spa_system system;
        struct spa_log *log;
};

static ssize_t impl_read(void *object, int fd, void *buf, size_t count)
{
	ssize_t res = read(fd, buf, count);
	return res < 0 ? -errno : res;
}

static ssize_t impl_write(void *object, int fd, const void *buf, size_t count)
{
	ssize_t res = write(fd, buf, count);
	return res < 0 ? -errno : res;
}

static int impl_ioctl(void *object, int fd, unsigned long request, ...)
{
	int res;
	va_list ap;
	long arg;

	va_start(ap, request);
	arg = va_arg(ap, long);
	res = ioctl(fd, request, arg);
	va_end(ap);

	return res < 0 ? -errno : res;
}

static int impl_close(void *object, int fd)
{
	struct impl *impl = object;
	int res = close(fd);
	spa_log_debug(impl->log, NAME " %p: close fd:%d", impl, fd);
	return res < 0 ? -errno : res;
}

/* clock */
static int impl_clock_gettime(void *object,
			int clockid, struct timespec *value)
{
	int res = clock_gettime(clockid, value);
	return res < 0 ? -errno : res;
}

static int impl_clock_getres(void *object,
			int clockid, struct timespec *res)
{
	int r = clock_getres(clockid, res);
	return r < 0 ? -errno : r;
}

/* poll */
static int impl_pollfd_create(void *object, int flags)
{
	struct impl *impl = object;
	int fl = 0, res;
	if (flags & SPA_FD_CLOEXEC)
		fl |= EPOLL_CLOEXEC;
	res = epoll_create1(fl);
	spa_log_debug(impl->log, NAME " %p: new fd:%d", impl, res);
	return res < 0 ? -errno : res;
}

static int impl_pollfd_add(void *object, int pfd, int fd, uint32_t events, void *data)
{
	struct epoll_event ep;
	int res;

	spa_zero(ep);
	ep.events = events;
	ep.data.ptr = data;

	res = epoll_ctl(pfd, EPOLL_CTL_ADD, fd, &ep);
	return res < 0 ? -errno : res;
}

static int impl_pollfd_mod(void *object, int pfd, int fd, uint32_t events, void *data)
{
	struct epoll_event ep;
	int res;

	spa_zero(ep);
	ep.events = events;
	ep.data.ptr = data;

	res = epoll_ctl(pfd, EPOLL_CTL_MOD, fd, &ep);
	return res < 0 ? -errno : res;
}

static int impl_pollfd_del(void *object, int pfd, int fd)
{
	int res = epoll_ctl(pfd, EPOLL_CTL_DEL, fd, NULL);
	return res < 0 ? -errno : res;
}

static int impl_pollfd_wait(void *object, int pfd,
		struct spa_poll_event *ev, int n_ev, int timeout)
{
	struct epoll_event ep[n_ev];
	int i, nfds;

	if (SPA_UNLIKELY((nfds = epoll_wait(pfd, ep, n_ev, timeout)) < 0))
		return -errno;

        for (i = 0; i < nfds; i++) {
                ev[i].events = ep[i].events;
                ev[i].data = ep[i].data.ptr;
        }
	return nfds;
}

/* timers */
static int impl_timerfd_create(void *object, int clockid, int flags)
{
	struct impl *impl = object;
	int fl = 0, res;
	if (flags & SPA_FD_CLOEXEC)
		fl |= TFD_CLOEXEC;
	if (flags & SPA_FD_NONBLOCK)
		fl |= TFD_NONBLOCK;
	res = timerfd_create(clockid, fl);
	spa_log_debug(impl->log, NAME " %p: new fd:%d", impl, res);
	return res < 0 ? -errno : res;
}

static int impl_timerfd_settime(void *object,
			int fd, int flags,
			const struct itimerspec *new_value,
			struct itimerspec *old_value)
{
	int fl = 0, res;
	if (flags & SPA_FD_TIMER_ABSTIME)
		fl |= TFD_TIMER_ABSTIME;
	if (flags & SPA_FD_TIMER_CANCEL_ON_SET)
		fl |= TFD_TIMER_CANCEL_ON_SET;
	res = timerfd_settime(fd, fl, new_value, old_value);
	return res < 0 ? -errno : res;
}

static int impl_timerfd_gettime(void *object,
			int fd, struct itimerspec *curr_value)
{
	int res = timerfd_gettime(fd, curr_value);
	return res < 0 ? -errno : res;

}
static int impl_timerfd_read(void *object, int fd, uint64_t *expirations)
{
	if (read(fd, expirations, sizeof(uint64_t)) != sizeof(uint64_t))
		return -errno;
	return 0;
}

/* events */
static int impl_eventfd_create(void *object, int flags)
{
	struct impl *impl = object;
	int fl = 0, res;
	if (flags & SPA_FD_CLOEXEC)
		fl |= EFD_CLOEXEC;
	if (flags & SPA_FD_NONBLOCK)
		fl |= EFD_NONBLOCK;
	if (flags & SPA_FD_EVENT_SEMAPHORE)
		fl |= EFD_SEMAPHORE;
	res = eventfd(0, fl);
	spa_log_debug(impl->log, NAME " %p: new fd:%d", impl, res);
	return res < 0 ? -errno : res;
}

static int impl_eventfd_write(void *object, int fd, uint64_t count)
{
	if (write(fd, &count, sizeof(uint64_t)) != sizeof(uint64_t))
		return -errno;
	return 0;
}

static int impl_eventfd_read(void *object, int fd, uint64_t *count)
{
	if (read(fd, count, sizeof(uint64_t)) != sizeof(uint64_t))
		return -errno;
	return 0;
}

/* signals */
static int impl_signalfd_create(void *object, int signal, int flags)
{
	struct impl *impl = object;
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
	spa_log_debug(impl->log, NAME " %p: new fd:%d", impl, res);

	return res < 0 ? -errno : res;
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

const struct spa_handle_factory spa_support_system_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_SUPPORT_SYSTEM,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info
};
