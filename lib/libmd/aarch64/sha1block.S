/*-
 * Copyright (c) 2017 The Go Authors. All rights reserved.
 * Copyright (c) 2024 Robert Clausecker <fuz@freebsd.org>
 *
 * Adapted from Go's crypto/sha1/sha1block_arm64.s.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *   * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *   * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <machine/asm.h>

/*
 * Scalar SHA1 implementation.
 *
 * Due to the ample register file available on AArch64, the w array is
 * kept entirely in registers.  The saved a-e variabled are instead kept
 * in memory as we don't have that much memory.
 */

	// sha1block(SHA1_CTX, buf, len)
ENTRY(sha1block)
ctx	.req	x0
buf	.req	x1
len	.req	x2
w	.req	sp
a	.req	w3
b	.req	w4
c	.req	w5
d	.req	w6
e	.req	w7
k	.req	w8
f	.req	w9
tmp	.req	w10
w_0	.req	w11
w_1	.req	w12
w_2	.req	w13
w_3	.req	w14
w_4	.req	w15
w_5	.req	w16
w_6	.req	w17
// w18 is the platform register
w_7	.req	w19
w_8	.req	w20
w_9	.req	w21
w_10	.req	w22
w_11	.req	w23
w_12	.req	w24
w_13	.req	w25
w_14	.req	w26
w_15	.req	w27

.macro	shuffle	w_i, w_i3, w_i8, w_i14
	eor	\w_i, \w_i, \w_i3
	eor	tmp, \w_i8, \w_i14
	eor	\w_i, \w_i, tmp		// w[i-16] ^ w[i-14] ^ w[i-8] ^ w[i-3]
	ror	\w_i, \w_i, #31		// w[i] = ... ror #31
.endm

.macro	func1	a, b, c, d, e
	and	f, \c, \b
	bic	tmp, \d, \b
	orr	f, f, tmp
.endm

.macro	func2	a, b, c, d, e
	eor	f, \b, \c
	eor	f, f, \d
.endm

.macro	func3	a, b, c, d, e
	eor	tmp, \b, \c
	and	f, \b, \c
	and	tmp, tmp, \d
	orr	f, f, tmp
.endm

.macro	func4	a, b, c, d, e
	func2	\a, \b, \c, \d, \e
.endm

.macro	mix	a, b, c, d, e, w_i
	ror	\b, \b, #2
	ror	tmp, \a, #27
	add	\e, \e, \w_i
	add	tmp, tmp, k
	add	\e, \e, f
	add	\e, \e, tmp		// (a ror 27) + e + f + k + w[i]
.endm

.macro	round1	a, b, c, d, e, w_i
	func1 	\a, \b, \c, \d, \e
	rev	\w_i, \w_i
	mix	\a, \b, \c, \d, \e, \w_i
.endm

.macro	round	func, a, b, c, d, e, w_i, w_i3, w_i8, w_i14
	shuffle	\w_i, \w_i3, \w_i8, \w_i14
	\func	\a, \b, \c, \d, \e
	mix	\a, \b, \c, \d, \e, \w_i
.endm

.macro	round1x	a, b, c, d, e, w_i, w_i3, w_i8, w_i14
	round	func1, \a, \b, \c, \d, \e, \w_i, \w_i3, \w_i8, \w_i14
.endm

.macro	round2	a, b, c, d, e, w_i, w_i3, w_i8, w_i14
	round	func2, \a, \b, \c, \d, \e, \w_i, \w_i3, \w_i8, \w_i14
.endm

.macro	round3	a, b, c, d, e, w_i, w_i3, w_i8, w_i14
	round	func3, \a, \b, \c, \d, \e, \w_i, \w_i3, \w_i8, \w_i14
.endm

.macro	round4	a, b, c, d, e, w_i, w_i3, w_i8, w_i14
	round	func4, \a, \b, \c, \d, \e, \w_i, \w_i3, \w_i8, \w_i14
