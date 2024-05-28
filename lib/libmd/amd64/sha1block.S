/*-
 * Copyright (c) 2009 The Go Authors. All rights reserved.
 * Copyright (c) 2024 Robert Clausecker <fuz@freebsd.org>
 *
 * Adapted from Go's crypto/sha1/sha1block_amd64.s.
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
#include <machine/specialreg.h>

/*
 * SHA-1 block routine. See sha1block.go for Go equivalent.
 *
 * There are 80 rounds of 4 types:
 *   - rounds 0-15 are type 1 and load data (round1 macro).
 *   - rounds 16-19 are type 1 and do not load data (round1x macro).
 *   - rounds 20-39 are type 2 and do not load data (round2 macro).
 *   - rounds 40-59 are type 3 and do not load data (round3 macro).
 *   - rounds 60-79 are type 4 and do not load data (round4 macro).
 *
 * Each round loads or shuffles the data, then computes a per-round
 * function of b, c, d, and then mixes the result into and rotates the
 * five registers a, b, c, d, e holding the intermediate results.
 *
 * The register rotation is implemented by rotating the arguments to
 * the round macros instead of by explicit move instructions.
 */
.macro	load		index
	mov		(\index)*4(%rsi), %r10d
	bswap		%r10d
	mov		%r10d, (\index)*4(%rsp)
.endm

.macro	shuffle		index
	mov		((\index   )&0xf)*4(%rsp), %r10d
	xor		((\index- 3)&0xf)*4(%rsp), %r10d
	xor		((\index- 8)&0xf)*4(%rsp), %r10d
	xor		((\index-14)&0xf)*4(%rsp), %r10d
	rol		$1, %r10d
	mov		%r10d, ((\index)&0xf)*4(%rsp)
.endm

.macro	func1		a, b, c, d, e
	mov		\d, %r9d
	xor		\c, %r9d
	and		\b, %r9d
	xor		\d, %r9d
.endm

.macro	func2		a, b, c, d, e
	mov		\b, %r9d
	xor		\c, %r9d
	xor		\d, %r9d
.endm

.macro	func3		a, b, c, d, e
	mov		\b, %r8d
	or		\c, %r8d
	and		\d, %r8d
	mov		\b, %r9d
	and		\c, %r9d
	or		%r8d, %r9d
.endm

.macro	func4		a, b, c, d, e
	func2		\a, \b, \c, \d, \e
.endm

.macro	mix		a, b, c, d, e, const
	rol		$30, \b
	add		%r9d, \e
	mov		\a, %r8d
	rol		$5, %r8d
	lea		\const(\e, %r10d, 1), \e
	add		%r8d, \e
.endm

.macro	round1		a, b, c, d, e, index
	load		\index
	func1		\a, \b, \c, \d, \e
	mix		\a, \b, \c, \d, \e, 0x5a827999
.endm

.macro	round1x		a, b, c, d, e, index
	shuffle		\index
	func1		\a, \b, \c, \d, \e
	mix		\a, \b, \c, \d, \e, 0x5a827999
.endm

.macro	round2		a, b, c, d, e, index
	shuffle		\index
	func2		\a, \b, \c, \d, \e
	mix		\a, \b, \c, \d, \e, 0x6ed9eba1
.endm

.macro	round3		a, b, c, d, e, index
	shuffle		\index
	func3		\a, \b, \c, \d, \e
	mix		\a, \b, \c, \d, \e, 0x8f1bbcdc
.endm

.macro	round4		a, b, c, d, e, index
	shuffle		\index
	func4		\a, \b, \c, \d, \e
	mix		\a, \b, \c, \d, \e, 0xca62c1d6
.endm

	// sha1block(SHA1_CTX, buf, len)
ENTRY(sha1block)
	push		%rbp
	push		%rbx
	push		%r12
	push		%r13
	push		%r14
	push		%r15
	push		%rdi			// rdi: SHA1_CTX
	sub		$64+8, %rsp		// 64 bytes for round keys
						// plus alignment

	mov		%rdi, %rbp
						// rsi: buf
	and		$~63, %rdx		// rdx: length in blocks
	lea		(%rsi, %rdx, 1), %rdi	// rdi: end pointer
	mov		(%rbp),	%eax		// c->h0
	mov		4(%rbp), %ebx		// c->h1
	mov		8(%rbp), %ecx		// c->h2
	mov		12(%rbp), %edx		// c->h3
	mov		16(%rbp), %ebp		// c->h4

	cmp		%rsi, %rdi		// any data to process?
	je		.Lend

