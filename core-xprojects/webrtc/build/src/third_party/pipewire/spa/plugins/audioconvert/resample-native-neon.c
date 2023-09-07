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

#include "resample-native-impl.h"

#include <arm_neon.h>

static void inner_product_neon(float *d, const float * SPA_RESTRICT s,
		const float * SPA_RESTRICT taps, uint32_t n_taps)
{
	unsigned int remainder = n_taps % 16;
	n_taps = n_taps - remainder;

#ifdef __aarch64__
	asm volatile(
		"      cmp %[n_taps], #0\n"
		"      bne 1f\n"
		"      ld1 {v4.4s}, [%[taps]], #16\n"
		"      ld1 {v8.4s}, [%[s]], #16\n"
		"      subs %[remainder], %[remainder], #4\n"
		"      fmul v0.4s, v4.4s, v8.4s\n"
		"      bne 4f\n"
		"      b 5f\n"
		"1:"
		"      ld1 {v4.4s,  v5.4s, v6.4s,  v7.4s}, [%[taps]], #64\n"
		"      ld1 {v8.4s,  v9.4s, v10.4s, v11.4s}, [%[s]], #64\n"
		"      subs %[n_taps], %[n_taps], #16\n"
		"      fmul v0.4s, v4.4s, v8.4s\n"
		"      fmul v1.4s, v5.4s, v9.4s\n"
		"      fmul v2.4s, v6.4s, v10.4s\n"
		"      fmul v3.4s, v7.4s, v11.4s\n"
		"      beq 3f\n"
		"2:"
		"      ld1 {v4.4s,  v5.4s, v6.4s,  v7.4s}, [%[taps]], #64\n"
		"      ld1 {v8.4s,  v9.4s, v10.4s, v11.4s}, [%[s]], #64\n"
		"      subs %[n_taps], %[n_taps], #16\n"
		"      fmla v0.4s, v4.4s, v8.4s\n"
		"      fmla v1.4s, v5.4s, v9.4s\n"
		"      fmla v2.4s, v6.4s, v10.4s\n"
		"      fmla v3.4s, v7.4s, v11.4s\n"
		"      bne 2b\n"
		"3:"
		"      fadd v4.4s, v0.4s, v1.4s\n"
		"      fadd v5.4s, v2.4s, v3.4s\n"
		"      cmp %[remainder], #0\n"
		"      fadd v0.4s, v4.4s, v5.4s\n"
		"      beq 5f\n"
		"4:"
		"      ld1 {v6.4s}, [%[taps]], #16\n"
		"      ld1 {v10.4s}, [%[s]], #16\n"
		"      subs %[remainder], %[remainder], #4\n"
		"      fmla v0.4s, v6.4s, v10.4s\n"
		"      bne 4b\n"
		"5:"
		"      faddp v0.4s, v0.4s, v0.4s\n"
		"      faddp v0.2s, v0.2s, v0.2s\n"
		"      str s0, [%[d]]\n"
		: [d] "+r" (d), [s] "+r" (s), [taps] "+r" (taps),
		  [n_taps] "+r" (n_taps), [remainder] "+r" (remainder)
		:
		: "cc", "v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8",
		  "v9", "v10", "v11");
#else
	asm volatile (
		"      cmp %[n_taps], #0\n"
		"      bne 1f\n"
		"      vld1.32 {q4}, [%[taps] :128]!\n"
		"      vld1.32 {q8}, [%[s]]!\n"
		"      subs %[remainder], %[remainder], #4\n"
		"      vmul.f32 q0, q4, q8\n"
		"      bne 4f\n"
		"      b 5f\n"
		"1:"
		"      vld1.32 {q4, q5}, [%[taps] :128]!\n"
		"      vld1.32 {q8, q9}, [%[s]]!\n"
		"      vld1.32 {q6, q7}, [%[taps] :128]!\n"
		"      vld1.32 {q10, q11}, [%[s]]!\n"
		"      subs %[n_taps], %[n_taps], #16\n"
		"      vmul.f32 q0, q4, q8\n"
		"      vmul.f32 q1, q5, q9\n"
		"      vmul.f32 q2, q6, q10\n"
		"      vmul.f32 q3, q7, q11\n"
		"      beq 3f\n"
		"2:"
		"      vld1.32 {q4, q5}, [%[taps] :128]!\n"
		"      vld1.32 {q8, q9}, [%[s]]!\n"
		"      vld1.32 {q6, q7}, [%[taps] :128]!\n"
		"      vld1.32 {q10, q11}, [%[s]]!\n"
		"      subs %[n_taps], %[n_taps], #16\n"
		"      vmla.f32 q0, q4, q8\n"
		"      vmla.f32 q1, q5, q9\n"
		"      vmla.f32 q2, q6, q10\n"
		"      vmla.f32 q3, q7, q11\n"
		"      bne 2b\n"
		"3:"
		"      vadd.f32 q4, q0, q1\n"
		"      vadd.f32 q5, q2, q3\n"
		"      cmp %[remainder], #0\n"
		"      vadd.f32 q0, q4, q5\n"
		"      beq 5f\n"
		"4:"
		"      vld1.32 {q6}, [%[taps] :128]!\n"
		"      vld1.32 {q10}, [%[s]]!\n"
		"      subs %[remainder], %[remainder], #4\n"
		"      vmla.f32 q0, q6, q10\n"
		"      bne 4b\n"
		"5:"
		"      vadd.f32 d0, d0, d1\n"
		"      vpadd.f32 d0, d0, d0\n"
		"      vstr d0, [%[d]]\n"
		: [d] "+r" (d), [s] "+r" (s), [taps] "+r" (taps),
		  [n_taps] "+l" (n_taps), [remainder] "+l" (remainder)
		:
		: "cc", "q0", "q1", "q2", "q3", "q4", "q5", "q6", "q7", "q8",
		  "q9", "q10", "q11");
#endif
}

