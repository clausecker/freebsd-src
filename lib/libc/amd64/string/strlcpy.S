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

#define ALIGN_TEXT	.p2align 4, 0x90

	.weak strlcpy
	.set strlcpy, __strlcpy
ARCHFUNCS(__strlcpy)
	ARCHFUNC(__strlcpy, scalar)
//	ARCHFUNC(__strlcpy, baseline)
ENDARCHFUNCS(__strlcpy)

ARCHENTRY(__strlcpy, scalar)
	push	%rbp		# establish stack frame
	mov	%rsp, %rbp
	push	%rsi
	push	%rbx
	push	%rdi
	push	%rdx
	mov	%rsi, %rdi
	call	CNAME(strlen)	# strlen(src)
	pop	%rdx
	pop	%rdi
	mov	-8(%rbp), %rsi
	mov	%rax, %rbx	# remember string length for return value
	sub	$1, %rdx	# do not copy into the final byte of the buffer
	jc	0f		# skip copying altogether if buffer was empty
	cmp	%rax, %rdx	# is the buffer longer than the input?
	cmova	%rax, %rdx	# if yes, only copy the part that fits
	movb	$0, (%rdi, %rdx, 1) # NUL-terminate output buffer
	call	CNAME(memcpy)	# copy string to output
0:	mov	%rbx, %rax	# restore return value
	pop	%rbx
	leave
	ret
ARCHEND(__strlcpy, scalar)

	.section .note.GNU-stack,"",%progbits
