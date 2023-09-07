/* PipeWire
 *
 * Copyright © 2020 Wim Taymans
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

#include <stdio.h>

#include <spa/utils/defs.h>

struct midi_file;

struct midi_event {
	uint32_t track;
	double sec;
	uint8_t *data;
	uint32_t size;
	struct {
		uint32_t offset;
		uint32_t size;
		union {
			struct {
				uint32_t uspqn; /* microseconds per quarter note */
			} tempo;
		} parsed;
	} meta;
};

struct midi_file_info {
	uint16_t format;
	uint16_t ntracks;
	uint16_t division;
};

struct midi_file *
midi_file_open(const char *filename, const char *mode, struct midi_file_info *info);

int midi_file_close(struct midi_file *mf);

int midi_file_next_time(struct midi_file *mf, double *sec);

int midi_file_read_event(struct midi_file *mf, struct midi_event *event);

int midi_file_write_event(struct midi_file *mf, const struct midi_event *event);

int midi_file_dump_event(FILE *out, const struct midi_event *event);
