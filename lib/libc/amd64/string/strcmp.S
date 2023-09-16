/*-
 * Copyright (c) 2023, The FreeBSD Foundation
 *
 * SPDX-License-Expression: BSD-2-Clause
 *
 * Portions of this software were developed by Robert Clausecker
 * <fuz@FreeBSD.org> under sponsorship from the FreeBSD Foundation.
 *
 * Adapted from NetBSD's common/lib/libc/arch/x86_64/string/strcmp.S
 * written by J.T. Conklin <jtc@acorntoolworks.com> that was originally
 * dedicated to the public domain.
 */

#include <machine/asm.h>
#if 0
	RCSID("$NetBSD: strcmp.S,v 1.3 2004/07/19 20:04:41 drochner Exp $")
#endif

#include "amd64_archlevel.h"

#define ALIGN_TEXT	.p2align 4, 0x90

ARCHFUNCS(strcmp)
	ARCHFUNC(strcmp, scalar)
ENDARCHFUNCS(strcmp)

ARCHENTRY(strcmp, scalar)
	/*
	 * Align s1 to word boundary.
	 * Consider unrolling loop?
	 */
.Ls1align:
	testb	$7,%dil
	je	.Ls1aligned
	movb	(%rdi),%al
	incq	%rdi
	movb	(%rsi),%dl
	incq	%rsi
	testb	%al,%al
	je	.Ldone
	cmpb	%al,%dl
	je	.Ls1align
	jmp	.Ldone

	/*
	 * Check whether s2 is aligned to a word boundary.  If it is, we
	 * can compare by words.  Otherwise we have to compare by bytes.
	 */
.Ls1aligned:
	testb	$7,%sil
	jne	.Lbyte_loop

	movabsq	$0x0101010101010101,%r8
	subq	$8,%rdi
	movabsq	$0x8080808080808080,%r9
	subq	$8,%rsi

	ALIGN_TEXT
.Lword_loop:
	movq	8(%rdi),%rax
	addq	$8,%rdi
	movq	8(%rsi),%rdx
	addq	$8,%rsi
	cmpq	%rax,%rdx
	jne	.Lbyte_loop
	subq	%r8,%rdx
	notq	%rax
	andq	%rax,%rdx
	testq	%r9,%rdx
	je	.Lword_loop

	ALIGN_TEXT
.Lbyte_loop:
	movb	(%rdi),%al
	incq	%rdi
	movb	(%rsi),%dl
	incq	%rsi
	testb	%al,%al
	je	.Ldone
	cmpb	%al,%dl
	je	.Lbyte_loop

.Ldone:
	movzbq	%al,%rax
	movzbq	%dl,%rdx
	subq	%rdx,%rax
	ret
ARCHEND(strcmp, scalar)

	.section .note.GNU-stack,"",%progbits
