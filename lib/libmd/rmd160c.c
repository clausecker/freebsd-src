/*-
 * Copyright (c) 2024 Robert Clausecker <fuz@freebsd.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <sys/types.h>
#include <assert.h>
#include <ripemd.h>
#include <stdint.h>
#include <string.h>
#include <sys/endian.h>

static void	ripemd160block(RIPEMD160_CTX *, const void *, size_t);

void
RIPEMD160_Init(RIPEMD160_CTX *c)
{
	c->A = 0x67452301;
	c->B = 0xefcdab89;
	c->C = 0x98badcfe;
	c->D = 0x10325476;
	c->E = 0xc3d2e1f0;

	c->Nl = 0;
	c->Nh = 0;
	c->num = 0;
}

void
RIPEMD160_Update(RIPEMD160_CTX *c, const void *data, size_t len)
{
	uint64_t nn;
	const char *p = data;

	nn = (uint64_t)c->Nl | (uint64_t)c->Nh << 32;
	nn += len;
	c->Nl = (uint32_t)nn;
	c->Nh = (uint32_t)(nn >> 32);

	if (c->num > 0) {
		int n = RIPEMD160_CBLOCK - c->num;

		if (n > len)
			n = len;

		memcpy((char *)c->data + c->num, p, n);
		c->num += n;
		if (c->num == RIPEMD160_CBLOCK) {
			ripemd160block(c, (void *)c->data, RIPEMD160_CBLOCK);
			c->num = 0;
		}

		p += n;
		len -= n;
	}

	if (len >= RIPEMD160_CBLOCK) {
		size_t n = len & ~(size_t)(RIPEMD160_CBLOCK - 1);

		ripemd160block(c, p, n);
		p += n;
		len -= n;
	}

	if (len > 0) {
		memcpy((void *)c->data, p, len);
		c->num = len;
	}
}

void
RIPEMD160_Final(unsigned char *md, RIPEMD160_CTX *c)
{
	uint64_t len;
	unsigned t;
	unsigned char tmp[RIPEMD160_CBLOCK + sizeof(uint64_t)] = {0x80, 0};

	len = (uint64_t)c->Nl | (uint64_t)c->Nh << 32;
	t = 64 + 56 - c->Nl % 64;
	if (t > 64)
		t -= 64;

	/* length in bits */
	len <<= 3;
	le64enc(tmp + t, len);
	RIPEMD160_Update(c, tmp, t + 8);
	assert(c->Nl % RIPEMD160_CBLOCK == 0);

	le32enc(md +  0, c->A);
	le32enc(md +  4, c->B);
	le32enc(md +  8, c->C);
	le32enc(md + 12, c->D);
	le32enc(md + 16, c->E);

	explicit_bzero(c, sizeof(*c));
}

