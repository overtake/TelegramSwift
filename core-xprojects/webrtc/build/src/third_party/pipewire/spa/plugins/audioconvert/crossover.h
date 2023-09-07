/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef CROSSOVER_H_
#define CROSSOVER_H_

#include "biquad.h"
/* An LR4 filter is two biquads with the same parameters connected in series:
 *
 * x -- [BIQUAD] -- y -- [BIQUAD] -- z
 *
 * Both biquad filter has the same parameter b[012] and a[12],
 * The variable [xyz][12] keep the history values.
 */
struct lr4 {
	struct biquad bq;
	float x1, x2;
	float y1, y2;
	float z1, z2;
};

void lr4_set(struct lr4 *lr4, enum biquad_type type, float freq);

void lr4_process(struct lr4 *lr4, float *data, int samples);

#endif /* CROSSOVER_H_ */
