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

ARCHFUNCS(timingsafe_bcmp)
	ARCHFUNC(timingsafe_bcmp, scalar)
ENDARCHFUNCS(timingsafe_bcmp)

ARCHENTRY(timingsafe_bcmp, scalar)
	cmp	$16, %rdx		# at least 17 bytes to process?
	jae	.Lgt16

	cmp	$8, %edx		# at least 9 bytes to process?
	jae	.L0916

	cmp	$4, %edx		# at least 5 bytes to process?
	jae	.L0508

	cmp	$2, %edx		# at least 3 bytes to process?
	jae	.L0304

	test	%edx, %edx		# buffer empty?
	jnz	.L0102

	xor	%eax, %eax		# empty buffer always matches
	ret

.L0102:	movzbl	(%rdi), %eax		# load 1--2 bytes from first buffer
	movzbl	-1(%rdi, %rdx, 1), %ecx
	xor	(%rsi), %al		# xor in second buffer
	xor	-1(%rsi, %rdx, 1), %cl
	or	%ecx, %eax		# mismatch in any of the two?
	ret

.L0304:	movzwl	(%rdi), %eax
	movzwl	-2(%rdi, %rdx, 1), %ecx
	xor	(%rsi), %ax
	xor	-2(%rsi, %rdx, 1), %cx
	or	%ecx, %eax
	ret

.L0508:	mov	(%rdi), %eax
	mov	-4(%rdi, %rdx, 1), %ecx
	xor	(%rsi), %eax
	xor	-4(%rsi, %rdx, 1), %ecx
	or	%ecx, %eax
	ret

.L0916:	mov	(%rdi), %rax
	mov	-8(%rdi, %rdx, 1), %rcx
	xor	(%rsi), %rax
	xor	-8(%rsi, %rdx, 1), %rcx
	or	%rcx, %rax
	setnz	%al			# ensure EAX nonzero even if only
	ret				# high bits of RAX were set

	/* more than 16 bytes: process buffer in a loop */
.Lgt16:	mov	(%rdi), %rax		# process first 16 bytes
	mov	8(%rdi), %r9
	mov	$32, %rcx
	xor	(%rsi), %rax
	xor	8(%rsi), %r9
	or	%r9, %rax

	cmp	%rdx, %rcx		# enough left for a full iteration?
	jae	.Ltail

	/* main loop processing 16 bytes per iteration */
	ALIGN_TEXT
0:	mov	-16(%rdi, %rcx, 1), %r8
	mov	-8(%rdi, %rcx, 1), %r9
	xor	-16(%rsi, %rcx, 1), %r8
	xor	-8(%rsi, %rcx, 1), %r9
	add	$16, %rcx
	or	%r9, %r8
	or	%r8, %rax

	cmp	%rdx, %rcx
	jb	0b

	/* process last 16 bytes */
.Ltail:	mov	-16(%rdi, %rdx, 1), %r8
	mov	-8(%rdi, %rdx, 1), %r9
	xor	-16(%rsi, %rdx, 1), %r8
	xor	-8(%rsi, %rdx, 1), %r9
	or	%r9, %r8
	or	%r8, %rax
	setnz	%al
	ret
ARCHEND(timingsafe_bcmp, scalar)

	.section .note.GNU-stack,"",%progbits
