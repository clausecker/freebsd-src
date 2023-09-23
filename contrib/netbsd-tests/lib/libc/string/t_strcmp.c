/* $NetBSD: t_strcmp.c,v 1.4 2012/03/25 08:17:54 joerg Exp $ */

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

int (*volatile strcmp_fn)(const char *, const char *);

ATF_TC(strcmp_basic);
ATF_TC_HEAD(strcmp_basic, tc)
{
        atf_tc_set_md_var(tc, "descr", "Test strcmp(3) results, #1");
}

ATF_TC_BODY(strcmp_basic, tc)
{
	unsigned int a0, a1, t;
	char buf0[64];
	char buf1[64];
	int ret;

	struct tab {
		const char*	val0;
		const char*	val1;
		int		ret;
	};

	const struct tab tab[] = {
		{ "",			"",			0 },

		{ "a",			"a",			0 },
		{ "a",			"b",			-1 },
		{ "b",			"a",			+1 },
		{ "",			"a",			-1 },
		{ "a",			"",			+1 },

		{ "aa",			"aa",			0 },
		{ "aa",			"ab",			-1 },
		{ "ab",			"aa",			+1 },
		{ "a",			"aa",			-1 },
		{ "aa",			"a",			+1 },

		{ "aaa",		"aaa",			0 },
		{ "aaa",		"aab",			-1 },
		{ "aab",		"aaa",			+1 },
		{ "aa",			"aaa",			-1 },
		{ "aaa",		"aa",			+1 },

		{ "aaaa",		"aaaa",			0 },
		{ "aaaa",		"aaab",			-1 },
		{ "aaab",		"aaaa",			+1 },
		{ "aaa",		"aaaa",			-1 },
		{ "aaaa",		"aaa",			+1 },

		{ "aaaaa",		"aaaaa",		0 },
		{ "aaaaa",		"aaaab",		-1 },
		{ "aaaab",		"aaaaa",		+1 },
		{ "aaaa",		"aaaaa",		-1 },
		{ "aaaaa",		"aaaa",			+1 },

		{ "aaaaaa",		"aaaaaa",		0 },
		{ "aaaaaa",		"aaaaab",		-1 },
		{ "aaaaab",		"aaaaaa",		+1 },
		{ "aaaaa",		"aaaaaa",		-1 },
		{ "aaaaaa",		"aaaaa",		+1 },
	};

	for (a0 = 0; a0 < sizeof(long); ++a0) {
		for (a1 = 0; a1 < sizeof(long); ++a1) {
			for (t = 0; t < __arraycount(tab); ++t) {
				memcpy(&buf0[a0], tab[t].val0,
				       strlen(tab[t].val0) + 1);
				memcpy(&buf1[a1], tab[t].val1,
				       strlen(tab[t].val1) + 1);

				ret = strcmp_fn(&buf0[a0], &buf1[a1]);

				if ((ret == 0 && tab[t].ret != 0) ||
				    (ret <  0 && tab[t].ret >= 0) ||
				    (ret >  0 && tab[t].ret <= 0)) {
					fprintf(stderr, "a0 %d, a1 %d, t %d\n",
					    a0, a1, t);
					fprintf(stderr, "\"%s\" \"%s\" %d\n",
					    &buf0[a0], &buf1[a1], ret);
					atf_tc_fail("Check stderr for details");
				}
			}
		}
	}
}

ATF_TC(strcmp_simple);
ATF_TC_HEAD(strcmp_simple, tc)
{
        atf_tc_set_md_var(tc, "descr", "Test strcmp(3) results, #2");
}

