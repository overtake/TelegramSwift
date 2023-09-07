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

#include <stdio.h>
#include <stdbool.h>
#include <limits.h>
#include <math.h>
#include <sys/timerfd.h>

#include <alsa/asoundlib.h>

#include <dll.h>

#define DEFAULT_DEVICE	"hw:0"

#define M_PI_M2 (M_PI + M_PI)

#define NSEC_PER_SEC	1000000000ll
#define TIMESPEC_TO_NSEC(ts) ((ts)->tv_sec * NSEC_PER_SEC + (ts)->tv_nsec)

#define BW_PERIOD	(NSEC_PER_SEC * 3)

struct state {
	unsigned int rate;
	unsigned int channels;
	snd_pcm_uframes_t period;

	snd_pcm_t *hndl;
	int timerfd;

	float accumulator;

	uint64_t next_time;
	uint64_t prev_time;

	struct spa_dll dll;
};

static int set_timeout(struct state *state, uint64_t time)
{
	struct itimerspec ts;
	ts.it_value.tv_sec = time / NSEC_PER_SEC;
	ts.it_value.tv_nsec = time % NSEC_PER_SEC;
	ts.it_interval.tv_sec = 0;
	ts.it_interval.tv_nsec = 0;
	return timerfd_settime(state->timerfd, TFD_TIMER_ABSTIME, &ts, NULL);
}

#define CHECK(s,msg,...) {		\
	int __err;			\
	if ((__err = (s)) < 0) {	\
		fprintf(stderr, msg ": %s\n", ##__VA_ARGS__, snd_strerror(__err));	\
		return __err;		\
	}				\
}

static int write_period(struct state *state)
{
	snd_pcm_uframes_t frames = state->period;
	snd_pcm_uframes_t offset;
	const snd_pcm_channel_area_t* areas;
	uint32_t i, j;
	int32_t *samples, v;

	snd_pcm_mmap_begin(state->hndl, &areas, &offset, &frames);

	samples = (int32_t*)((uint8_t*)areas[0].addr + (areas[0].first + offset*areas[0].step) / 8);

	for (i = 0; i < frames; i++) {
		state->accumulator += M_PI_M2 * 440 / state->rate;
		if (state->accumulator >= M_PI_M2)
			state->accumulator -= M_PI_M2;
		v = sin(state->accumulator) * 0x7fffffff;

		for (j = 0; j < state->channels; j++)
			*samples++ = v;
	}
	snd_pcm_mmap_commit(state->hndl, offset, frames) ;

	return 0;
}

static int on_timer_wakeup(struct state *state)
{
	snd_pcm_sframes_t avail, delay;
	double error, corr;

	/* check the delay in the device */
	CHECK(snd_pcm_avail_delay(state->hndl, &avail, &delay), "delay");

	/* calculate the error, we want to have exactly 1 period of
	 * samples remaining in the device when we wakeup. */
	error = (double)delay - (double)state->period;

	/* update the dll with the error, this gives a rate correction */
	corr = spa_dll_update(&state->dll, error);

	/* set our new adjusted timeout. alternatively, this value can
	 * instead be used to drive a resampler if this device is
	 * slaved. */
	state->next_time += state->period / corr * 1e9 / state->rate;
	set_timeout(state, state->next_time);

	if (state->next_time - state->prev_time > BW_PERIOD) {
		state->prev_time = state->next_time;

		/* reduce bandwidth and show some stats */
		if (state->dll.bw > SPA_DLL_BW_MIN)
			spa_dll_set_bw(&state->dll, state->dll.bw / 2.0,
					state->period, state->rate);

		fprintf(stdout, "corr:%f error:%f bw:%f\n",
				corr, error, state->dll.bw);
	}
	/* pull in new samples write a new period */
	write_period(state);

	return 0;
}

int main(int argc, char *argv[])
{
	struct state state = { 0, };
	const char *device = DEFAULT_DEVICE;
	snd_pcm_hw_params_t *hparams;
	struct timespec now;

	CHECK(snd_pcm_open(&state.hndl, device, SND_PCM_STREAM_PLAYBACK, 0), "open %s failed", device);

	state.rate = 44100;
	state.channels = 2;
	state.period = 1024;

	/* hw params */
	snd_pcm_hw_params_alloca(&hparams);
	snd_pcm_hw_params_any(state.hndl, hparams);
	CHECK(snd_pcm_hw_params_set_access(state.hndl, hparams,
				SND_PCM_ACCESS_MMAP_INTERLEAVED), "set interleaved");
	CHECK(snd_pcm_hw_params_set_format(state.hndl, hparams,
				SND_PCM_FORMAT_S32_LE), "set format");
	CHECK(snd_pcm_hw_params_set_channels_near(state.hndl, hparams,
				&state.channels), "set channels");
	CHECK(snd_pcm_hw_params_set_rate_near(state.hndl, hparams,
				&state.rate, 0), "set rate");
	CHECK(snd_pcm_hw_params(state.hndl, hparams), "hw_params");

	fprintf(stdout, "opened format:%s rate:%u channels:%u\n",
			snd_pcm_format_name(SND_PCM_FORMAT_S32_LE),
			state.rate, state.channels);

	spa_dll_init(&state.dll);
	spa_dll_set_bw(&state.dll, SPA_DLL_BW_MAX, state.period, state.rate);

	if ((state.timerfd = timerfd_create(CLOCK_MONOTONIC, 0)) < 0)
		perror("timerfd");

	CHECK(snd_pcm_prepare(state.hndl), "prepare");

	/* before we start, write one period */
	write_period(&state);

	/* set our first timeout for now */
	clock_gettime(CLOCK_MONOTONIC, &now);
	state.prev_time = state.next_time = TIMESPEC_TO_NSEC(&now);
	set_timeout(&state, state.next_time);

	/* and start playback */
	CHECK(snd_pcm_start(state.hndl), "start");

	/* wait for timer to expire and call the wakeup function,
	 * this can be done in a poll loop as well */
	while (true) {
		uint64_t expirations;
		CHECK(read(state.timerfd, &expirations, sizeof(expirations)), "read");
		on_timer_wakeup(&state);
	}

	snd_pcm_drain(state.hndl);
	snd_pcm_close(state.hndl);
	close(state.timerfd);

	return EXIT_SUCCESS;
}
