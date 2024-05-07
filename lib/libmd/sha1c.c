/*
 * Copyright 2011-2023 Tarsnap Backup Inc.  All rights reserved.
 * Copyright 2005-2023 Colin Percival.  All rights reserved.
 * Copyright 2014 Sean Kelly.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sha.h>
#include <stdint.h>
#include <string.h>
#include <sys/endian.h>

/*
 * Encode a length len/4 vector of (uint32_t) into a length len vector of
 * (uint8_t) in big-endian form.  Assumes len is a multiple of 4.
 */
static void
be32enc_vect(uint8_t * dst, const uint32_t * src, size_t len)
{
	size_t i;

	for (i = 0; i < len / 4; i++)
		be32enc(dst + i * 4, src[i]);
}

/*
 * Decode a big-endian length len vector of (uint8_t) into a length
 * len/4 vector of (uint32_t).  Assumes len is a multiple of 4.
 */
static void
be32dec_vect(uint32_t * dst, const uint8_t * src, size_t len)
{
	size_t i;

	for (i = 0; i < len / 4; i++)
		dst[i] = be32dec(src + i * 4);
}

/* Elementary functions used by SHA1 */
#define ROTL(x, n)	((x << n) | (x >> (32 - n)))
#define Ch(x, y, z)	((x & (y ^ z)) ^ z)
#define Maj(x, y, z)	((x & (y | z)) | (y & z))

/* SHA1 round functions */
#define RND0(a, b, c, d, e, k) do {				\
	e = ROTL(a, 5) + Ch(b, c, d) + e + k + 0x5A827999;	\
	b = ROTL(b, 30);					\
} while (0)
#define RND1(a, b, c, d, e, k) do {				\
	e = ROTL(a, 5) + (b ^ c ^ d) + e + k + 0x6ED9EBA1;	\
	b = ROTL(b, 30);					\
} while (0)
#define RND2(a, b, c, d, e, k) do {				\
	e = ROTL(a, 5) + Maj(b, c, d) + e + k + 0x8F1BBCDC;	\
	b = ROTL(b, 30);					\
} while (0)
#define RND3(a, b, c, d, e, k) do {				\
	e = ROTL(a, 5) + (b ^ c ^ d) + e + k + 0xCA62C1D6;	\
	b = ROTL(b, 30);					\
} while (0)

/* Adjusted round functions for rotating state */
#define RND0r(S, W, i)				\
	RND0(S[(80 - i) % 5], S[(81 - i) % 5],	\
	     S[(82 - i) % 5], S[(83 - i) % 5],	\
	     S[(84 - i) % 5], W[i])
#define RND1r(S, W, i)				\
	RND1(S[(80 - i) % 5], S[(81 - i) % 5],	\
	     S[(82 - i) % 5], S[(83 - i) % 5],	\
	     S[(84 - i) % 5], W[i])
#define RND2r(S, W, i)				\
	RND2(S[(80 - i) % 5], S[(81 - i) % 5],	\
	     S[(82 - i) % 5], S[(83 - i) % 5],	\
	     S[(84 - i) % 5], W[i])
#define RND3r(S, W, i)				\
	RND3(S[(80 - i) % 5], S[(81 - i) % 5],	\
	     S[(82 - i) % 5], S[(83 - i) % 5],	\
	     S[(84 - i) % 5], W[i])

/*
 * SHA1 block compression function.  The 160-bit state is transformed via
 * the 512-bit input block to produce a new state.
 */
static void
SHA1_Transform(SHA1_CTX * ctx, const uint8_t block[64])
{
	uint32_t W[80];
	uint32_t S[5];
	int i;

	/* 1. Prepare message schedule W. */
	be32dec_vect(W, block, 64);
	for (i = 16; i < 80; i++) {
		W[i] = W[i - 3] ^ W[i - 8] ^ W[i - 14] ^ W[i - 16];
		W[i] = ROTL(W[i], 1);
	}

	/* 2. Initialize working variables. */
	S[0] = ctx->h0;
	S[1] = ctx->h1;
	S[2] = ctx->h2;
	S[3] = ctx->h3;
	S[4] = ctx->h4;

	/* 3. Mix. */
	RND0r(S, W, 0);
	RND0r(S, W, 1);
	RND0r(S, W, 2);
	RND0r(S, W, 3);
	RND0r(S, W, 4);
	RND0r(S, W, 5);
	RND0r(S, W, 6);
	RND0r(S, W, 7);
	RND0r(S, W, 8);
	RND0r(S, W, 9);
	RND0r(S, W, 10);
	RND0r(S, W, 11);
	RND0r(S, W, 12);
	RND0r(S, W, 13);
	RND0r(S, W, 14);
	RND0r(S, W, 15);
	RND0r(S, W, 16);
	RND0r(S, W, 17);
	RND0r(S, W, 18);
	RND0r(S, W, 19);
	RND1r(S, W, 20);
	RND1r(S, W, 21);
	RND1r(S, W, 22);
	RND1r(S, W, 23);
	RND1r(S, W, 24);
	RND1r(S, W, 25);
	RND1r(S, W, 26);
	RND1r(S, W, 27);
	RND1r(S, W, 28);
	RND1r(S, W, 29);
	RND1r(S, W, 30);
	RND1r(S, W, 31);
	RND1r(S, W, 32);
	RND1r(S, W, 33);
	RND1r(S, W, 34);
	RND1r(S, W, 35);
	RND1r(S, W, 36);
	RND1r(S, W, 37);
	RND1r(S, W, 38);
	RND1r(S, W, 39);
	RND2r(S, W, 40);
	RND2r(S, W, 41);
	RND2r(S, W, 42);
	RND2r(S, W, 43);
	RND2r(S, W, 44);
	RND2r(S, W, 45);
	RND2r(S, W, 46);
	RND2r(S, W, 47);
	RND2r(S, W, 48);
	RND2r(S, W, 49);
	RND2r(S, W, 50);
	RND2r(S, W, 51);
	RND2r(S, W, 52);
	RND2r(S, W, 53);
	RND2r(S, W, 54);
	RND2r(S, W, 55);
	RND2r(S, W, 56);
	RND2r(S, W, 57);
	RND2r(S, W, 58);
	RND2r(S, W, 59);
	RND3r(S, W, 60);
	RND3r(S, W, 61);
	RND3r(S, W, 62);
	RND3r(S, W, 63);
	RND3r(S, W, 64);
	RND3r(S, W, 65);
	RND3r(S, W, 66);
	RND3r(S, W, 67);
	RND3r(S, W, 68);
	RND3r(S, W, 69);
	RND3r(S, W, 70);
	RND3r(S, W, 71);
	RND3r(S, W, 72);
	RND3r(S, W, 73);
	RND3r(S, W, 74);
	RND3r(S, W, 75);
	RND3r(S, W, 76);
	RND3r(S, W, 77);
	RND3r(S, W, 78);
	RND3r(S, W, 79);

	/* 4. Mix local working variables into global state. */
	ctx->h0 += S[0];
	ctx->h1 += S[1];
	ctx->h2 += S[2];
	ctx->h3 += S[3];
	ctx->h4 += S[4];
}

