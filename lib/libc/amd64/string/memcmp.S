/*-
 * Copyright (c) 2018, 2023 The FreeBSD Foundation
 *
 * This software was developed by Mateusz Guzik <mjg@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
 *
 * Portions of this software were developed by Robert Clausecker
 * <fuz@FreeBSD.org> under sponsorship from the FreeBSD Foundation.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD$
 */

#include <machine/param.h>

#include <machine/asm.h>
__FBSDID("$FreeBSD$");

#include "amd64_archlevel.h"

/*
 * Note: this routine was written with kernel use in mind (read: no simd),
 * it is only present in userspace as a temporary measure until something
 * better gets imported.
 */

#define ALIGN_TEXT      .p2align 4,0x90 /* 16-byte alignment, nop filled */

#ifdef BCMP
#define memcmp bcmp
#endif

ARCHFUNCS(memcmp)
	ARCHFUNC(memcmp, scalar)
	ARCHFUNC(memcmp, baseline)
ENDARCHFUNCS(memcmp)

ARCHENTRY(memcmp, scalar)
	xorl	%eax,%eax
10:
	cmpq	$16,%rdx
	ja	101632f

	cmpb	$8,%dl
	jg	100816f

	cmpb	$4,%dl
	jg	100408f

	cmpb	$2,%dl
	jge	100204f

	cmpb	$1,%dl
	jl	100000f
	movzbl	(%rdi),%eax
	movzbl	(%rsi),%r8d
	subl	%r8d,%eax
100000:
	ret

	ALIGN_TEXT
100816:
	movq	(%rdi),%r8
	movq	(%rsi),%r9
	cmpq	%r8,%r9
	jne	80f
	movq	-8(%rdi,%rdx),%r8
	movq	-8(%rsi,%rdx),%r9
	cmpq	%r8,%r9
	jne	10081608f
	ret
	ALIGN_TEXT
100408:
	movl	(%rdi),%r8d
	movl	(%rsi),%r9d
	cmpl	%r8d,%r9d
	jne	80f
	movl	-4(%rdi,%rdx),%r8d
	movl	-4(%rsi,%rdx),%r9d
	cmpl	%r8d,%r9d
	jne	10040804f
	ret
	ALIGN_TEXT
100204:
	movzwl	(%rdi),%r8d
	movzwl	(%rsi),%r9d
	cmpl	%r8d,%r9d
	jne	1f
	movzwl	-2(%rdi,%rdx),%r8d
	movzwl	-2(%rsi,%rdx),%r9d
	cmpl	%r8d,%r9d
	jne	1f
	ret
	ALIGN_TEXT
101632:
	cmpq	$32,%rdx
	ja	103200f
	movq	(%rdi),%r8
	movq	(%rsi),%r9
	cmpq	%r8,%r9
	jne	80f
	movq	8(%rdi),%r8
	movq	8(%rsi),%r9
	cmpq	%r8,%r9
	jne	10163208f
	movq	-16(%rdi,%rdx),%r8
	movq	-16(%rsi,%rdx),%r9
	cmpq	%r8,%r9
	jne	10163216f
	movq	-8(%rdi,%rdx),%r8
	movq	-8(%rsi,%rdx),%r9
	cmpq	%r8,%r9
	jne	10163224f
	ret
	ALIGN_TEXT
103200:
	movq	(%rdi),%r8
	movq	8(%rdi),%r9
	subq	(%rsi),%r8
	subq	8(%rsi),%r9
	orq	%r8,%r9
	jnz	10320000f

	movq    16(%rdi),%r8
	movq    24(%rdi),%r9
	subq    16(%rsi),%r8
	subq    24(%rsi),%r9
	orq	%r8,%r9
	jnz     10320016f

	leaq	32(%rdi),%rdi
	leaq	32(%rsi),%rsi
	subq	$32,%rdx
	cmpq	$32,%rdx
	jae	103200b
	cmpb	$0,%dl
	jne	10b
	ret

/*
 * Mismatch was found.
 */
#ifdef BCMP
	ALIGN_TEXT
10320016:
10320000:
10081608:
10163224:
10163216:
10163208:
10040804:
80:
1:
	leal	1(%eax),%eax
	ret
