/*-
 * Copyright (c) 2024 Robert Clausecker <fuz@freebsd.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <machine/asm.h>

	// md5block(MD5_CTX, buf, len)
ENTRY(md5block)
.macro	round	a, b, c, d, f, k, m, s
	\f	%ebp, \b, \c, \d
	add	$\k, \a			// a + k[i]
	add	((\m)%16*4)(%rsi), \a	// a + k[i] + m[g]
	add	%ebp, \a		// a + k[i] + m[g] + f
	rol	$\s, \a
	add	\b, \a
.endm

	// f = b ? c : d
.macro	f0	f, b, c, d
	mov	\c, \f
	xor	\d, \f
	and	\b, \f
	xor	\d, \f
.endm

	// f = d ? b : c
.macro	f1	f, b, c, d
	mov	\c, \f
	xor	\b, \f
	and	\d, \f
	xor	\c, \f
.endm

	// f = b ^ c ^ d
.macro	f2	f, b, c, d
	mov	\c, \f
	xor	\d, \f
	xor	\b, \f
.endm

	// f = c ^ (b | ~d)
.macro	f3	f, b, c, d
	mov	$-1, \f
	xor	\d, \f
	or	\b, \f
	xor	\c, \f
.endm

	// do 4 rounds
.macro	rounds	f, p, q, s0, s1, s2, s3, k0, k1, k2, k3, k4
	round	%eax, %ebx, %ecx, %edx, \f, \k0, \p*0+\q, \s0
	round	%edx, %eax, %ebx, %ecx, \f, \k1, \p*1+\q, \s1
	round	%ecx, %edx, %eax, %ebx, \f, \k2, \p*2+\q, \s2
	round	%ebx, %ecx, %edx, %eax, \f, \k3, \p*3+\q, \s3
.endm

	// do 4 rounds with f0, f1, f2, f3
.macro	rounds0	i, k0, k1, k2, k3
	rounds	f0, 1, \i, 7, 12, 17, 22, \k0, \k1, \k2, \k3
.endm

.macro	rounds1	i, k0, k1, k2, k3
	rounds	f1, 5, 5*\i+1, 5, 9, 14, 20, \k0, \k1, \k2, \k3
.endm

.macro	rounds2	i, k0, k1, k2, k3
	rounds	f2, 3, 3*\i+5, 4, 11, 16, 23, \k0, \k1, \k2, \k3
.endm

.macro	rounds3	i, k0, k1, k2, k3
	rounds	f3, 7, 7*\i, 6, 10, 15, 21, \k0, \k1, \k2, \k3
.endm

	push	%rbx
	push	%rbp
	push	%r12

	and	$~63, %rdx		// length in blocks
	lea	(%rsi, %rdx, 1), %r12	// end pointer

	mov	(%rdi), %eax		// a
	mov	4(%rdi), %ebx		// b
	mov	8(%rdi), %ecx		// c
	mov	12(%rdi), %edx		// d

	cmp	%rsi, %r12		// any data to process?
	je	.Lend

	.balign	16
.Lloop:	mov	%eax, %r8d
	mov	%ebx, %r9d
	mov	%ecx, %r10d
	mov	%edx, %r11d

	rounds0	 0, 0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee
	rounds0	 4, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501
	rounds0	 8, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be
	rounds0	12, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821

	rounds1	16, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa
	rounds1	20, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8
	rounds1	24, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed
	rounds1	28, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a

	rounds2	32, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c
	rounds2	36, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70
	rounds2	40, 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05
	rounds2	44, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665

	rounds3	48, 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039
	rounds3	52, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1
	rounds3	56, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1
	rounds3	60, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391

	add	%r8d, %eax
	add	%r9d, %ebx
	add	%r10d, %ecx
	add	%r11d, %edx

	add	$64, %rsi
	cmp	%rsi, %r12
	jne	.Lloop

	mov	%eax, (%rdi)
	mov	%ebx, 4(%rdi)
	mov	%ecx, 8(%rdi)
	mov	%edx, 12(%rdi)

.Lend:	pop	%r12
	pop	%rbp
	pop	%rbx
	ret
END(md5block)

	.section .note.GNU-stack,"",%progbits
