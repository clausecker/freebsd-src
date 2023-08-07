/* $NetBSD: t_strcpy.c,v 1.1 2011/07/07 08:59:33 jruoho Exp $ */

/*
 * Written by J.T. Conklin <jtc@acorntoolworks.com>
 *
 * Portions of this software were developed by Robert Clausecker
 * <fuz@FreeBSD.org> under sponsorship from the FreeBSD Foundation.
 *
 * Public domain.
 */

#include <atf-c.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>

char * (*volatile strcpy_fn)(char *restrict, const char *restrict);

ATF_TC(strcpy_basic);
ATF_TC_HEAD(strcpy_basic, tc)
{
        atf_tc_set_md_var(tc, "descr", "Test strcpy(3) results");
}

ATF_TC_BODY(strcpy_basic, tc)
{
	void *dl_handle;
	unsigned int a0, a1, t;
	char buf0[128];
	char buf1[128];
	char *ret;

	struct tab {
		const char*	val;
		size_t		len;
	};

	const struct tab tab[] = {
		/*
		 * patterns that check for all combinations of leading and
		 * trailing unaligned characters (on a 64 bit processor)
		 */

		{ "",					0 },
		{ "a",					1 },
		{ "ab",					2 },
		{ "abc",				3 },
		{ "abcd",				4 },
		{ "abcde",				5 },
		{ "abcdef",				6 },
		{ "abcdefg",				7 },
		{ "abcdefgh",				8 },
		{ "abcdefghi",				9 },
		{ "abcdefghij",				10 },
		{ "abcdefghijk",			11 },
		{ "abcdefghijkl",			12 },
		{ "abcdefghijklm",			13 },
		{ "abcdefghijklmn",			14 },
		{ "abcdefghijklmno",			15 },
		{ "abcdefghijklmnop",			16 },
		{ "abcdefghijklmnopq",			17 },
		{ "abcdefghijklmnopqr",			18 },
		{ "abcdefghijklmnopqrs",		19 },
		{ "abcdefghijklmnopqrst",		20 },
		{ "abcdefghijklmnopqrstu",		21 },
		{ "abcdefghijklmnopqrstuv",		22 },
		{ "abcdefghijklmnopqrstuvw",		23 },
		{ "abcdefghijklmnopqrstuvwx",		24 },
		{ "abcdefghijklmnopqrstuvwxy",		25 },
		{ "abcdefghijklmnopqrstuvwxyz",		26 },
		{ "abcdefghijklmnopqrstuvwxyz0",	27 },
		{ "abcdefghijklmnopqrstuvwxyz01",	28 },
		{ "abcdefghijklmnopqrstuvwxyz012",	29 },
		{ "abcdefghijklmnopqrstuvwxyz0123",	30 },
		{ "abcdefghijklmnopqrstuvwxyz01234",	31 },

		/*
		 * patterns that check for the cases where the expression:
		 *
		 *	((word - 0x7f7f..7f) & 0x8080..80)
		 *
		 * returns non-zero even though there are no zero bytes in
		 * the word.
		 */

		{ "" "\xff\xff\xff\xff\xff\xff\xff\xff" "abcdefgh",	16 },
		{ "a" "\xff\xff\xff\xff\xff\xff\xff\xff" "bcdefgh",	16 },
		{ "ab" "\xff\xff\xff\xff\xff\xff\xff\xff" "cdefgh",	16 },
		{ "abc" "\xff\xff\xff\xff\xff\xff\xff\xff" "defgh",	16 },
		{ "abcd" "\xff\xff\xff\xff\xff\xff\xff\xff" "efgh",	16 },
		{ "abcde" "\xff\xff\xff\xff\xff\xff\xff\xff" "fgh",	16 },
		{ "abcdef" "\xff\xff\xff\xff\xff\xff\xff\xff" "gh",	16 },
		{ "abcdefg" "\xff\xff\xff\xff\xff\xff\xff\xff" "h",	16 },
		{ "abcdefgh" "\xff\xff\xff\xff\xff\xff\xff\xff" "",	16 },
	};

	dl_handle = dlopen(NULL, RTLD_LAZY);
	strcpy_fn = dlsym(dl_handle, "test_strcpy");
	if (!strcpy_fn)
		strcpy_fn = strcpy;

	for (a0 = 0; a0 < 16; ++a0) {
		for (a1 = 0; a1 < sizeof(long); ++a1) {
			for (t = 0; t < (sizeof(tab) / sizeof(tab[0])); ++t) {

				memcpy(&buf1[a1], tab[t].val, tab[t].len + 1);
				ret = strcpy_fn(&buf0[a0], &buf1[a1]);

				/*
				 * verify strcpy returns address of
				 * first parameter
				 */
			    	if (&buf0[a0] != ret) {
					fprintf(stderr, "a0 %d, a1 %d, t %d\n",
					    a0, a1, t);
					atf_tc_fail("strcpy did not return "
					    "its first arg");
				}

				/*
				 * verify string was copied correctly
				 */
				if (memcmp(&buf0[a0], &buf1[a1],
					   tab[t].len + 1) != 0) {
					fprintf(stderr, "a0 %d, a1 %d, t %d\n",
					    a0, a1, t);
					atf_tc_fail("not correctly copied");
				}
			}
		}
	}
}

ATF_TP_ADD_TCS(tp)
{

	ATF_TP_ADD_TC(tp, strcpy_basic);

	return atf_no_error();
}
