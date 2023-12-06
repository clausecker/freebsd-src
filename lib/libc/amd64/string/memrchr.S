/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2023 Robert Clausecker
 */

#include <machine/asm.h>

#include "amd64_archlevel.h"

#define	ALIGN_TEXT	.p2align 4, 0x90

ARCHFUNCS(memrchr)
	ARCHFUNC(memrchr, scalar)
ENDARCHFUNCS(memrchr)

ARCHENTRY(memrchr, scalar)
	xor	%eax, %eax		# prospective return value
	sub	$4, %rdx		# 4 bytes left to process?
	jb	1f

	ALIGN_TEXT
0:	xor	%r8, %r8
	lea	2(%rdi), %r10
	cmp	%sil, 2(%rdi)
	cmovne	%r8, %r10		# point to null if no match

	cmp	%sil, (%rdi)
	cmove	%rdi, %r8		# point to first char if match

	lea	1(%rdi), %r9
	cmp	%sil, 1(%rdi)
	cmovne	%r8, %r9		# point to first result if no match in second

	lea	3(%rdi), %r11
	cmp	%sil, 3(%rdi)
	cmovne	%r10, %r11

	test	%r11, %r11
	cmovz	%r9, %r11		# take first pair match if none in second

	test	%r11, %r11
	cmovnz	%r11, %rax		# take match in current set if any

	add	$4, %rdi
	sub	$4, %rdx
	jae	0b

1:	cmp	$-3, %edx		# a least one character left to process?
	jb	2f

	cmp	%sil, (%rdi)
	cmove	%rdi, %rax

	lea	1(%rdi), %rcx
	cmp	$-2, %edx		# at least two characters left to process?
	jb	2f

	cmp	%sil, 1(%rdi)
	cmove	%rcx, %rax

	lea	2(%rdi), %rcx
	cmp	$-1, %edx		# at least three character left to process?
	jb	2f

	cmp	%sil, 2(%rdi)
	cmove	%rcx, %rax

2:	ret
ARCHEND(memrchr, scalar)

	.section	.note.GNU-stack, "", %progbits
