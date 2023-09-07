/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef BIQUAD_H_
#define BIQUAD_H_

#ifdef __cplusplus
extern "C" {
#endif

/* The biquad filter parameters. The transfer function H(z) is (b0 + b1 * z^(-1)
 * + b2 * z^(-2)) / (1 + a1 * z^(-1) + a2 * z^(-2)).  The previous two inputs
 * are stored in x1 and x2, and the previous two outputs are stored in y1 and
 * y2.
 *
 * We use double during the coefficients calculation for better accuracy, but
 * float is used during the actual filtering for faster computation.
 */
struct biquad {
	float b0, b1, b2;
	float a1, a2;
};

/* The type of the biquad filters */
enum biquad_type {
	BQ_LOWPASS,
	BQ_HIGHPASS,
};

/* Initialize a biquad filter parameters from its type and parameters.
 * Args:
 *    bq - The biquad filter we want to set.
 *    type - The type of the biquad filter.
 *    frequency - The value should be in the range [0, 1]. It is relative to
 *        half of the sampling rate.
 */
void biquad_set(struct biquad *bq, enum biquad_type type, double freq);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* BIQUAD_H_ */