static void
ripemd160block(RIPEMD160_CTX *c, const void *data, size_t len)
{
	uint32_t m[16];
	uint32_t h0 = c->A, h1 = c->B, h2 = c->C, h3 = c->D, h4 = c->E;
	const char *p = data;

	while (len >= RIPEMD160_CBLOCK) {
		size_t i;
		uint32_t a, b, c, d, e, aa, bb, cc, dd, ee;
		uint32_t f, ff, t, tt;

		a = aa = h0;
		b = bb = h1;
		c = cc = h2;
		d = dd = h3;
		e = ee = h4;

#		pragma unroll
		for (i = 0; i < 16; i++)
			m[i] = le32dec(p + 4*i);

#		pragma unroll
		for (i = 0; i < 16; i++) {
			const int s[] = { 11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8 };
			const int ss[] = { 8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6 };
			const int rr[] = { 5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12 };

			f = b ^ (c ^ d);
			t = a + f + m[i];
			t = (t << s[i] | t >> 32 - s[i]) + e;
			a = e;
			e = d;
			d = (c << 10 | c >> 32 - 10);
			c = b;
			b = t;

			ff = bb ^ (cc | ~dd);
			tt = aa + ff + m[rr[i]] + 0x50a28be6;
			tt = (tt << ss[i] | tt >> 32 - ss[i]) + ee;
			aa = ee;
			ee = dd;
			dd = (cc << 10 | cc >> 32 - 10);
			cc = bb;
			bb = tt;
		}

#		pragma unroll
		for (i = 0; i < 16; i++) {
			const int s[] = { 7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12 };
			const int ss[] = { 9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11 };
			const int r[] = { 7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8 };
			const int rr[] = { 6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2 };

			f = d ^ b & (c ^ d);
//			f = (b & c) + (~b & d);
			t = a + f + m[r[i]] + 0x5a827999;
			t = (t << s[i] | t >> 32 - s[i]) + e;
			a = e;
			e = d;
			d = (c << 10 | c >> 32 - 10);
			c = b;
			b = t;

//			ff = cc ^ dd & (bb ^ cc);
			ff = (bb & dd) + (cc & ~dd);
			tt = aa + ff + m[rr[i]] + 0x5c4dd124;
			tt = (tt << ss[i] | tt >> 32 - ss[i]) + ee;
			aa = ee;
			ee = dd;
			dd = (cc << 10 | cc >> 32 - 10);
			cc = bb;
			bb = tt;
		}

#		pragma unroll
		for (i = 0; i < 16; i++) {
			const int s[] = { 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5 };
			const int ss[] = { 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5 };
			const int r[] = { 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12 };
			const int rr[] = { 15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13 };

			f = (b | ~c) ^ d;
			t = a + f + m[r[i]] + 0x6ed9eba1;
			t = (t << s[i] | t >> 32 - s[i]) + e;
			a = e;
			e = d;
			d = (c << 10 | c >> 32 - 10);
			c = b;
			b = t;

			ff = (bb | ~cc) ^ dd;
			tt = aa + ff + m[rr[i]] + 0x6d703ef3;
			tt = (tt << ss[i] | tt >> 32 - ss[i]) + ee;
			aa = ee;
			ee = dd;
			dd = (cc << 10 | cc >> 32 - 10);
			cc = bb;
			bb = tt;
		}

#		pragma unroll
		for (i = 0; i < 16; i++) {
			const int s[] = { 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12 };
			const int ss[] = { 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8 };
			const int r[] = { 1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2 };
			const int rr[] = { 8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14 };

//			f = c ^ d & (b ^ c);
			f = (b & d) + (c & ~d);
			t = a + f + m[r[i]] + 0x8f1bbcdc;
			t = (t << s[i] | t >> 32 - s[i]) + e;
			a = e;
			e = d;
			d = (c << 10 | c >> 32 - 10);
			c = b;
			b = t;

			ff = dd ^ bb & (cc ^ dd);
//			ff = (bb & cc) + (~bb & dd);
			tt = aa + ff + m[rr[i]] + 0x7a6d76e9;
			tt = (tt << ss[i] | tt >> 32 - ss[i]) + ee;
			aa = ee;
			ee = dd;
			dd = (cc << 10 | cc >> 32 - 10);
			cc = bb;
			bb = tt;
		}

#		pragma unroll
		for (i = 0; i < 16; i++) {
			const int s[] = { 9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6 };
			const int ss[] = { 8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11 };
			const int r[] = { 4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13 };
			const int rr[] = { 12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11 };

			f = b ^ (c | ~d);
			t = a + f + m[r[i]] + 0xa953fd4e;
			t = (t << s[i] | t >> 32 - s[i]) + e;
			a = e;
			e = d;
			d = (c << 10 | c >> 32 - 10);
			c = b;
			b = t;

			ff = bb ^ (cc ^ dd);
			tt = aa + ff + m[rr[i]];
			tt = (tt << ss[i] | tt >> 32 - ss[i]) + ee;
			aa = ee;
			ee = dd;
			dd = (cc << 10 | cc >> 32 - 10);
			cc = bb;
			bb = tt;
		}

		t = h1 + c + dd;
		h1 = h2 + d + ee;
		h2 = h3 + e + aa;
		h3 = h4 + a + bb;
		h4 = h0 + b + cc;
		h0 = t;

		p += RIPEMD160_CBLOCK;
		len -= RIPEMD160_CBLOCK;
	}

	c->A = h0;
	c->B = h1;
	c->C = h2;
	c->D = h3;
	c->E = h4;
}

#ifdef WEAK_REFS
/* When building libmd, provide weak references. Note: this is not
   activated in the context of compiling these sources for internal
   use in libcrypt.
 */
#undef RIPEMD160_Init
__weak_reference(_libmd_RIPEMD160_Init, RIPEMD160_Init);
#undef RIPEMD160_Update
__weak_reference(_libmd_RIPEMD160_Update, RIPEMD160_Update);
#undef RIPEMD160_Final
__weak_reference(_libmd_RIPEMD160_Final, RIPEMD160_Final);
#endif