ATF_TC_BODY(strcmp_simple, tc)
{
	char buf1[10] = "xxx";
	char buf2[10] = "xxy";

	ATF_CHECK(strcmp_fn(buf1, buf1) == 0);
	ATF_CHECK(strcmp_fn(buf2, buf2) == 0);

	ATF_CHECK(strcmp_fn("x\xf6x", "xox") > 0);
	ATF_CHECK(strcmp_fn("xxx", "xxxyyy") < 0);
	ATF_CHECK(strcmp_fn("xxxyyy", "xxx") > 0);

	ATF_CHECK(strcmp_fn(buf1 + 0, buf2 + 0) < 0);
	ATF_CHECK(strcmp_fn(buf1 + 1, buf2 + 1) < 0);
	ATF_CHECK(strcmp_fn(buf1 + 2, buf2 + 2) < 0);
	ATF_CHECK(strcmp_fn(buf1 + 3, buf2 + 3) == 0);

	ATF_CHECK(strcmp_fn(buf2 + 0, buf1 + 0) > 0);
	ATF_CHECK(strcmp_fn(buf2 + 1, buf1 + 1) > 0);
	ATF_CHECK(strcmp_fn(buf2 + 2, buf1 + 2) > 0);
	ATF_CHECK(strcmp_fn(buf2 + 3, buf1 + 3) == 0);
}

ATF_TC(strcmp_alignments);
ATF_TC_HEAD(strcmp_alignments, tc)
{
	atf_tc_set_md_var(tc, "descr", "Test strcmp(3) with various alignments");
}

static void
alignment_testcase(char *a, char *b, int want)
{
	int res;

	res = strcmp_fn(a, b);
	ATF_CHECK_MSG(want == (res > 0) - (res < 0),
	    "strcmp(%p \"%s\", %p \"%s\") = %d != %d",
	    (void *)a, a, (void *)b, b, res, want);

	/* repeat testcase so we can debug it */
	if (want != (res > 0) - (res < 0))
		(void)strcmp_fn(a, b);
}

static void
check_strcmp_alignments(char a[], char b[],
    size_t a_off, size_t b_off, size_t len, size_t pos)
{
	char *a_str, *b_str, a_orig, b_orig;

	a[a_off] = '\0';
	b[b_off] = '\0';

	a_str = a + a_off + 1;
	b_str = b + b_off + 1;

	a_str[len] = '\0';
	b_str[len] = '\0';
	a_str[len+1] = 'A';
	b_str[len+1] = 'B';

	a_orig = a_str[pos];
	b_orig = b_str[pos];

	alignment_testcase(a_str, b_str, 0);

	if (pos < len) {
		a_str[pos] = '\0';
		alignment_testcase(a_str, b_str, -1);
		a_str[pos] = a_orig;
		b_str[pos] = '\0';
		alignment_testcase(a_str, b_str, 1);
		b_str[pos] = b_orig;
	}

	a_str[pos] = 'X';
	alignment_testcase(a_str, b_str, 1);
	a_str[pos] = a_orig;
	b_str[pos] = 'X';
	alignment_testcase(a_str, b_str, -1);
	b_str[pos] = b_orig;

	a[a_off] = '-';
	b[b_off] = '-';
	a_str[len] = '-';
	b_str[len] = '-';
	a_str[len+1] = '-';
	b_str[len+1] = '-';
}

ATF_TC_BODY(strcmp_alignments, tc)
{
	size_t a_off, b_off, len, pos;
	char a[64+16+3], b[64+16+3];

	memset(a, '-', sizeof(a));
	memset(b, '-', sizeof(b));
	a[sizeof(a) - 1] = '\0';
	b[sizeof(b) - 1] = '\0';

	for (a_off = 0; a_off < 16; a_off++)
		for (b_off = 0; b_off < 16; b_off++)
			for (len = 1; len <= 64; len++)
				for (pos = 0; pos <= len; pos++)
					check_strcmp_alignments(a, b, a_off, b_off, len, pos);
}

ATF_TP_ADD_TCS(tp)
{
	void *dl_handle;

	dl_handle = dlopen(NULL, RTLD_LAZY);
	strcmp_fn = dlsym(dl_handle, "test_strcmp");
	if (strcmp_fn == NULL)
		strcmp_fn = strcmp;

	ATF_TP_ADD_TC(tp, strcmp_basic);
	ATF_TP_ADD_TC(tp, strcmp_simple);
	ATF_TP_ADD_TC(tp, strcmp_alignments);

	return atf_no_error();
}
