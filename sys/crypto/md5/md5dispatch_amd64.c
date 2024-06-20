/*-
 * Copyright (c) 2024 Robert Clausecker <fuz@freebsd.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <machine/specialreg.h>
#include <sys/types.h>
#include <sys/md5.h>
#include <x86/ifunc.h>

extern void _libmd_md5block_baseline(MD5_CTX *, const void *, size_t);
extern void _libmd_md5block_bmi1(MD5_CTX *, const void *, size_t);
extern void _libmd_md5block_avx512(MD5_CTX *, const void *, size_t);

DEFINE_UIFUNC(, void, _libmd_md5block, (MD5_CTX *, const void *, size_t))
{
	/*
	 * AVX-512 would need to be turned on first in the kernel
	 * and that's too expensive; the BMI1 kernel is plenty fast
	 * and doesn't require any special registers to run.
	 */
#ifndef _KERNEL
	if ((cpu_stdext_feature & (CPUID_STDEXT_AVX512F | CPUID_STDEXT_AVX512VL))
	    == (CPUID_STDEXT_AVX512F | CPUID_STDEXT_AVX512VL))
		return (_libmd_md5block_avx512);
#endif

	if (cpu_stdext_feature & CPUID_STDEXT_BMI1)
		return (_libmd_md5block_bmi1);
	else
		return (_libmd_md5block_baseline);
}
