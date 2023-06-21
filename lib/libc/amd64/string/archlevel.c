/*-
 * Copyright (c) 2023 The FreeBSD Foundation
 *
 * This software was developed by Robert Clausecker <fuz@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ''AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE
 */
#include <sys/types.h>

#include <machine/cpufunc.h>
#include <stdatomic.h>
#include <stddef.h>
#include <string.h>

#include "archlevel.h"

#define ARCHLEVEL_ENV	"ARCHLEVEL"

static atomic_int amd64_archlevel = X86_64_UNDEFINED;

static const struct archlevel {
	char name[12];
	u_int feat_edx, feat_ecx, amd_ecx, ext_ebx; /* CPUID feature bits that need to be present */
} levels[] = {
	{"scalar",    0x00000000, 0x00000000, 0x00000000, 0x00000000},
	{"baseline",  0x07808101, 0x00000000, 0x00000000, 0x00000000},
	{"x86-64-v2", 0x07808101, 0x00982201, 0x00000001, 0x00000000},
	{"x86-64-v3", 0x07808101, 0x38d83201, 0x00000021, 0x00000128},
	{"x86-64-v4", 0x07808101, 0x38d83201, 0x00000021, 0xd0030128},
};

static int
supported_archlevel(void)
{
	int level;
	u_int p[4], max_leaf;
	u_int feat_edx = 0, feat_ecx = 0, amd_ecx = 0, ext_ebx = 0;

	do_cpuid(0, p);
	max_leaf = p[0];

	if (max_leaf >= 1) {
		do_cpuid(1, p);
		feat_edx = p[3];
		feat_ecx = p[2];
	}

	if (max_leaf >= 7) {
		cpuid_count(7, 0, p);
		ext_ebx = p[1];
	}

	do_cpuid(0x80000000, p);
	max_leaf = p[0];

	if (max_leaf >= 0x80000001) {
		do_cpuid(0x80000001, p);
		amd_ecx = p[2];
	}

	for (level = X86_64_BASELINE; level <= X86_64_MAX; level++) {
		const struct archlevel *lvl = &levels[level];

		if ((lvl->feat_edx & feat_edx) != lvl->feat_edx ||
		    (lvl->feat_ecx & feat_ecx) != lvl->feat_ecx ||
		    (lvl->amd_ecx & amd_ecx) != lvl->amd_ecx ||
		    (lvl->ext_ebx & ext_ebx) != lvl->ext_ebx)
			return (level - 1);
	}

	return (X86_64_MAX);
}

static int
match_archlevel(const char *str)
{
	int level;

	if (str[0] == '!')
		str++;

	for (level = 0; level <= X86_64_MAX; level++) {
		size_t i;
		const char *candidate = levels[level].name;

		/* can't use strcmp here: would recurse during ifunc resolution */
		for (i = 0; str[i] == candidate[i]; i++)
			/* suffixes starting with : or + are ignored for future extensions */
			if (str[i] == '\0' || str[i] == ':' || str[i] == '+')
				return (level);
	}

	return (X86_64_UNDEFINED);
}

/*
 * We can't use getenv(), strcmp(), and a bunch of other functions here as
 * they may in turn call SIMD-optimised string functions.
 *
 * *force is set to 1 if the architecture level is valid and begins with a !
 */
static int
env_archlevel(int *force)
{
	size_t i;
	int level;
	extern char **environ;

	if (environ == NULL)
		return (X86_64_UNDEFINED);

	for (i = 0; environ[i] != NULL; i++) {
		size_t j;

		for (j = 0; environ[i][j] == ARCHLEVEL_ENV "="[j]; j++)
			if (environ[i][j] == '=') {
				level = match_archlevel(&environ[i][j + 1]);
				if (level != X86_64_UNDEFINED && environ[i][j + 1] == '!')
					*force = 1;

				return (level);
			}
	}

	return (X86_64_UNDEFINED);

}

/*
 * Determine the architecture level by checking the CPU capabilities
 * and the environment:
 *
 * 1. If environment variable ARCHLEVEL starts with a ! and is followed
 *    by a valid architecture level, that level is returned.
 * 2. Else if ARCHLEVEL is set to a valid architecture level that is
 *    supported by the CPU, that level is returned.
 * 3. Else the highest architecture level supported by the CPU is
 *    returned.
 *
 * Valid architecture levels are those defined in the levels array.
 * The architecture level "scalar" indicates that SIMD enhancements
 * shall not be used.
 */
extern int __hidden
__archlevel(void)
{
	int wantlevel, hwlevel, force = 0;
	int islevel = amd64_archlevel;

	if (islevel != X86_64_UNDEFINED)
		return (islevel);

	wantlevel = env_archlevel(&force);
	if (!force) {
		hwlevel = supported_archlevel();
		if (wantlevel == X86_64_UNDEFINED || wantlevel > hwlevel)
			wantlevel = hwlevel;
	}

	(void)atomic_compare_exchange_strong(&amd64_archlevel, &islevel, wantlevel);

	return (wantlevel);
}

/*
 * Helper function for SIMD ifunc dispatch: select the highest level
 * implementation up to the current architecture level.
 */
extern void __hidden (*
__archlevel_resolve(int32_t *funcs))()
{
	int level;

	for (level = __archlevel(); level >= 0; level--)
		if (funcs[level] != 0)
			return ((void (*)())((uintptr_t)funcs + (ptrdiff_t)funcs[level]));

	/* no function is present -- what now? */
	__builtin_trap();
}
