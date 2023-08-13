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

#include "amd64_archlevel.h"

#define ALIGN_TEXT	.p2align 4,0x90 /* 16-byte alignment, nop filled */

ARCHFUNCS(strcspn)
	ARCHFUNC(strcspn, scalar)
ENDARCHFUNCS(strcspn)

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

	.section .note.GNU-stack,"",%progbits
