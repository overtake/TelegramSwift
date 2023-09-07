/* Simple Plugin API
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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <errno.h>

#include <spa/utils/result.h>
#include <spa/utils/json.h>

static int dump(FILE *file, int indent, struct spa_json *it, const char *value, int len)
{
	struct spa_json sub;
	int count = 0;

	if (spa_json_is_array(value, len)) {
		fprintf(file, "[");
		spa_json_enter(it, &sub);
		while ((len = spa_json_next(&sub, &value)) > 0) {
			fprintf(file, "%s\n%*s", count++ > 0 ? "," : "",
					indent+2, "");
			dump(file, indent+2, &sub, value, len);
		}
		fprintf(file, "%s%*s]", count > 0 ? "\n" : "",
				count > 0 ? indent : 0, "");
	} else if (spa_json_is_object(value, len)) {
		fprintf(file, "{");
		spa_json_enter(it, &sub);
		while ((len = spa_json_next(&sub, &value)) > 0) {
			char *q = spa_json_is_string(value, len) ? "" : "\"";
			fprintf(file, "%s\n%*s%s%.*s%s: ", count++ > 0 ? "," : "",
					indent+2, "", q, len, value, q);
			if ((len = spa_json_next(&sub, &value)) <= 0)
				break;
			dump(file, indent+2, &sub, value, len);
		}
		fprintf(file, "%s%*s}", count > 0 ? "\n" : "",
				count > 0 ? indent : 0, "");
	} else if (spa_json_is_string(value, len) ||
	    spa_json_is_null(value, len) ||
	    spa_json_is_bool(value, len) ||
	    spa_json_is_float(value, len)) {
		fprintf(file, "%.*s", len, value);
	} else {
		fprintf(file, "\"%.*s\"", len, value);
	}
	return 0;
}

int main(int argc, char *argv[])
{
	int fd, len, res, exit_code = EXIT_FAILURE;
	void *data;
	struct stat sbuf;
	struct spa_json it;
	const char *value;

	if (argc < 2) {
		fprintf(stderr, "usage: %s <spa-json-file>\n", argv[0]);
		goto error;
	}
	if ((fd = open(argv[1],  O_CLOEXEC | O_RDONLY)) < 0)  {
                fprintf(stderr, "error opening file '%s': %m\n", argv[1]);
		goto error;
        }
        if (fstat(fd, &sbuf) < 0) {
                fprintf(stderr, "error statting file '%s': %m\n", argv[1]);
                goto error_close;
	}
        if ((data = mmap(NULL, sbuf.st_size, PROT_READ, MAP_PRIVATE, fd, 0)) == MAP_FAILED) {
                fprintf(stderr, "error mmapping file '%s': %m\n", argv[1]);
                goto error_close;
	}

	spa_json_init(&it, data, sbuf.st_size);
	if ((len = spa_json_next(&it, &value)) <= 0) {
                fprintf(stderr, "not a valid file '%s': %s\n", argv[1], spa_strerror(len));
		goto error_unmap;
	}
	if (!spa_json_is_container(value, len)) {
		spa_json_init(&it, data, sbuf.st_size);
		value = "{";
		len = 1;
	}
	if ((res = dump(stdout, 0, &it, value, len)) < 0) {
                fprintf(stderr, "error parsing file '%s': %s\n", argv[1], spa_strerror(res));
		goto error_unmap;
	}
	fprintf(stdout, "\n");
	exit_code = EXIT_SUCCESS;

error_unmap:
        munmap(data, sbuf.st_size);
error_close:
        close(fd);
error:
	return exit_code;
}