.endm

	ands	len, len, #~63		// take length in multiples of block length
	beq	1f			// bail out if input empty

	sub	sp, sp, #24+9*8		// allocate stack space
	str	x19, [sp, #24+0*8]
	stp	x20, x21, [sp, #24+1*8]
	stp	x22, x23, [sp, #24+3*8]
	stp	x24, x25, [sp, #24+5*8]
	stp	x26, x27, [sp, #24+7*8]

	ldp	a, b, [ctx, #0]		// load SHA1 state from context
	ldp	c, d, [ctx, #8]
	ldr	e, [ctx, #16]

0:	stp	a, b, [sp, #0]		// save old SHA1 state
	stp	c, d, [sp, #8]
	str	e, [sp, #16]

	movz	k, #0x7999		// round constant 1
	movk	k, #0x5a82, lsl #16

	ldp	w_0, w_1, [buf, #0*4]
	round1	a, b, c, d, e, w_0
	round1	e, a, b, c, d, w_1

	ldp	w_2, w_3, [buf, #2*4]
	round1	d, e, a, b, c, w_2
	round1	c, d, e, a, b, w_3

	ldp	w_4, w_5, [buf, #4*4]
	round1	b, c, d, e, a, w_4
	round1	a, b, c, d, e, w_5

	ldp	w_6, w_7, [buf, #6*4]
	round1	e, a, b, c, d, w_6
	round1	d, e, a, b, c, w_7

	ldp	w_8, w_9, [buf, #8*4]
	round1	c, d, e, a, b, w_8
	round1	b, c, d, e, a, w_9

	ldp	w_10, w_11, [buf, #10*4]
	round1	a, b, c, d, e, w_10
	round1	e, a, b, c, d, w_11

	ldp	w_12, w_13, [buf, #12*4]
	round1	d, e, a, b, c, w_12
	round1	c, d, e, a, b, w_13

	ldp	w_14, w_15, [buf, #14*4]
	round1	b, c, d, e, a, w_14
	round1	a, b, c, d, e, w_15

	round1x	e, a, b, c, d, w_0,  w_13,  w_8,  w_2
	round1x	d, e, a, b, c, w_1,  w_14,  w_9,  w_3
	round1x	c, d, e, a, b, w_2,  w_15, w_10,  w_4
	round1x	b, c, d, e, a, w_3,  w_0,  w_11,  w_5

	movz	k, #0xeba1		// round constant 2
	movk	k, #0x6ed9, lsl #16

	round2	a, b, c, d, e, w_4,  w_1,  w_12,  w_6
	round2	e, a, b, c, d, w_5,  w_2,  w_13,  w_7
	round2	d, e, a, b, c, w_6,  w_3,  w_14,  w_8
	round2	c, d, e, a, b, w_7,  w_4,  w_15,  w_9
	round2	b, c, d, e, a, w_8,  w_5,  w_0,   w_10

	round2	a, b, c, d, e, w_9,  w_6,  w_1,   w_11
	round2	e, a, b, c, d, w_10, w_7,  w_2,   w_12
	round2	d, e, a, b, c, w_11, w_8,  w_3,   w_13
	round2	c, d, e, a, b, w_12, w_9,  w_4,   w_14
	round2	b, c, d, e, a, w_13, w_10, w_5,   w_15

	round2	a, b, c, d, e, w_14, w_11, w_6,   w_0
	round2	e, a, b, c, d, w_15, w_12, w_7,   w_1
	round2	d, e, a, b, c, w_0,  w_13, w_8,   w_2
	round2	c, d, e, a, b, w_1,  w_14, w_9,   w_3
	round2	b, c, d, e, a, w_2,  w_15, w_10,  w_4

	round2	a, b, c, d, e, w_3,  w_0,  w_11,  w_5
	round2	e, a, b, c, d, w_4,  w_1,  w_12,  w_6
	round2	d, e, a, b, c, w_5,  w_2,  w_13,  w_7
	round2	c, d, e, a, b, w_6,  w_3,  w_14,  w_8
	round2	b, c, d, e, a, w_7,  w_4,  w_15,  w_9

	movz	k, #0xbcdc		// round constant 3
	movk	k, #0x8f1b, lsl #16

	round3	a, b, c, d, e, w_8,  w_5,  w_0,  w_10
	round3	e, a, b, c, d, w_9,  w_6,  w_1,  w_11
	round3	d, e, a, b, c, w_10, w_7,  w_2,  w_12
	round3	c, d, e, a, b, w_11, w_8,  w_3,  w_13
	round3	b, c, d, e, a, w_12, w_9,  w_4,  w_14

	round3	a, b, c, d, e, w_13, w_10, w_5,  w_15
	round3	e, a, b, c, d, w_14, w_11, w_6,  w_0
	round3	d, e, a, b, c, w_15, w_12, w_7,  w_1
	round3	c, d, e, a, b, w_0,  w_13, w_8,  w_2
	round3	b, c, d, e, a, w_1,  w_14, w_9,  w_3

	round3	a, b, c, d, e, w_2,  w_15, w_10, w_4
	round3	e, a, b, c, d, w_3,  w_0,  w_11, w_5
	round3	d, e, a, b, c, w_4,  w_1,  w_12, w_6
	round3	c, d, e, a, b, w_5,  w_2,  w_13, w_7
	round3	b, c, d, e, a, w_6,  w_3,  w_14, w_8

	round3	a, b, c, d, e, w_7,  w_4,  w_15, w_9
	round3	e, a, b, c, d, w_8,  w_5,  w_0,  w_10
	round3	d, e, a, b, c, w_9,  w_6,  w_1,  w_11
	round3	c, d, e, a, b, w_10, w_7,  w_2,  w_12
	round3	b, c, d, e, a, w_11, w_8,  w_3,  w_13

	movz	k, #0xc1d6		// round constant 4
	movk	k, #0xca62, lsl #16

	round4	a, b, c, d, e, w_12, w_9,  w_4,  w_14
	round4	e, a, b, c, d, w_13, w_10, w_5,  w_15
	round4	d, e, a, b, c, w_14, w_11, w_6,  w_0
	round4	c, d, e, a, b, w_15, w_12, w_7,  w_1
	round4	b, c, d, e, a, w_0,  w_13, w_8,  w_2

	round4	a, b, c, d, e, w_1,  w_14, w_9,  w_3
	round4	e, a, b, c, d, w_2,  w_15, w_10, w_4
	round4	d, e, a, b, c, w_3,  w_0,  w_11, w_5
	round4	c, d, e, a, b, w_4,  w_1,  w_12, w_6
	round4	b, c, d, e, a, w_5,  w_2,  w_13, w_7

	round4	a, b, c, d, e, w_6,  w_3,  w_14, w_8
	round4	e, a, b, c, d, w_7,  w_4,  w_15, w_9
	round4	d, e, a, b, c, w_8,  w_5,  w_0,  w_10
	round4	c, d, e, a, b, w_9,  w_6,  w_1,  w_11
	round4	b, c, d, e, a, w_10, w_7,  w_2,  w_12

	round4	a, b, c, d, e, w_11, w_8,  w_3,  w_13
	round4	e, a, b, c, d, w_12, w_9,  w_4,  w_14
	round4	d, e, a, b, c, w_13, w_10, w_5,  w_15
	round4	c, d, e, a, b, w_14, w_11, w_6,  w_0
	round4	b, c, d, e, a, w_15, w_12, w_7,  w_1

	ldp	w_0, w_1, [sp, #0]	// reload saved SHA1 state
	ldp	w_2, w_3, [sp, #8]
	ldr	w_4, [sp, #16]

	add	a, a, w_0
	add	b, b, w_1
	add	c, c, w_2
	add	d, d, w_3
	add	e, e, w_4

	add	buf, buf, #64
	subs	len, len, #64
	bhi	0b

	stp	a, b, [ctx, #0]		// write updated SHA1 state
	stp	c, d, [ctx, #8]
	str	e, [ctx, #16]

	ldr	x19, [sp, #24+0*8]
	ldp	x20, x21, [sp, #24+1*8]
	ldp	x22, x23, [sp, #24+3*8]
	ldp	x24, x25, [sp, #24+5*8]
	ldp	x26, x27, [sp, #24+7*8]
	add	sp, sp, #24+9*8

1:	ret
END(sha1block)

	.section .note.GNU-stack,"",%progbits
