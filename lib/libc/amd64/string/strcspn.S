/*
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

#include <machine/asm.h>
#include <machine/param.h>

#include "amd64_archlevel.h"

#define ALIGN_TEXT	.p2align 4,0x90 /* 16-byte alignment, nop filled */

ARCHFUNCS(strcspn)
	ARCHFUNC(strcspn, scalar)
	NOARCHFUNC
	ARCHFUNC(strcspn, x86_64_v2)
ENDARCHFUNCS(strcspn)

	.section	.rodata
	.p2align	4
.Lbits:	.8byte		0x8040201008040201
	.8byte		0x8040201008040201

ARCHENTRY(strcspn, scalar)
	push	%rbp			# align stack to enable function call
	mov	%rsp, %rbp
	sub	$256, %rsp		# allocate space for lookup table

	/* check for special cases */
	movzbl	(%rsi), %eax		# first character in the set
	test	%eax, %eax
	jz	.Lstrlen

	movzbl	1(%rsi), %edx		# second character in the set
	test	%edx, %edx
	jz	.Lstrchr

	/* no special case matches -- prepare lookup table */
	xor	%r8d, %r8d
	mov	$28, %ecx
0:	mov	%r8, (%rsp, %rcx, 8)
	mov	%r8, 8(%rsp, %rcx, 8)
	mov	%r8, 16(%rsp, %rcx, 8)
	mov	%r8, 24(%rsp, %rcx, 8)
	sub	$4, %ecx
	jnc	0b

	add	$2, %rsi
	movb	$1, (%rsp, %rax, 1)	# register first chars in set
	movb	$1, (%rsp, %rdx, 1)
	mov	%rdi, %rax		# a copy of the source to iterate over

	/* process remaining chars in set */
	ALIGN_TEXT
0:	movzbl	(%rsi), %ecx
	movb	$1, (%rsp, %rcx, 1)
	test	%ecx, %ecx
	jz	1f

	movzbl	1(%rsi), %ecx
	movb	$1, (%rsp, %rcx, 1)
	test	%ecx, %ecx
	jz	1f

	add	$2, %rsi
	jmp	0b

	/* find match */
	ALIGN_TEXT
1:	movzbl	(%rax), %ecx
	cmpb	$0, (%rsp, %rcx, 1)
	jne	2f

	movzbl	1(%rax), %ecx
	cmpb	$0, (%rsp, %rcx, 1)
	jne	3f

	movzbl	2(%rax), %ecx
	cmpb	$0, (%rsp, %rcx, 1)
	jne	4f

	movzbl	3(%rax), %ecx
	add	$4, %rax
	cmpb	$0, (%rsp, %rcx, 1)
	je	1b

	sub	$3, %rax
4:	dec	%rdi
3:	inc	%rax
2:	sub	%rdi, %rax		# number of characters preceding match
	leave
	ret

	/* set is empty, degrades to strlen */
.Lstrlen:
	leave
	jmp	CNAME(strlen)

	/* just one character in set, degrades to strchr */
.Lstrchr:
	mov	%rdi, (%rsp)		# stash a copy of the string
	mov	%eax, %esi		# find the character in the set
	call	CNAME(strchrnul)
	sub	(%rsp), %rax		# length of prefix before match
	leave
	ret
ARCHEND(strcspn, scalar)

	/*
	 * This kernel uses pcmpistri to do the heavy lifting.
	 * We provide three code paths, depending on set size:
	 *
	 *      0: call strlen()
	 *      1: call strchr()
	 *    >=2: adapted from Muła/Langdale algorithm
	 *         http://0x80.pl/articles/simd-byte-lookup.html
	 */
ARCHENTRY(strcspn, x86_64_v2)
	push		%rbp
	mov		%rsp, %rbp
	sub		$32, %rsp

	/* check for special cases */
	movzbl		(%rsi), %eax
	test		%eax, %eax		# empty string?
	jz		.Lstrlenv2

	cmpb		$0, 1(%rsi)		# single character string?
	jz		.Lstrchrv2

	movdqa		.Lbits(%rip), %xmm6	# 0102..4080 x2

	/* clear out look up table */
	pxor		%xmm3, %xmm3
	movdqa		%xmm3, -32(%rbp)
	movdqa		%xmm3, -16(%rbp)

	/* build look up table */
	movb		$1, -32(%rbp)		# NUL is always in the set

	ALIGN_TEXT
