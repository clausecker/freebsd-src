/*-
 * SPDF-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 Robert Clausecker <fuz@FreeBSD.org>
 */

#include <string.h>
#include <ssp/ssp.h>

void *
__ssp_real(memset_explicit)(void *buf, int ch, size_t len)
{
	return (memset(buf, ch, len));
}
