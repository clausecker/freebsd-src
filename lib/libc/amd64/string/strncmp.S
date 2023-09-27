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
#include <machine/param.h>

#include "amd64_archlevel.h"

#define ALIGN_TEXT	.p2align 4, 0x90

ARCHFUNCS(strncmp)
	ARCHFUNC(strncmp, scalar)
ENDARCHFUNCS(strncmp)

/*
 * This is just the scalar loop unrolled a bunch of times.
 */
ARCHENTRY(strncmp, scalar)
	xor	%eax, %eax
	sub	$4, %rdx	# 8 chars left to compare?
	jb	.Ltail

	ALIGN_TEXT
0:	movzbl	(%rdi), %ecx
	test	%ecx, %ecx	# NUL char in first string?
	jz	.L0
	cmpb	(%rsi), %cl	# mismatch between strings?
	jnz	.L0

	movzbl	1(%rdi), %ecx
	test	%ecx, %ecx
	jz	.L1
	cmpb	1(%rsi), %cl
	jnz	.L1

	movzbl	2(%rdi), %ecx
	test	%ecx, %ecx
	jz	.L2
	cmpb	2(%rsi), %cl
	jnz	.L2

	movzbl	3(%rdi), %ecx
	test	%ecx, %ecx
	jz	.L3
	cmpb	3(%rsi), %cl
	jnz	.L3

	add	$4, %rdi	# advance to next iteration
	add	$4, %rsi
	sub	$4, %rdx
	jae	0b

	/* end of string within the next 4 characters */
.Ltail:	jz	.Leq		# end of string reached immediately?
	movzbl	(%rdi), %ecx
	test	%ecx, %ecx
	jz	.L0
	cmpb	(%rsi), %cl
	jnz	.L0

	cmp	$-3, %edx	# end of string reached after 1 char?
	jz	.Leq
	movzbl	1(%rdi), %ecx
	test	%ecx, %ecx
	jz	.L1
	cmpb	1(%rsi), %cl
	jnz	.L1

	cmp	$-2, %edx
	jz	.Leq
	movzbl	2(%rdi), %ecx
	test	%ecx, %ecx
	jz	.L2
	cmpb	2(%rsi), %cl
	jnz	.L2

	cmp	$-1, %edx	# either end of string after 3 chars,
	jz	.Leq		# or it boils down to the last char

.L3:	inc	%eax
.L2:	inc	%eax
.L1:	inc	%eax
.L0:	movzbl	(%rsi, %rax, 1), %ecx
	movzbl	(%rdi, %rax, 1), %eax
	sub	%ecx, %eax
.Leq:	ret
ARCHEND(strncmp, scalar)

	.section .note.GNU-stack,"",%progbits
