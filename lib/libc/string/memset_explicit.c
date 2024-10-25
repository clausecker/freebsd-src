/*-
 * SPDF-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 Robert Clausecker <fuz@FreeBSD.org>
 */

#include <string.h>

void *
memset_explicit(void *buf, int ch, size_t len)
{
	return (memset(buf, ch, len));
}
