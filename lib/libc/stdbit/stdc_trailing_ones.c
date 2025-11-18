/*
 * Copyright (c) 2025 Robert Clausecker <fuz@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h>
#include <limits.h>
#include <stdbit.h>

static_assert(sizeof(unsigned char) < sizeof(unsigned),
    "stdc_trailing_ones_uc needs sizeof(unsigned char) < sizeof(unsigned)");

unsigned
stdc_trailing_ones_uc(unsigned char x)
{
	return (__builtin_ctz(~x));
}

static_assert(sizeof(unsigned short) < sizeof(unsigned),
    "stdc_trailing_ones_us needs sizeof(unsigned short) < sizeof(unsigned)");

unsigned
stdc_trailing_ones_us(unsigned short x)
{
	return (__builtin_ctz(~x));
}

unsigned
stdc_trailing_ones_ui(unsigned x)
{
	if (x == ~0U)
		return (sizeof(x) * CHAR_BIT);

	return (__builtin_ctz(~x));
}

unsigned
stdc_trailing_ones_ul(unsigned long x)
{
	if (x == ~0UL)
		return (sizeof(x) * CHAR_BIT);

	return (__builtin_ctzl(~x));
}

unsigned
stdc_trailing_ones_ull(unsigned long long x)
{
	if (x == ~0ULL)
		return (sizeof(x) * CHAR_BIT);

	return (__builtin_ctzll(~x));
}