#else
/*
 * We need to compute the difference between strings.
 * Start with narrowing the range down (16 -> 8 -> 4 bytes).
 */
	ALIGN_TEXT
10320016:
	leaq	16(%rdi),%rdi
	leaq	16(%rsi),%rsi
10320000:
	movq	(%rdi),%r8
	movq	(%rsi),%r9
	cmpq	%r8,%r9
	jne	80f
	leaq	8(%rdi),%rdi
	leaq	8(%rsi),%rsi
	jmp	80f
	ALIGN_TEXT
10081608:
10163224:
	leaq	-8(%rdi,%rdx),%rdi
	leaq	-8(%rsi,%rdx),%rsi
	jmp	80f
	ALIGN_TEXT
10163216:
	leaq	-16(%rdi,%rdx),%rdi
	leaq	-16(%rsi,%rdx),%rsi
	jmp	80f
	ALIGN_TEXT
10163208:
	leaq	8(%rdi),%rdi
	leaq	8(%rsi),%rsi
	jmp	80f
	ALIGN_TEXT
10040804:
	leaq	-4(%rdi,%rdx),%rdi
	leaq	-4(%rsi,%rdx),%rsi
	jmp	1f

	ALIGN_TEXT
80:
	movl	(%rdi),%r8d
	movl	(%rsi),%r9d
	cmpl	%r8d,%r9d
	jne	1f
	leaq	4(%rdi),%rdi
	leaq	4(%rsi),%rsi

/*
 * We have up to 4 bytes to inspect.
 */
1:
	movzbl	(%rdi),%eax
	movzbl	(%rsi),%r8d
	cmpb	%r8b,%al
	jne	2f

	movzbl	1(%rdi),%eax
	movzbl	1(%rsi),%r8d
	cmpb	%r8b,%al
	jne	2f

	movzbl	2(%rdi),%eax
	movzbl	2(%rsi),%r8d
	cmpb	%r8b,%al
	jne	2f

	movzbl	3(%rdi),%eax
	movzbl	3(%rsi),%r8d
2:
	subl	%r8d,%eax
	ret
#endif
ARCHEND(memcmp, scalar)

ARCHENTRY(memcmp, baseline)
	cmp		$32, %rdx		# enough to permit use of the long kernel?
	ja		.Llong

	test		%rdx, %rdx		# zero bytes buffer?
	je		.L0

	/*
	 * Compare strings of 1--32 bytes.  We want to do this by
	 * loading into two xmm registers and then comparing.  To avoid
	 * crossing into unmapped pages, we either load 32 bytes from
	 * the start of the buffer or 32 bytes before its end, depending
	 * on whether there is a page boundary between the overread area
	 * or not.
	 */

	/* check for page boundaries overreads */
	lea		32(%rdi), %eax		# end of overread
	lea		32(%rsi), %r8d
	lea		(%rdi, %rdx, 1), %ecx	# end of buffer
	lea		(%rsi, %rdx, 1), %r9d
	xor		%ecx, %eax
	xor		%r9d, %r8d
	test		$PAGE_SIZE, %eax	# did we cross a page?
	jz		0f

	/* fix up rdi */
	movdqu		-32(%rdi, %rdx, 1), %xmm0
	movdqu		-16(%rdi, %rdx, 1), %xmm1
	lea		-8(%rsp), %rdi		# end of replacement buffer
	sub		%rdx, %rdi		# start of replacement buffer
	movdqa		%xmm0, -40(%rsp)	# copy to replacement buffer
	movdqa		%xmm1, -24(%rsp)

0:	test		$PAGE_SIZE, %r8d
	jz		0f

	/* fix up rsi */
	movdqu		-32(%rsi, %rdx, 1), %xmm0
	movdqu		-16(%rsi, %rdx, 1), %xmm1
	lea		-40(%rsp), %rsi		# end of replacement buffer
	sub		%rdx, %rsi		# start of replacement buffer
	movdqa		%xmm0, -72(%rsp)	# copy to replacement buffer
	movdqa		%xmm1, -56(%rsp)

	/* load data and compare properly */
