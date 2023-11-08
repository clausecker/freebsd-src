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

	.weak stpncpy
	.set stpncpy, __stpncpy
ARCHFUNCS(__stpncpy)
	ARCHFUNC(__stpncpy, scalar)
	ARCHFUNC(__stpncpy, baselin)
ENDARCHFUNCS(__stpncpy)

ARCHENTRY(__stpncpy, scalar)
	ud2		// TODO
ARCHEND(__stpncpy, scalar)

/* stpncpy(char *restrict rdi, const char *rsi, size_t rdx) */
ARCHENTRY(__stpncpy, baseline)
	test		%rdx, %rdx		# no bytes to copy?
	jz		.L0

	mov		%esi, %ecx
	and		$~0xf, %rsi		# align source to 16 bytes
	movdqa		(%rsi), %xmm0		# load head
	and		$0xf, %ecx		# offset from alignment
	mov		$-1, %r9d
	shl		%cl, %r9d		# mask of bytes belonging to the string
	pxor		%xmm1, %xmm1
	movdqa		%xmm0, -4*16-8(%rsp)	# stash copy of head on the stack
	pcmpeqb		%xmm1, %xmm0
	pmovmskb	%xmm0, %r8d

	lea		(%rdx, %rcx, 1), %r10	# buffer length from alignment boundary
	cmp		$48, %r10		# less than 3 lanes to play with?
	jbe		.Lrunt			# if yes, use special runt processing

	sub		%rcx, %rdi		# make [RDI] correspond to [RSI]
	and		%r9d, %r8d		# end of string during head?
	jnz		.Lheadnul

	/* 3 lanes or more to copy (first may be incomplete) */
	movdqa		16(%rsi), %xmm0		# load second chunk from string
	movdqu		(%rsi, %rcx, 1), %xmm2	# load head of source from memory
	movdqu		%xmm2, (%rdi, %rcx, 1)	# and deposit into the destination
	movdqu		%xmm0, 16(%rdi)		# also deposit second chunk
	pcmpeqb		%xmm1, %xmm0		# NUL byte in second chunk?
	pmovmskb	%xmm0, %r8d
	test		%r8d, %r8d
	jnz		.Lsecondnul


	movdqa		32(%rsi), %xmm0		# load third chunk from string
	movdqu		%xmm0, 32(%rdi)		# and deposit into the destination	

	/* transform coordinates for further processing */
	add		%r10, %rsi		# end of source buffer
	add		%r10, %rdi		# end of destination buffer
	neg		%r10			# now RSI+RAX point to the beginning

	add		$32, %r10		# account for the bytes already processed
	movdqa			

	/* NUL byte found while processing head */
.Lheadnul:
	tzcnt		%r8d, %r8d		# location of NUL byte
	movdqu		-4*16-8(%rsp, %rcx, 1), %xmm0	# load head from bounce buffer
	movdqu		%xmm0, (%rdi, %rcx, 1)	# store head into destination buffer

	lea		(%rdi, %r8, 1), %rax	# point to the NUL byte
	add		%r10, %rdi		# point to end of buffer
	neg		%r10			# RDI[R10] points to beginning of buffer
	lea		16(%r10, %r8, 1), %r10	# RDI[R10-16] points to NUL byte


	/* fill the remaining destination with NUL bytes */
0:	movdqu		%xmm1, -16(%rdi, %r10, 1)
	add		$16, %r10
	jc		1f

	movdqu		%xmm1, -16(%rdi, %r10, 1)
	add		$16, %r10
	jnc		0b

1:	movdqu		%xmm1, -15(%rdi)	# clear last 15 bytes of buffer
	ret

	/* NUL byte found while processing the second chunk */
.Lsecondnul:
	tzcnt		%r8d, %r8d		# where is the NUL?
	lea		(%rdi, %r8, 1), %rax	# point to the NUL byte
	add		%r10, %rdi		# point to end of buffer
	neg		%r10			# RDI[RAX] points to beginning of buffer
	lea		32(%r10, %r8, 1), %r10	# RDI[RAX-16] points to NUL byte
	jmp		0b			# clear buffer with same loop as above	

	/* 1--32 bytes to copy, bounce through the stack */
