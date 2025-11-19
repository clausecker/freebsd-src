/*
 * Copyright (c) 2025 Robert Clausecker <fuz@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <limits.h>
#include <stdbit.h>

unsigned char
stdc_bit_floor_uc(unsigned char x)
{
	if (x == 0)
		return (0);

	return (1U << (CHAR_BIT * sizeof(unsigned int) - __builtin_clz(x) - 1));
}

unsigned short
stdc_bit_floor_us(unsigned short x)
{
	if (x == 0)
		return (0);

	return (1U << (CHAR_BIT * sizeof(unsigned int) - __builtin_clz(x) - 1));
}

unsigned int
stdc_bit_floor_ui(unsigned int x)
{
	if (x == 0)
		return (0);

	return (1U << (CHAR_BIT * sizeof(unsigned int) - __builtin_clz(x) - 1));
}

unsigned long
stdc_bit_floor_ul(unsigned long x)
{
	if (x == 0)
		return (0);

	return (1UL << (CHAR_BIT * sizeof(unsigned long) - __builtin_clzl(x) - 1));
}

unsigned long long
stdc_bit_floor_ull(unsigned long long x)
{
	if (x == 0)
		return (0);

	return (1ULL << (CHAR_BIT * sizeof(unsigned long long) - __builtin_clzll(x) - 1));
}