0:	movdqu		16(%rdi), %xmm1
	movdqu		16(%rsi), %xmm3
	movdqu		(%rdi), %xmm0
	movdqu		(%rsi), %xmm2
	mov		%edx, %ecx
	mov		$-1, %edx
	shl		%cl, %rdx		# ones where the buffer is not
	pcmpeqb		%xmm3, %xmm1
	pcmpeqb		%xmm2, %xmm0
	pmovmskb	%xmm1, %ecx
	pmovmskb	%xmm0, %eax
	shl		$16, %ecx
	or		%ecx, %eax		# ones where the buffers match
	or		%edx, %eax		# including where the buffer is not
	not		%eax			# ones where there is a mismatch
#ifndef BCMP
	bsf		%eax, %edx		# location of the first mismatch
	cmovz		%eax, %edx		# including if there is no mismatch
	movzbl		(%rdi, %rdx, 1), %eax	# mismatching bytes
	movzbl		(%rsi, %rdx, 1), %edx
	sub		%edx, %eax
#endif
	ret

	/* empty input */
.L0:	xor		%eax, %eax
	ret

	/* compare head for 33+ bytes */
	ALIGN_TEXT
.Llong:	movdqu		(%rdi), %xmm1
	movdqu		(%rsi), %xmm0
	mov		$16, %ecx
	pcmpeqb		%xmm1, %xmm0		# rdi[i] == rsi[i] for 0..15?
	pmovmskb	%xmm0, %eax		# mask of positions where this is the case
	xor		$0xffff, %eax		# any positions not equal?
	jnz		.Luneq1st

	/* align rdi to 16 bytes, then continue */
	mov		%edi, %eax
	add		$16, %ecx		# total string length we have checked after next iteration
	and		$0xf, %eax		# offset of RDI from alignment
	sub		%rax, %rcx		# -16(%rdi, %rcx, 1) is aligned

	/* main loop unrolled twice */
	ALIGN_TEXT
0:	movdqu		-16(%rsi, %rcx, 1), %xmm0
	lea		16(%rcx), %r8		# loop bound check to break dependency chain
	pcmpeqb		-16(%rdi, %rcx, 1), %xmm0 # all characters equal?
	pmovmskb	%xmm0, %eax		# mask of positions where this is the case
	xor		$0xffff, %eax		# any positions not equal?
	jnz		.Luneq1st
	cmp		%rdx, %r8		# 16 bytes left to compare for second half?
	ja		1f

	movdqu		(%rsi, %rcx, 1), %xmm0
	pcmpeqb		(%rdi, %rcx, 1), %xmm0
	add		$32, %rcx		# advance to next iteration
	pmovmskb	%xmm0, %eax
	xor		$0xffff, %eax
	jnz		.Luneq2nd
	cmp		%rdx, %rcx		# 16 bytes left for the next iteration?
	jbe		0b
	sub		$16, %rcx		# if not, go back to after first half

	/* less than 16 bytes left to compare, but total string length >=16 bytes */
1:	movdqu		-16(%rdi, %rdx, 1), %xmm1
	movdqu		-16(%rsi, %rdx, 1), %xmm0
	pcmpeqb		%xmm1, %xmm0
	pmovmskb	%xmm0, %eax
	xor		$0xffff, %eax
#ifndef BCMP
	bsf		%eax, %ecx		# find first mismatch
	cmovz		%eax, %ecx		# ensure ecx == 0 if no mismatch found
	add		%rcx, %rdx		# mismatch now at rdi[rdx-16] != rsi[rdx-16]
	movzbl		-16(%rsi, %rdx, 1), %ecx
	movzbl		-16(%rdi, %rdx, 1), %eax
	sub		%ecx, %eax
#endif /* ifndef(BCMP) */
	ret

	/* match found */
#ifdef BCMP
.Luneq2nd:
.Luneq1st:
	ret					# eax is guaranteed nonzero here
						# TODO: match return value of generic implementation?
#else /* memcmp */
.Luneq2nd:
	sub		$16, %rcx		# undo half the increment

.Luneq1st:
	tzcnt		%eax, %eax		# find first mismatch
	add		%rcx, %rax		# location of first mismatch
	movzbl		-16(%rsi, %rax, 1), %ecx
	movzbl		-16(%rdi, %rax, 1), %eax
	sub		%ecx, %eax
	ret
#endif /* ifdef(BCMP) */
ARCHEND(memcmp, baseline)

	.section .note.GNU-stack,"",%progbits
