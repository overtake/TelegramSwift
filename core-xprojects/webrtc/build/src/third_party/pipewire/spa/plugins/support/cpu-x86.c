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

#include <cpuid.h>

static int
x86_init(struct impl *impl)
{
	uint32_t flags;

	unsigned int vendor;
	unsigned int model, family;
	unsigned int max_level, ext_level, has_osxsave;
	unsigned int eax, ebx, ecx, edx;


	max_level = __get_cpuid_max(0, &vendor);
	if (max_level < 1)
		return 0;

	__cpuid(1, eax, ebx, ecx, edx);

	model = (eax >> 4) & 0x0f;
	family = (eax >> 8) & 0x0f;

	if (vendor == signature_INTEL_ebx ||
	    vendor == signature_AMD_ebx) {
		unsigned int extended_model, extended_family;

		extended_model = (eax >> 12) & 0xf0;
		extended_family = (eax >> 20) & 0xff;
		if (family == 0x0f) {
			family += extended_family;
			model += extended_model;
		} else if (family == 0x06)
			model += extended_model;
	}

	flags = 0;
	if (ecx & bit_SSE3)
		flags |= SPA_CPU_FLAG_SSE3;
	if (ecx & bit_SSSE3)
		flags |= SPA_CPU_FLAG_SSSE3;
	if (ecx & bit_SSE4_1)
		flags |= SPA_CPU_FLAG_SSE41;
	if (ecx & bit_SSE4_2)
		flags |= SPA_CPU_FLAG_SSE42;
	if (ecx & bit_AVX)
		flags |= SPA_CPU_FLAG_AVX;
	has_osxsave = ecx & bit_OSXSAVE;
	if (ecx & bit_FMA)
		flags |= SPA_CPU_FLAG_FMA3;

	if (edx & bit_CMOV)
		flags |= SPA_CPU_FLAG_CMOV;
	if (edx & bit_MMX)
		flags |= SPA_CPU_FLAG_MMX;
	if (edx & bit_MMXEXT)
		flags |= SPA_CPU_FLAG_MMXEXT;
	if (edx & bit_SSE)
		flags |= SPA_CPU_FLAG_SSE;
	if (edx & bit_SSE2)
		flags |= SPA_CPU_FLAG_SSE2;


	if (max_level >= 7) {
		__cpuid_count(7, 0, eax, ebx, ecx, edx);

		if (ebx & bit_BMI)
			flags |= SPA_CPU_FLAG_BMI1;
		if (ebx & bit_AVX2)
			flags |= SPA_CPU_FLAG_AVX2;
		if (ebx & bit_BMI2)
			flags |= SPA_CPU_FLAG_BMI2;
#define AVX512_BITS (bit_AVX512F | bit_AVX512DQ | bit_AVX512CD | bit_AVX512BW | bit_AVX512VL)
		if ((ebx & AVX512_BITS) == AVX512_BITS)
			flags |= SPA_CPU_FLAG_AVX512;
	}

	/* Check cpuid level of extended features.  */
	__cpuid (0x80000000, ext_level, ebx, ecx, edx);

	if (ext_level >= 0x80000001) {
		__cpuid (0x80000001, eax, ebx, ecx, edx);

		if (edx & bit_3DNOW)
			flags |= SPA_CPU_FLAG_3DNOW;
		if (edx & bit_3DNOWP)
			flags |= SPA_CPU_FLAG_3DNOWEXT;
		if (edx & bit_MMX)
			flags |= SPA_CPU_FLAG_MMX;
		if (edx & bit_MMXEXT)
			flags |= SPA_CPU_FLAG_MMXEXT;
		if (ecx & bit_FMA4)
			flags |= SPA_CPU_FLAG_FMA4;
		if (ecx & bit_XOP)
			flags |= SPA_CPU_FLAG_XOP;
	}

	/* Get XCR_XFEATURE_ENABLED_MASK register with xgetbv.  */
#define XCR_XFEATURE_ENABLED_MASK	0x0
#define XSTATE_FP			0x1
#define XSTATE_SSE			0x2
#define XSTATE_YMM			0x4
#define XSTATE_OPMASK			0x20
#define XSTATE_ZMM			0x40
#define XSTATE_HI_ZMM			0x80

#define XCR_AVX_ENABLED_MASK \
	(XSTATE_SSE | XSTATE_YMM)
#define XCR_AVX512F_ENABLED_MASK \
	(XSTATE_SSE | XSTATE_YMM | XSTATE_OPMASK | XSTATE_ZMM | XSTATE_HI_ZMM)

	if (has_osxsave)
		asm (".byte 0x0f; .byte 0x01; .byte 0xd0"
			: "=a" (eax), "=d" (edx)
			: "c" (XCR_XFEATURE_ENABLED_MASK));
	else
		eax = 0;

	/* Check if AVX registers are supported.  */
	if ((eax & XCR_AVX_ENABLED_MASK) != XCR_AVX_ENABLED_MASK) {
		flags &= ~(SPA_CPU_FLAG_AVX |
				SPA_CPU_FLAG_AVX2 |
				SPA_CPU_FLAG_FMA3 |
				SPA_CPU_FLAG_FMA4 |
				SPA_CPU_FLAG_XOP);
	}

	/* Check if AVX512F registers are supported.  */
	if ((eax & XCR_AVX512F_ENABLED_MASK) != XCR_AVX512F_ENABLED_MASK) {
		flags &= ~SPA_CPU_FLAG_AVX512;
	}

	if (flags & SPA_CPU_FLAG_AVX512)
		impl->max_align = 64;
	else if (flags & (SPA_CPU_FLAG_AVX2 |
	    SPA_CPU_FLAG_AVX |
	    SPA_CPU_FLAG_XOP |
	    SPA_CPU_FLAG_FMA4 |
	    SPA_CPU_FLAG_FMA3))
		impl->max_align = 32;
	else if (flags & (SPA_CPU_FLAG_AESNI |
	    SPA_CPU_FLAG_SSE42 |
	    SPA_CPU_FLAG_SSE41 |
	    SPA_CPU_FLAG_SSSE3 |
	    SPA_CPU_FLAG_SSE3 |
	    SPA_CPU_FLAG_SSE2 |
	    SPA_CPU_FLAG_SSE))
		impl->max_align = 16;
	else
		impl->max_align = 8;

	impl->flags = flags;

	return 0;
}
