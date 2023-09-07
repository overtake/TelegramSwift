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

#ifndef RESAMPLE_H
#define RESAMPLE_H

#include <spa/support/cpu.h>
#include <spa/support/log.h>

#define RESAMPLE_DEFAULT_QUALITY	4

struct resample {
	uint32_t cpu_flags;
	uint32_t channels;
	uint32_t i_rate;
	uint32_t o_rate;
	struct spa_log *log;
	double rate;
	int quality;

	void (*free)		(struct resample *r);
	void (*update_rate)	(struct resample *r, double rate);
	uint32_t (*in_len)	(struct resample *r, uint32_t out_len);
	uint32_t (*out_len)	(struct resample *r, uint32_t in_len);
	void (*process)		(struct resample *r,
				 const void * SPA_RESTRICT src[], uint32_t *in_len,
				 void * SPA_RESTRICT dst[], uint32_t *out_len);
	void (*reset)		(struct resample *r);
	uint32_t (*delay)	(struct resample *r);
	void *data;
};

#define resample_free(r)		(r)->free(r)
#define resample_update_rate(r,...)	(r)->update_rate(r,__VA_ARGS__)
#define resample_in_len(r,...)		(r)->in_len(r,__VA_ARGS__)
#define resample_out_len(r,...)		(r)->out_len(r,__VA_ARGS__)
#define resample_process(r,...)		(r)->process(r,__VA_ARGS__)
#define resample_reset(r)		(r)->reset(r)
#define resample_delay(r)		(r)->delay(r)

int resample_native_init(struct resample *r);
int resample_peaks_init(struct resample *r);

#endif /* RESAMPLE_H */
