/* Spa
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

#include <stddef.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <sched.h>
#include <fcntl.h>

#ifdef __FreeBSD__
#include <sys/sysctl.h>
#endif

#include <spa/support/log.h>
#include <spa/support/cpu.h>
#include <spa/support/plugin.h>
#include <spa/utils/type.h>
#include <spa/utils/hook.h>
#include <spa/utils/names.h>

#define NAME "cpu"

struct impl {
	struct spa_handle handle;
	struct spa_cpu cpu;

	struct spa_log *log;

	uint32_t flags;
	uint32_t force;
	uint32_t count;
	uint32_t max_align;
	uint32_t vm_type;
};

static char *read_file(const char *name, char *buffer, size_t len)
{
	int n, fd;

	if ((fd = open(name, O_RDONLY | O_CLOEXEC, 0)) < 0)
		return NULL;

	if ((n = read(fd, buffer, len-1)) < 0) {
		close(fd);
		return NULL;
	}
	buffer[n] = '\0';
	close(fd);
	return buffer;
}

# if defined (__i386__) || defined (__x86_64__)
#include "cpu-x86.c"
#define init(t)	x86_init(t)
# elif defined (__arm__) || defined (__aarch64__)
#include "cpu-arm.c"
#define init(t)	arm_init(t)
# else
#define init(t)
#endif

static uint32_t
impl_cpu_get_flags(void *object)
{
	struct impl *impl = object;
	if (impl->force != SPA_CPU_FORCE_AUTODETECT)
		return impl->force;
	return impl->flags;
}

static int
impl_cpu_force_flags(void *object, uint32_t flags)
{
	struct impl *impl = object;
	impl->force = flags;
	return 0;
}

#ifndef __FreeBSD__
static uint32_t get_count(struct impl *this)
{
	cpu_set_t cpuset;
	CPU_ZERO(&cpuset);
	if (sched_getaffinity(0, sizeof(cpuset), &cpuset) == 0)
		return CPU_COUNT(&cpuset);
	return 1;
}
#else
static uint32_t get_count(struct impl *this)
{
	int mib[] = {CTL_HW, HW_NCPU};
	int r;
	size_t rSize = sizeof(r);
	if(-1 == sysctl(mib, 2, &r, &rSize, 0, 0))
		return 1;
	return r;
}
#endif

static uint32_t
impl_cpu_get_count(void *object)
{
	struct impl *impl = object;
	return impl->count;
}

static uint32_t
impl_cpu_get_max_align(void *object)
{
	struct impl *impl = object;
	return impl->max_align;
}

static uint32_t
impl_cpu_get_vm_type(void *object)
{
	struct impl *impl = object;

	if (impl->vm_type != 0)
		return impl->vm_type;

#if defined(__i386__) || defined(__x86_64__) || defined(__arm__) || defined(__aarch64__)
	static const char *const dmi_vendors[] = {
		"/sys/class/dmi/id/product_name", /* Test this before sys_vendor to detect KVM over QEMU */
		"/sys/class/dmi/id/sys_vendor",
		"/sys/class/dmi/id/board_vendor",
		"/sys/class/dmi/id/bios_vendor"
	};
	static const struct {
		const char *vendor;
		int id;
	} dmi_vendor_table[] = {
		{ "KVM",		SPA_CPU_VM_KVM },
		{ "QEMU",		SPA_CPU_VM_QEMU },
		{ "VMware",		SPA_CPU_VM_VMWARE }, /* https://kb.vmware.com/s/article/1009458 */
		{ "VMW",                SPA_CPU_VM_VMWARE },
		{ "innotek GmbH",	SPA_CPU_VM_ORACLE },
		{ "Oracle Corporation",	SPA_CPU_VM_ORACLE },
		{ "Xen",		SPA_CPU_VM_XEN },
		{ "Bochs",		SPA_CPU_VM_BOCHS },
		{ "Parallels",		SPA_CPU_VM_PARALLELS },
		/* https://wiki.freebsd.org/bhyve */
		{ "BHYVE",		SPA_CPU_VM_BHYVE },
        };
	uint32_t i, j;

	for (i = 0; i < SPA_N_ELEMENTS(dmi_vendors); i++) {
		char buffer[256], *s;

		if ((s = read_file(dmi_vendors[i], buffer, sizeof(buffer))) == NULL)
			continue;

		for (j = 0; j < SPA_N_ELEMENTS(dmi_vendor_table); j++) {
			if (strstr(s, dmi_vendor_table[j].vendor) == s) {
				spa_log_debug(impl->log, "Virtualization %s found in DMI (%s)",
						s, dmi_vendors[i]);
				impl->vm_type = dmi_vendor_table[j].id;
				goto done;
                        }
		}
	}
done:
#endif
	return impl->vm_type;
}

static const struct spa_cpu_methods impl_cpu = {
	SPA_VERSION_CPU_METHODS,
	.get_flags = impl_cpu_get_flags,
	.force_flags = impl_cpu_force_flags,
	.get_count = impl_cpu_get_count,
	.get_max_align = impl_cpu_get_max_align,
	.get_vm_type = impl_cpu_get_vm_type,
};

static int impl_get_interface(struct spa_handle *handle, const char *type, void **interface)
{
	struct impl *this;

	spa_return_val_if_fail(handle != NULL, -EINVAL);
	spa_return_val_if_fail(interface != NULL, -EINVAL);

	this = (struct impl *) handle;

	if (strcmp(type, SPA_TYPE_INTERFACE_CPU) == 0)
		*interface = &this->cpu;
	else
		return -ENOENT;

	return 0;
}

static int impl_clear(struct spa_handle *handle)
{
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
	struct impl *this;
	const char *str;

	spa_return_val_if_fail(factory != NULL, -EINVAL);
	spa_return_val_if_fail(handle != NULL, -EINVAL);

	handle->get_interface = impl_get_interface;
	handle->clear = impl_clear;

	this = (struct impl *) handle;

	this->cpu.iface = SPA_INTERFACE_INIT(
			SPA_TYPE_INTERFACE_CPU,
			SPA_VERSION_CPU,
			&impl_cpu, this);

	this->log = spa_support_find(support, n_support, SPA_TYPE_INTERFACE_Log);

	this->flags = 0;
	this->force = SPA_CPU_FORCE_AUTODETECT;
	this->max_align = 16;
	this->count = get_count(this);
	init(this);

	if (info) {
		if ((str = spa_dict_lookup(info, SPA_KEY_CPU_FORCE)) != NULL)
			this->flags = atoi(str);
		if ((str = spa_dict_lookup(info, SPA_KEY_CPU_VM_TYPE)) != NULL)
			this->vm_type = atoi(str);
	}

	spa_log_debug(this->log, NAME " %p: count:%d align:%d flags:%08x",
			this, this->count, this->max_align, this->flags);

	return 0;
}

static const struct spa_interface_info impl_interfaces[] = {
	{SPA_TYPE_INTERFACE_CPU,},
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

const struct spa_handle_factory spa_support_cpu_factory = {
	SPA_VERSION_HANDLE_FACTORY,
	SPA_NAME_SUPPORT_CPU,
	NULL,
	impl_get_size,
	impl_init,
	impl_enum_interface_info,
};
