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

#define ALIGN_TEXT	.p2align 4,0x90	# 16-byte alignment, nop-filled

	.weak	strchrnul
	.set	strchrnul, __strchrnul

ARCHFUNCS(__strchrnul)
        ARCHFUNC(__strchrnul, scalar)
ENDARCHFUNCS(__strchrnul)

/*
 * This is implemented like strlen(str, c), but we check for the
 * presence of both NUL and c in each iteration.
 */
ARCHENTRY(__strchrnul, scalar)
	movzbl	%sil, %esi		# clear stray high bits
	movabs	$0x0101010101010101, %r8
	movabs	$0x8080808080808080, %r9
	imul	%r8, %rsi		# replicate char 8 times
	xor	$-1, %r8		# negate 01..01 so we can use lea

	test	$7, %dil		# input already aligned?
	jz	1f

	mov	%edi, %ecx
	and	$~7, %rdi		# align to 8 bytes
	mov	(%rdi), %rax
	shl	$3, %ecx		# start of string in (%rdi) as number of bits
	mov	$-1, %rdx		# 0xff..ff to mask out undesired bits
	shl	%cl, %rdx		# 0xff where the string is
	not	%rdx			# 0xff where the string is not
	or	%rdx, %rax		# string with 0xff before it
	and	%r9, %rdx		# 0x80 where the string is not
	xor	%rax, %rdx		# string with 0x7f before it
	cmp	$0xff, %sil		# c == 0xff?
	cmove	%rdx, %rax		# if equal mask with 0x7f, else with 0xff
	jmp	0f

	/* main loop */
	ALIGN_TEXT
1:	mov	(%rdi), %rax		# str
0:	add	$8, %rdi
	mov	%rsi, %r10
	xor	%rax, %r10		# str ^ c
	lea	(%rax, %r8, 1), %rdx	# str - 0x01..01
	lea	(%r10, %r8, 1), %r11	# (str ^ c) - 0x01..01
	not	%rax			# ~str
	not	%r10			# ~(str ^ c)
	and	%r9, %rax		# ~str & 0x80..80
	and	%r9, %r10		# ~(str ^ c) & 0x80..80
	and	%rdx, %rax		# (str - 0x01..01) & ~str & 0x80..80
	and	%r11, %r10		# ((str ^ c - 0x01..01) & ~(str ^ c) & 0x80..80
	or	%r10, %rax		# NUL byte or c found?
	jz	1b

	/* NUL or c found */
2:	bsf	%rax, %rax		# first NUL or c byte match
	shr	$3, %eax		# scale from bit to byte index
	lea	-8(%rdi, %rax, 1), %rax	# pointer to found c or NUL
	ret
ARCHEND(__strchrnul, scalar)
