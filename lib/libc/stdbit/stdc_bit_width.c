/*
 * Copyright (c) 2025 Robert Clausecker <fuz@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <limits.h>
#include <stdbit.h>

unsigned
stdc_bit_width_uc(unsigned char x)
{
	if (x == 0)
		return 0;

	return (CHAR_BIT * sizeof(unsigned) - __builtin_clz(x));
}

unsigned
stdc_bit_width_us(unsigned short x)
{
	if (x == 0)
		return 0;

	return (CHAR_BIT * sizeof(unsigned) - __builtin_clz(x));
}

unsigned
stdc_bit_width_ui(unsigned x)
{
	if (x == 0)
		return 0;

	return (CHAR_BIT * sizeof(unsigned) - __builtin_clz(x));
}

unsigned
stdc_bit_width_ul(unsigned long x)
{
	if (x == 0)
		return 0;

	return (CHAR_BIT * sizeof(unsigned long) - __builtin_clzl(x));
}

unsigned
stdc_bit_width_ull(unsigned long long x)
{
	if (x == 0)
		return 0;

	return (CHAR_BIT * sizeof(unsigned long long) - __builtin_clzll(x));
}
