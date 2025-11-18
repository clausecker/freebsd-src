/*
 * Copyright (c) 2025 Robert Clausecker <fuz@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h>
#include <limits.h>
#include <stdbit.h>

static_assert(sizeof(unsigned char) < sizeof(unsigned),
    "stdc_leading_zeros_uc needs sizeof(unsigned char) < sizeof(unsigned)");

unsigned
stdc_leading_zeros_uc(unsigned char x)
{
	const int offset = CHAR_BIT * (sizeof(unsigned) - sizeof(x));

	return (__builtin_clz((x << offset) + (1 << (offset - 1))));
}

static_assert(sizeof(unsigned short) < sizeof(unsigned),
    "stdc_leading_zeros_us needs sizeof(unsigned short) < sizeof(unsigned)");

unsigned
stdc_leading_zeros_us(unsigned short x)
{
	const int offset = CHAR_BIT * (sizeof(unsigned) - sizeof(x));

	return (__builtin_clz((x << offset) + (1 << (offset - 1))));
}

unsigned
stdc_leading_zeros_ui(unsigned x)
{
	if (x == 0)
		return (sizeof(x) * CHAR_BIT);

	return (__builtin_clz(x));
}

unsigned
stdc_leading_zeros_ul(unsigned long x)
{
	if (x == 0)
		return (sizeof(x) * CHAR_BIT);

	return (__builtin_clzl(x));
}

unsigned
stdc_leading_zeros_ull(unsigned long long x)
{
	if (x == 0)
		return (sizeof(x) * CHAR_BIT);

	return (__builtin_clzll(x));
}