static uint8_t PAD[64] = {
	0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

/* Add padding and terminating bit-count. */
static void
SHA1_Pad(SHA1_CTX * ctx)
{
	uint8_t len[8];
	uint32_t r, plen;

	/*
	 * Convert length to a vector of bytes -- we do this now rather
	 * than later because the length will change after we pad.
	 */
	be32enc(len + 0, ctx->Nh);
	be32enc(len + 4, ctx->Nl);

	/* Add 1--64 bytes so that the resulting length is 56 mod 64. */
	r = (ctx->Nl >> 3) & 0x3f;
	plen = (r < 56) ? (56 - r) : (120 - r);
	SHA1_Update(ctx, PAD, (size_t)plen);

	/* Add the terminating bit-count. */
	SHA1_Update(ctx, len, 8);
}

/**
 * SHA1_Init(ctx):
 * Initialize the SHA1 context ${ctx}.
 */
void
SHA1_Init(SHA1_CTX * ctx)
{

	/* Zero bits processed so far. */
	ctx->Nl = ctx->Nh = 0;

	/* Magic initialization constants. */
	ctx->h0 = 0x67452301;
	ctx->h1 = 0xEFCDAB89;
	ctx->h2 = 0x98BADCFE;
	ctx->h3 = 0x10325476;
	ctx->h4 = 0xC3D2E1F0;
}

/**
 * SHA1_Update(ctx, in, len):
 * Input ${len} bytes from ${in} into the SHA1 context ${ctx}.
 */
void
SHA1_Update(SHA1_CTX * ctx, const void * in, size_t len)
{
	uint32_t bitlen[2];
	uint32_t r;
	const uint8_t * src = in;

	/* Return immediately if we have nothing to do. */
	if (len == 0)
		return;

	/* Number of bytes left in the buffer from previous updates. */
	r = (ctx->Nl >> 3) & 0x3f;

	/* Convert the length into a number of bits. */
	bitlen[1] = ((uint32_t)len) << 3;
	bitlen[0] = (uint32_t)(len >> 29);

	/* Update number of bits. */
	if ((ctx->Nl += bitlen[1]) < bitlen[1])
		ctx->Nh++;
	ctx->Nh += bitlen[0];

	/* Handle the case where we don't need to perform any transforms. */
	if (len < 64 - r) {
		memcpy((char *)ctx->data + r, src, len);
		return;
	}

	/* Finish the current block. */
	memcpy((char *)ctx->data + r, src, 64 - r);
	SHA1_Transform(ctx, (const uint8_t *)ctx->data);
	src += 64 - r;
	len -= 64 - r;

	/* Perform complete blocks. */
	while (len >= 64) {
		SHA1_Transform(ctx, src);
		src += 64;
		len -= 64;
	}

	/* Copy left over data into buffer. */
	memcpy(ctx->data, src, len);
}

/**
 * SHA1_Final(digest, ctx):
 * Output the SHA1 hash of the data input to the context ${ctx} into the
 * buffer ${digest}, and clear the context state.
 */
void
SHA1_Final(uint8_t digest[20], SHA1_CTX * ctx)
{
	/* Add padding. */
	SHA1_Pad(ctx);

	/* Write the hash. */
	be32enc(digest +  0, ctx->h0);
	be32enc(digest +  4, ctx->h1);
	be32enc(digest +  8, ctx->h2);
	be32enc(digest + 12, ctx->h3);
	be32enc(digest + 16, ctx->h4);
}

/**
 * SHA1_Buf(in, len, digest):
 * Compute the SHA1 hash of ${len} bytes from ${in} and write it to ${digest}.
 */
void
SHA1_Buf(const void * in, size_t len, uint8_t digest[20])
{
	SHA1_CTX ctx;

	SHA1_Init(&ctx);
	SHA1_Update(&ctx, in, len);
	SHA1_Final(digest, &ctx);
}
