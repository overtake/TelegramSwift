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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define MAX_BUFFER 4096

static char *get_cpuinfo_line(char *cpuinfo, const char *tag)
{
	char *line, *end, *colon;

	if (!(line = strstr(cpuinfo, tag)))
		return NULL;

	if (!(end = strchr(line, '\n')))
		return NULL;

	if (!(colon = strchr(line, ':')))
		return NULL;

	if (++colon >= end)
		return NULL;

	return strndup(colon, end - colon);
}

static char *get_cpuinfo(void)
{
	char *cpuinfo;
	int n, fd;

	cpuinfo = malloc(MAX_BUFFER);

	if ((fd = open("/proc/cpuinfo", O_RDONLY | O_CLOEXEC, 0)) < 0) {
		free(cpuinfo);
		return NULL;
	}

	if ((n = read(fd, cpuinfo, MAX_BUFFER-1)) < 0) {
		free(cpuinfo);
		close(fd);
		return NULL;
	}
	cpuinfo[n] = 0;
	close(fd);

	return cpuinfo;
}

static int
arm_init(struct impl *impl)
{
	uint32_t flags = 0;
	char *cpuinfo, *line;
	int arch;

	if (!(cpuinfo = get_cpuinfo())) {
		spa_log_warn(impl->log, NAME " %p: Can't read cpuinfo", impl);
		return 1;
	}

	if ((line = get_cpuinfo_line(cpuinfo, "CPU architecture"))) {
		arch = strtoul(line, NULL, 0);
		if (arch >= 6)
			flags |= SPA_CPU_FLAG_ARMV6;
		if (arch >= 8)
			flags |= SPA_CPU_FLAG_ARMV8;

		free(line);
	}

	if ((line = get_cpuinfo_line(cpuinfo, "Features"))) {
		char *state = NULL;
		char *current = strtok_r(line, " ", &state);

		do {
#if defined (__aarch64__)
			if (!strcmp(current, "asimd"))
				flags |= SPA_CPU_FLAG_NEON;
			else if (!strcmp(current, "fp"))
				flags |= SPA_CPU_FLAG_VFPV3 | SPA_CPU_FLAG_VFP;
#else
			if (!strcmp(current, "vfp"))
				flags |= SPA_CPU_FLAG_VFP;
			else if (!strcmp(current, "neon"))
				flags |= SPA_CPU_FLAG_NEON;
			else if (!strcmp(current, "vfpv3"))
				flags |= SPA_CPU_FLAG_VFPV3;
#endif
		} while ((current = strtok_r(NULL, " ", &state)));

		free(line);
	}

	free(cpuinfo);

	impl->flags = flags;

	return 0;
}
