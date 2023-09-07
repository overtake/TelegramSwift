/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/* Copyright (C) 2010 Google Inc. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE.WEBKIT file.
 */


#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <spa/utils/defs.h>

#include <math.h>
#include "biquad.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#ifndef M_SQRT2
#define M_SQRT2 1.41421356237309504880
#endif

static void set_coefficient(struct biquad *bq, double b0, double b1, double b2,
			    double a0, double a1, double a2)
{
	double a0_inv = 1 / a0;
	bq->b0 = b0 * a0_inv;
	bq->b1 = b1 * a0_inv;
	bq->b2 = b2 * a0_inv;
	bq->a1 = a1 * a0_inv;
	bq->a2 = a2 * a0_inv;
}

static void biquad_lowpass(struct biquad *bq, double cutoff)
{
	/* Limit cutoff to 0 to 1. */
	cutoff = SPA_CLAMP(cutoff, 0.0, 1.0);

	if (cutoff >= 1.0) {
		/* When cutoff is 1, the z-transform is 1. */
		set_coefficient(bq, 1, 0, 0, 1, 0, 0);
	} else if (cutoff > 0) {
		/* Compute biquad coefficients for lowpass filter */
		double theta = M_PI * cutoff;
		double sn = 0.5 * M_SQRT2 * sin(theta);
		double beta = 0.5 * (1 - sn) / (1 + sn);
		double gamma_coeff = (0.5 + beta) * cos(theta);
		double alpha = 0.25 * (0.5 + beta - gamma_coeff);

		double b0 = 2 * alpha;
		double b1 = 2 * 2 * alpha;
		double b2 = 2 * alpha;
		double a1 = 2 * -gamma_coeff;
		double a2 = 2 * beta;

		set_coefficient(bq, b0, b1, b2, 1, a1, a2);
	} else {
		/* When cutoff is zero, nothing gets through the filter, so set
		 * coefficients up correctly.
		 */
		set_coefficient(bq, 0, 0, 0, 1, 0, 0);
	}
}

static void biquad_highpass(struct biquad *bq, double cutoff)
{
	/* Limit cutoff to 0 to 1. */
	cutoff = SPA_CLAMP(cutoff, 0.0, 1.0);

	if (cutoff >= 1.0) {
		/* The z-transform is 0. */
		set_coefficient(bq, 0, 0, 0, 1, 0, 0);
	} else if (cutoff > 0) {
		/* Compute biquad coefficients for highpass filter */
		double theta = M_PI * cutoff;
		double sn = 0.5 * M_SQRT2 * sin(theta);
		double beta = 0.5 * (1 - sn) / (1 + sn);
		double gamma_coeff = (0.5 + beta) * cos(theta);
		double alpha = 0.25 * (0.5 + beta + gamma_coeff);

		double b0 = 2 * alpha;
		double b1 = 2 * -2 * alpha;
		double b2 = 2 * alpha;
		double a1 = 2 * -gamma_coeff;
		double a2 = 2 * beta;

		set_coefficient(bq, b0, b1, b2, 1, a1, a2);
	} else {
		/* When cutoff is zero, we need to be careful because the above
		 * gives a quadratic divided by the same quadratic, with poles
		 * and zeros on the unit circle in the same place. When cutoff
		 * is zero, the z-transform is 1.
		 */
		set_coefficient(bq, 1, 0, 0, 1, 0, 0);
	}
}

void biquad_set(struct biquad *bq, enum biquad_type type, double freq)
{

	switch (type) {
	case BQ_LOWPASS:
		biquad_lowpass(bq, freq);
		break;
	case BQ_HIGHPASS:
		biquad_highpass(bq, freq);
		break;
	}
}