static void inner_product_ip_neon(float *d, const float * SPA_RESTRICT s,
	const float * SPA_RESTRICT t0, const float * SPA_RESTRICT t1, float x,
	uint32_t n_taps)
{
#ifdef __aarch64__
	asm volatile(
		"      dup v10.4s, %w[x]\n"
		"      ld1 {v4.4s, v5.4s}, [%[t0]], #32\n"
		"      ld1 {v8.4s, v9.4s}, [%[s]], #32\n"
		"      ld1 {v6.4s, v7.4s}, [%[t1]], #32\n"
		"      subs %[n_taps], %[n_taps], #8\n"
		"      fmul v0.4s, v4.4s, v8.4s\n"
		"      fmul v1.4s, v5.4s, v9.4s\n"
		"      fmul v2.4s, v6.4s, v8.4s\n"
		"      fmul v3.4s, v7.4s, v9.4s\n"
		"      beq 3f\n"
		"2:"
		"      ld1 {v4.4s, v5.4s}, [%[t0]], #32\n"
		"      ld1 {v8.4s, v9.4s}, [%[s]], #32\n"
		"      ld1 {v6.4s, v7.4s}, [%[t1]], #32\n"
		"      subs %[n_taps], %[n_taps], #8\n"
		"      fmla v0.4s, v4.4s, v8.4s\n"
		"      fmla v1.4s, v5.4s, v9.4s\n"
		"      fmla v2.4s, v6.4s, v8.4s\n"
		"      fmla v3.4s, v7.4s, v9.4s\n"
		"      bne 2b\n"
		"3:"
		"      fadd v0.4s, v0.4s, v1.4s\n"	/* sum[0] */
		"      fadd v2.4s, v2.4s, v3.4s\n"	/* sum[1] */
		"      fsub v2.4s, v2.4s, v0.4s\n"	/* sum[1] -= sum[0] */
		"      fmla v0.4s, v2.4s, v10.4s\n"	/* sum[0] += sum[1] * x */
		"      faddp v0.4s, v0.4s, v0.4s\n"
		"      faddp v0.2s, v0.2s, v0.2s\n"
		"      str s0, [%[d]]\n"
		: [d] "+r" (d), [s] "+r" (s), [t0] "+r" (t0), [t1] "+r" (t1),
		  [n_taps] "+r" (n_taps), [x] "+r" (x)
		:
		: "cc", "v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8",
		  "v9", "v10");
#else
	asm volatile(
		"      vdup.32 q10, %[x]\n"
		"      vld1.32 {q4, q5}, [%[t0] :128]!\n"
		"      vld1.32 {q8, q9}, [%[s]]!\n"
		"      vld1.32 {q6, q7}, [%[t1] :128]!\n"
		"      subs %[n_taps], %[n_taps], #8\n"
		"      vmul.f32 q0, q4, q8\n"
		"      vmul.f32 q1, q5, q9\n"
		"      vmul.f32 q2, q6, q8\n"
		"      vmul.f32 q3, q7, q9\n"
		"      beq 3f\n"
		"2:"
		"      vld1.32 {q4, q5}, [%[t0] :128]!\n"
		"      vld1.32 {q8, q9}, [%[s]]!\n"
		"      vld1.32 {q6, q7}, [%[t1] :128]!\n"
		"      subs %[n_taps], %[n_taps], #8\n"
		"      vmla.f32 q0, q4, q8\n"
		"      vmla.f32 q1, q5, q9\n"
		"      vmla.f32 q2, q6, q8\n"
		"      vmla.f32 q3, q7, q9\n"
		"      bne 2b\n"
		"3:"
		"      vadd.f32 q0, q0, q1\n"		/* sum[0] */
		"      vadd.f32 q2, q2, q3\n"		/* sum[1] */
		"      vsub.f32 q2, q2, q0\n"		/* sum[1] -= sum[0] */
		"      vmla.f32 q0, q2, q10\n"		/* sum[0] += sum[1] * x */
		"      vadd.f32 d0, d0, d1\n"
		"      vpadd.f32 d0, d0, d0\n"
		"      vstr d0, [%[d]]\n"
		: [d] "+r" (d), [s] "+r" (s), [t0] "+r" (t0), [t1] "+r" (t1),
		  [n_taps] "+l" (n_taps), [x] "+l" (x)
		:
		: "cc", "q0", "q1", "q2", "q3", "q4", "q5", "q6", "q7", "q8",
		  "q9", "q10");
#endif
}

MAKE_RESAMPLER_FULL(neon);
MAKE_RESAMPLER_INTER(neon);
