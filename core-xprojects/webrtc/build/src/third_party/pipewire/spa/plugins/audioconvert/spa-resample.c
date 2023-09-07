/* Spa
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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <getopt.h>

#include <spa/support/log-impl.h>
#include <spa/debug/mem.h>

#include <sndfile.h>

SPA_LOG_IMPL(logger);

#include "resample.h"

#define DEFAULT_QUALITY	RESAMPLE_DEFAULT_QUALITY

#define MAX_SAMPLES	4096u

struct data {
	bool verbose;
	int rate;
	int format;
	int quality;

	const char *iname;
	SF_INFO iinfo;
	SNDFILE *ifile;

	const char *oname;
	SF_INFO oinfo;
	SNDFILE *ofile;
};

#define STR_FMTS "(s8|s16|s32|f32|f64)"

#define OPTIONS		"hvr:f:q:"
static const struct option long_options[] = {
	{ "help",	no_argument,		NULL, 'h'},
	{ "verbose",	no_argument,		NULL, 'v'},

	{ "rate",	required_argument,	NULL, 'r' },
	{ "format",	required_argument,	NULL, 'f' },
	{ "quality",	required_argument,	NULL, 'q' },

        { NULL, 0, NULL, 0 }
};

static void show_usage(const char *name, bool is_error)
{
	FILE *fp;

	fp = is_error ? stderr : stdout;

	fprintf(fp, "%s [options] <infile> <outfile>\n", name);
	fprintf(fp,
		"  -h, --help                            Show this help\n"
		"  -v  --verbose                         Be verbose\n"
		"\n");
	fprintf(fp,
		"  -r  --rate                            Output sample rate (default as input)\n"
		"  -f  --format                          Output sample format %s (default as input)\n"
		"  -q  --quality                         Resampler quality (default %u)\n"
		"\n",
		STR_FMTS, DEFAULT_QUALITY);
}

static inline int
sf_str_to_fmt(const char *str)
{
	if (!str)
		return -1;
	if (!strcmp(str, "s8"))
		return SF_FORMAT_PCM_S8;
	if (!strcmp(str, "s16"))
		return SF_FORMAT_PCM_16;
	if (!strcmp(str, "s24"))
		return SF_FORMAT_PCM_24;
	if (!strcmp(str, "s32"))
		return SF_FORMAT_PCM_32;
	if (!strcmp(str, "f32"))
		return SF_FORMAT_FLOAT;
	if (!strcmp(str, "f64"))
		return SF_FORMAT_DOUBLE;
	return -1;
}

static int open_files(struct data *d)
{
	d->ifile = sf_open(d->iname, SFM_READ, &d->iinfo);
        if (d->ifile == NULL) {
		fprintf(stderr, "error: failed to open input file \"%s\": %s\n",
				d->iname, sf_strerror(NULL));
		return -EIO;
	}

	d->oinfo.channels = d->iinfo.channels;
	d->oinfo.samplerate = d->rate > 0 ? d->rate : d->iinfo.samplerate;
	d->oinfo.format = d->format > 0 ? d->format : d->iinfo.format;
	d->oinfo.format |= SF_FORMAT_WAV;

	d->ofile = sf_open(d->oname, SFM_WRITE, &d->oinfo);
        if (d->ofile == NULL) {
		fprintf(stderr, "error: failed to open output file \"%s\": %s\n",
				d->oname, sf_strerror(NULL));
		return -EIO;
	}
	return 0;
}

static int close_files(struct data *d)
{
	if (d->ifile)
		sf_close(d->ifile);
	if (d->ofile)
		sf_close(d->ofile);
	return 0;
}

static int do_conversion(struct data *d)
{
	struct resample r;
	int channels = d->iinfo.channels;
	float in[MAX_SAMPLES * channels];
	float out[MAX_SAMPLES * channels];
	float ibuf[MAX_SAMPLES * channels];
	float obuf[MAX_SAMPLES * channels];
	uint32_t in_len, out_len;
        uint32_t pin_len, pout_len;
	const void *src[channels];
	void *dst[channels];
	uint32_t i;
	int j, k, queued;
	bool flushing = false;

	spa_zero(r);
	r.log = &logger.log;
	r.channels = channels;
	r.i_rate = d->iinfo.samplerate;
	r.o_rate = d->oinfo.samplerate;
	r.quality = d->quality < 0 ? DEFAULT_QUALITY : d->quality;
	resample_native_init(&r);

	for (j = 0; j < channels; j++)
		src[j] = &in[MAX_SAMPLES * j];
	for (j = 0; j < channels; j++)
		dst[j] = &out[MAX_SAMPLES * j];

	queued = 0;
	while (true) {
		pout_len = out_len = MAX_SAMPLES;
                in_len = SPA_MIN(MAX_SAMPLES, resample_in_len(&r, out_len)) - queued;

	        pin_len = in_len = sf_readf_float(d->ifile, &ibuf[queued * channels], in_len);
		if (pin_len == 0) {
			if (flushing)
				break;

			flushing = true;
			pin_len = in_len = resample_delay(&r);

			for (k = 0, i = 0; i < pin_len; i++) {
				for (j = 0; j < channels; j++)
					ibuf[k++] = 0.0;
			}
		}

		in_len += queued;
		pin_len = in_len;

		for (k = 0, i = 0; i < pin_len; i++) {
			for (j = 0; j < channels; j++) {
				in[MAX_SAMPLES * j + i] = ibuf[k++];
			}
		}
                resample_process(&r, src, &pin_len, dst, &pout_len);

		queued = in_len - pin_len;
		if (queued)
			memmove(ibuf, &ibuf[pin_len * channels], queued * channels * sizeof(float));

		for (k = 0, i = 0; i < pout_len; i++) {
			for (j = 0; j < channels; j++) {
				obuf[k++] = out[MAX_SAMPLES * j + i];
			}
		}
		pout_len = sf_writef_float(d->ofile, obuf, pout_len);
	}
	return 0;
}

int main(int argc, char *argv[])
{
	int c;
	int longopt_index = 0, ret;
	struct data data;

	spa_zero(data);

	logger.log.level = SPA_LOG_LEVEL_DEBUG;

	data.quality = -1;
	while ((c = getopt_long(argc, argv, OPTIONS, long_options, &longopt_index)) != -1) {
		switch (c) {
		case 'h':
                        show_usage(argv[0], false);
                        return EXIT_SUCCESS;
		case 'v':
			data.verbose = true;
			break;
		case 'r':
			ret = atoi(optarg);
			if (ret <= 0) {
				fprintf(stderr, "error: bad rate %s\n", optarg);
                                goto error_usage;
			}
			data.rate = ret;
			break;
		case 'f':
			ret = sf_str_to_fmt(optarg);
			if (ret < 0) {
				fprintf(stderr, "error: bad format %s\n", optarg);
                                goto error_usage;
			}
			data.format = ret;
			break;
		case 'q':
			ret = atoi(optarg);
			if (ret < 0) {
				fprintf(stderr, "error: bad quality %s\n", optarg);
                                goto error_usage;
			}
			data.quality = ret;
			break;
                default:
			fprintf(stderr, "error: unknown option '%c'\n", c);
			goto error_usage;
		}
	}
	if (optind + 1 >= argc) {
                fprintf(stderr, "error: filename arguments missing (%d %d)\n", optind, argc);
		goto error_usage;
	}
        data.iname = argv[optind++];
        data.oname = argv[optind++];

	if (open_files(&data) < 0)
		return EXIT_FAILURE;

	do_conversion(&data);

	close_files(&data);

	return 0;

error_usage:
        show_usage(argv[0], true);
	return EXIT_FAILURE;
}