0:	mov		%eax, %ecx
	and		$0xf, %eax		# low nibble
	shr		$4, %ecx		# high nibble
	mov		$1, %edx
	shl		%cl, %edx		# the bit we are interested in
	or		%dl, -32(%rbp, %rax, 1)	# apply bit to low LUT
	or		%dh, -16(%rbp, %rax, 1)	# apply bit to high LUT
	inc		%rsi
	movzbl		(%rsi), %eax
	test		%eax, %eax		# end of string?
	jnz		0b

	/* prepare for string */
	mov		%rdi, %rax		# retain copy of buffer pointer
	and		$~0xf, %rax		# align source to 16 bytes
	movdqa		(%rax), %xmm0		# load head of string
	movdqa		-32(%rbp), %xmm4	# low LUT
	movdqa		-16(%rbp), %xmm5	# high LUT
	pcmpeqb		%xmm7, %xmm7		# FFFF..FFFF x2
	pavgb		%xmm3, %xmm7		# 8080..8080 x2
	mov		%edi, %ecx
	and		$0xf, %ecx		# offset from alignment
	mov		$0xffff, %edx
	shl		%cl, %edx		# bits where the string is in xmm0
	add		$16, %rax		# advance to next iteration

	/* process head */
	movdqa		%xmm4, %xmm1		# low LUT copy
	movdqa		%xmm5, %xmm2		# high LUT copy
	pshufb		%xmm0, %xmm1		# look up high nibble masks of 0x--7x
	pxor		%xmm7, %xmm0		# flip sign bits
	pshufb		%xmm0, %xmm2		# look up high nibble masks of 8x--fx
	psrld		$4, %xmm0		# retrieve high nibbles
	por		%xmm2, %xmm1		# join high nibble masks
	movdqa		%xmm7, %xmm2		# 8080..8080 copy
	pandn		%xmm0, %xmm2		# fix up index for pshufb
	movdqa		%xmm6, %xmm0		# 0102..4080 copy
	pshufb		%xmm2, %xmm0		# 1 << (char >> 4 & 7)
	pand		%xmm0, %xmm1		# test if bits present
	pcmpeqb		%xmm0, %xmm1		# FF if match or 00 otherwise
	pmovmskb	%xmm1, %esi		# bit set if match
	and		%esi, %edx		# masked to bits in the string
	jnz		.Lheadmatchv2

	ALIGN_TEXT
0:	movdqa		(%rax), %xmm0
	movdqa		%xmm4, %xmm1		# low LUT copy
	movdqa		%xmm5, %xmm2		# high LUT copy
	add		$16, %rax
	pshufb		%xmm0, %xmm1		# look up high nibble masks of 0x--7x
	pxor		%xmm7, %xmm0		# flip sign bits
	pshufb		%xmm0, %xmm2		# look up high nibble masks of 8x--fx
	psrld		$4, %xmm0		# retrieve high nibbles
	por		%xmm2, %xmm1		# join high nibble masks
	movdqa		%xmm7, %xmm2		# 8080..8080 copy
	pandn		%xmm0, %xmm2		# fix up index for pshufb
	movdqa		%xmm6, %xmm0		# 0102..4080 copy
	pshufb		%xmm2, %xmm0		# 1 << (char >> 4 & 7)
	ptest		%xmm0, %xmm1		# any match?
	jz		0b

	pand		%xmm0, %xmm1		# compute match bitmask
	pcmpeqb		%xmm0, %xmm1		# FF where there is a match
	pmovmskb	%xmm1, %ecx
	sub		%rdi, %rax		# length of processed prefix + 16
	sub		$16, %rax		# length of processed prefix
	tzcnt		%ecx, %ecx		# location of first match in %xmm1
	add		%rcx, %rax
	leave
	ret

.Lheadmatchv2:
	tzcnt		%edx, %eax		# location of match in xmm0
	sub		%ecx, %eax		# location of match in string
	leave
	ret

	/* set is empty, degrades to strlen */
.Lstrlenv2:
	leave
	jmp	CNAME(strlen)

	/* just one character in set, degrades to strchr */
.Lstrchrv2:
	mov	%rdi, (%rsp)		# stash a copy of the string
	mov	%eax, %esi		# find this character
	call	CNAME(strchrnul)
	sub	(%rsp), %rax		# length of prefix before match
	leave
	ret
ARCHEND(strcspn, x86_64_v2)

	.section .note.GNU-stack,"",%progbits