.Lloop:	mov		%eax, %r11d
	mov		%ebx, %r12d
	mov		%ecx, %r13d
	mov		%edx, %r14d
	mov		%ebp, %r15d

	round1		%eax, %ebx, %ecx, %edx, %ebp,  0
	round1		%ebp, %eax, %ebx, %ecx, %edx,  1
	round1		%edx, %ebp, %eax, %ebx, %ecx,  2
	round1		%ecx, %edx, %ebp, %eax, %ebx,  3
	round1		%ebx, %ecx, %edx, %ebp, %eax,  4

	round1		%eax, %ebx, %ecx, %edx, %ebp,  5
	round1		%ebp, %eax, %ebx, %ecx, %edx,  6
	round1		%edx, %ebp, %eax, %ebx, %ecx,  7
	round1		%ecx, %edx, %ebp, %eax, %ebx,  8
	round1		%ebx, %ecx, %edx, %ebp, %eax,  9

	round1		%eax, %ebx, %ecx, %edx, %ebp, 10
	round1		%ebp, %eax, %ebx, %ecx, %edx, 11
	round1		%edx, %ebp, %eax, %ebx, %ecx, 12
	round1		%ecx, %edx, %ebp, %eax, %ebx, 13
	round1		%ebx, %ecx, %edx, %ebp, %eax, 14

	round1		%eax, %ebx, %ecx, %edx, %ebp, 15
	round1x		%ebp, %eax, %ebx, %ecx, %edx, 16
	round1x		%edx, %ebp, %eax, %ebx, %ecx, 17
	round1x		%ecx, %edx, %ebp, %eax, %ebx, 18
	round1x		%ebx, %ecx, %edx, %ebp, %eax, 19

	round2		%eax, %ebx, %ecx, %edx, %ebp, 20
	round2		%ebp, %eax, %ebx, %ecx, %edx, 21
	round2		%edx, %ebp, %eax, %ebx, %ecx, 22
	round2		%ecx, %edx, %ebp, %eax, %ebx, 23
	round2		%ebx, %ecx, %edx, %ebp, %eax, 24

	round2		%eax, %ebx, %ecx, %edx, %ebp, 25
	round2		%ebp, %eax, %ebx, %ecx, %edx, 26
	round2		%edx, %ebp, %eax, %ebx, %ecx, 27
	round2		%ecx, %edx, %ebp, %eax, %ebx, 28
	round2		%ebx, %ecx, %edx, %ebp, %eax, 29

	round2		%eax, %ebx, %ecx, %edx, %ebp, 30
	round2		%ebp, %eax, %ebx, %ecx, %edx, 31
	round2		%edx, %ebp, %eax, %ebx, %ecx, 32
	round2		%ecx, %edx, %ebp, %eax, %ebx, 33
	round2		%ebx, %ecx, %edx, %ebp, %eax, 34

	round2		%eax, %ebx, %ecx, %edx, %ebp, 35
	round2		%ebp, %eax, %ebx, %ecx, %edx, 36
	round2		%edx, %ebp, %eax, %ebx, %ecx, 37
	round2		%ecx, %edx, %ebp, %eax, %ebx, 38
	round2		%ebx, %ecx, %edx, %ebp, %eax, 39

	round3		%eax, %ebx, %ecx, %edx, %ebp, 40
	round3		%ebp, %eax, %ebx, %ecx, %edx, 41
	round3		%edx, %ebp, %eax, %ebx, %ecx, 42
	round3		%ecx, %edx, %ebp, %eax, %ebx, 43
	round3		%ebx, %ecx, %edx, %ebp, %eax, 44

	round3		%eax, %ebx, %ecx, %edx, %ebp, 45
	round3		%ebp, %eax, %ebx, %ecx, %edx, 46
	round3		%edx, %ebp, %eax, %ebx, %ecx, 47
	round3		%ecx, %edx, %ebp, %eax, %ebx, 48
	round3		%ebx, %ecx, %edx, %ebp, %eax, 49

	round3		%eax, %ebx, %ecx, %edx, %ebp, 50
	round3		%ebp, %eax, %ebx, %ecx, %edx, 51
	round3		%edx, %ebp, %eax, %ebx, %ecx, 52
	round3		%ecx, %edx, %ebp, %eax, %ebx, 53
	round3		%ebx, %ecx, %edx, %ebp, %eax, 54

	round3		%eax, %ebx, %ecx, %edx, %ebp, 55
	round3		%ebp, %eax, %ebx, %ecx, %edx, 56
	round3		%edx, %ebp, %eax, %ebx, %ecx, 57
	round3		%ecx, %edx, %ebp, %eax, %ebx, 58
	round3		%ebx, %ecx, %edx, %ebp, %eax, 59

	round4		%eax, %ebx, %ecx, %edx, %ebp, 60
	round4		%ebp, %eax, %ebx, %ecx, %edx, 61
	round4		%edx, %ebp, %eax, %ebx, %ecx, 62
	round4		%ecx, %edx, %ebp, %eax, %ebx, 63
	round4		%ebx, %ecx, %edx, %ebp, %eax, 64

	round4		%eax, %ebx, %ecx, %edx, %ebp, 65
	round4		%ebp, %eax, %ebx, %ecx, %edx, 66
	round4		%edx, %ebp, %eax, %ebx, %ecx, 67
	round4		%ecx, %edx, %ebp, %eax, %ebx, 68
	round4		%ebx, %ecx, %edx, %ebp, %eax, 69

	round4		%eax, %ebx, %ecx, %edx, %ebp, 70
	round4		%ebp, %eax, %ebx, %ecx, %edx, 71
	round4		%edx, %ebp, %eax, %ebx, %ecx, 72
	round4		%ecx, %edx, %ebp, %eax, %ebx, 73
	round4		%ebx, %ecx, %edx, %ebp, %eax, 74

	round4		%eax, %ebx, %ecx, %edx, %ebp, 75
	round4		%ebp, %eax, %ebx, %ecx, %edx, 76
	round4		%edx, %ebp, %eax, %ebx, %ecx, 77
	round4		%ecx, %edx, %ebp, %eax, %ebx, 78
	round4		%ebx, %ecx, %edx, %ebp, %eax, 79

	add		%r11d, %eax
	add		%r12d, %ebx
	add		%r13d, %ecx
	add		%r14d, %edx
	add		%r15d, %ebp

	add		$64, %rsi
	cmp		%rdi, %rsi
	jb		.Lloop

.Lend:	add		$64+8, %rsp
	pop		%rdi			// SHA1_CTX
	mov		%eax, (%rdi)
	mov		%ebx, 4(%rdi)
	mov		%ecx, 8(%rdi)
	mov		%edx, 12(%rdi)
	mov		%ebp, 16(%rdi)

	pop		%r15
	pop		%r14
	pop		%r13
	pop		%r12
	pop		%rbx
	pop		%rbp
	ret
END(sha1block)

	.section .note.GNU-stack,"",%progbits