.Lrunt:	dec		%r10d			# point to last char in xmm0
	movdqa		%xmm1, -3*16-8(%rsp)	# clear out rest of on-stack copy
	bts		%r10, %r8		# treat end of buffer as end of string
	movdqa		%xmm1, -2*16-8(%rsp)
	and		%r9w, %r8w		# end of string within first buffer?
	jnz		0f

	movdqa		16(%rsi), %xmm0		# load second chunk of input
	movdqa		%xmm0, -3*16-8(%rsp)	# stash copy on stack
	pcmpeqb		%xmm1, %xmm0		# NUL in second chunk?
	pmovmskb	%xmm0, %r8d
	sub		$16, %r10d		# point to last char in xmm0
	bts		%r10, %r8		# treat end of buffer as end of string
	test		$0xffff, %r8d		# end of string within second buffer?
	jnz		1f	

	/* third buffer must have end of string */
	movdqa		32(%rsi), %xmm0		# load third chunk of input
	movdqa		%xmm0, -2*16-8(%rsp)	# stash copy on stack
	pcmpeqb		%xmm1, %xmm0		# NUL in second chunk?
	pmovmskb	%xmm0, %r8d
	sub		$16, %r10d		# point to last char in xmm0
	bts		%r10, %r8		# mark end of buffer in xmm0
	shl		$16, %r8

	/* end of string after two buffers */
1:	shl		$16, %r8

	/* end of string after one buffer */
0:	tzcnt		%r8, %r8		# location of last char in string
	movdqa		%xmm1, -4*16-7(%rsp, %r8, 1) # clear bytes behind string
	cmpb		$0, (%rsi, %r8, 1)	# was the NUL byte copied?
	cmovne		%edx, %r8d		# if not, set length to all 
	lea		-4*16(%rsp, %rcx, 1), %rsi # start of string copy on stack
	lea		(%rdi, %r8), %rax	# return pointer to NUL byte or rdi[rdx]

	cmp	$32, %edx			# at least 32 bytes to transfer?
	jae	.L3247

	cmp	$16, %edx			# at least 16 bytes to transfer?
	jae	.L1631

	mov	(%rsi), %rcx			# load string head
	cmp	$8, %edx			# at least 8 bytes to transfer?
	jae	.L0815

	cmp	$4, %edx			# at least 4 bytes to transfer?
	jae	.L0407

	movzwl	-1(%rsi, %rdx, 1), %edx		# load last two bytes of string
	mov	%cl, (%rdi)			# store first byte

	cmp	$2, %edx			# at least 2 bytes to transfer?
	jb	.L1

	mov	%dx, -1(%rdi, %rdx, 1)		# store last two bytes of string
.L1:	ret

.L3247:	movdqu	16(%rsi), %xmm0			# copy middle 16 bytes of string
	movdqu	%xmm0, 16(%rdi)
.L1631:	movdqu	(%rsi), %xmm0			# load first 16 bytes of string
	movdqu	-15(%rsi, %rdx, 1), %xmm1	# load last 16 bytes of string
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, -15(%rdi, %rdx, 1)
	ret

.L0815:	mov	-7(%rsi, %rdx, 1), %rdx		# load last 8 bytes of string
	mov	%rcx, (%rdi)
	mov	%rdx, -7(%rdi, %rdx, 1)
	ret

.L0407:	mov	-3(%rsi, %rdx, 1), %edx		# load last four bytes of string
	mov	%ecx, (%rdi)
	mov	%edx, -3(%rdi, %rdx, 1)
	ret

	/* length 0 buffer: just return dest */
.L0:	mov	%rdi, %rax
	ret
ARCHEND(__stpncpy, baseline)

	.section .note.GNU-stack,"",%progbits
