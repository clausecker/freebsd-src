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

#include <machine/asm.h>

#include "amd64_archlevel.h"

#define ALIGN_TEXT      .p2align 4,0x90 /* 16-byte alignment, nop filled */

        .weak memchr
        .set memchr, __memchr
ARCHFUNCS(__memchr)
	ARCHFUNC(__memchr, scalar)
//	ARCHFUNC(__memchr, baseline)
ENDARCHFUNCS(__memchr)

ARCHENTRY(__memchr, scalar)
	test	%rdx, %rdx	# empty input?
	je	.Lnomatch

	lea	(, %rdi, 8), %ecx
	add	%rdi, %rdx	# pointer to end of buffer
	and	$~7, %rdi	# align to 8 bytes
	mov	(%rdi), %rax	# load first word
	movzbl	%sil, %esi	# clear stray high bits
	movabs	$0x0101010101010101, %r8
	imul	%r8, %rsi	# replicate char 8 times

	/* compute head and tail masks */
	mov	%r8, %r10
	movabs	$0x8080808080808080, %r9
	shl	%cl, %r10	# 0x01 where string head is
	lea	(, %rdx, 8), %ecx
	xor	%r8, %r10	# 0x01 where it is not
	neg	%r8		# negate 01..01 so we can use lea
	mov	%r9, %r11
	xor	%rsi, %rax	# str ^ c (0x00 where str[i] == c)
	neg	%ecx
	or	%r10, %rax	# except before the string
	shr	%cl, %r11	# 0x80 where string tail is

	add	$8, %rdi	# advance to next 8 bytes
	cmp	%rdx, %rdi	# end of buffer reached during head?
	jae	.Ltail		# and go to tail-processing code

	/* main loop, unrolled twice */
	ALIGN_TEXT
0:	lea	(%rax, %r8, 1), %rcx # (str ^ c) - 0x01..01
	not	%rax		# ~(str ^ c)
	and	%r9, %rax	# ((str^c) - 0x01..01) & ~(str^c)
	and	%rcx, %rax	# not including junk bytes
	jnz	.Lmatch

	mov	(%rdi), %rax
	add	$8, %rdi
	xor	%rsi, %rax	# str ^ c
	cmp	%rdx, %rdi
	jae	.Ltail

	lea	(%rax, %r8, 1), %rcx # (str ^ c) - 0x01..01
	not	%rax		# ~(str ^ c)
	and	%r9, %rax	# ((str^c) - 0x01..01) & ~(str^c)
	and	%rcx, %rax	# not including junk bytes
	jnz	.Lmatch

	mov	(%rdi), %rax
	add	$8, %rdi
	xor	%rsi, %rax	# str ^ c
	cmp	%rdx, %rdi
	jb	0b

.Ltail:	lea	(%rax, %r8, 1), %rcx # (str ^ c) - 0x01..01
	not	%rax		# ~(str ^ c)
	and	%r11, %rax	# ((str^c) - 0x01..01) & ~(str^c)
	and	%rcx, %rax	# not including junk bytes or bytes past buffer
	jz	.Lnomatch

.Lmatch:
	tzcnt	%rax, %rax	# first match
	shr	$3, %eax	# scale from bit to byte index
	lea	-8(%rdi, %rax), %rax # pointer to found c
	ret

	/* no match found */
.Lnomatch:
	xor	%eax, %eax	# return null pointer
	ret
ARCHEND(__memchr, scalar)

ARCHENTRY(__memchr, baseline)
	ud2
ARCHEND(__memchr, baseline)

	.section .note.GNU-stack,"",%progbits
