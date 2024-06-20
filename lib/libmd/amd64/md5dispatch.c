/*-
 * Copyright (c) 2024 Robert Clausecker <fuz@freebsd.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// #include <stdint.h>
#include <machine/specialreg.h>
#include <sys/types.h>
#include <md5.h>
#include <x86/ifunc.h>

extern void md5block_baseline(MD5_CTX *, const void *, size_t);
extern void md5block_bmi1(MD5_CTX *, const void *, size_t);
extern void md5block_avx512(MD5_CTX *, const void *, size_t);

DEFINE_UIFUNC(, void, md5block, (MD5_CTX *, const void *, size_t))
{
	if ((cpu_stdext_feature & (CPUID_STDEXT_AVX512F | CPUID_STDEXT_AVX512VL))
	    == (CPUID_STDEXT_AVX512F | CPUID_STDEXT_AVX512VL))
		return (md5block_avx512);
	if (cpu_stdext_feature & CPUID_STDEXT_BMI1)
		return (md5block_bmi1);
	else
		return (md5block_baseline);
}
