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

#define ALIGN_TEXT	.p2align 4,0x90 /* 16-byte alignment, nop filled */

ARCHFUNCS(timingsafe_memcmp)
	ARCHFUNC(timingsafe_memcmp, scalar)
	ARCHFUNC(timingsafe_memcmp, baseline)
ENDARCHFUNCS(timingsafe_memcmp)

ARCHENTRY(timingsafe_memcmp, scalar)
	cmp	$16, %rdx		# at least 17 bytes to process?
	ja	.Lgt16

	cmp	$8, %edx		# at least 9 bytes to process?
	ja	.L0916

	cmp	$4, %edx		# at least 5 bytes to process?
	ja	.L0508

	cmp	$2, %edx		# at least 3 bytes to process?
	ja	.L0304

	test	%edx, %edx		# buffer empty?
	jnz	.L0102

	xor	%eax, %eax		# empty buffer always matches
	ret

.L0102:	movzbl	-1(%rdi, %rdx, 1), %eax	# load 1--2 bytes from first buffer
	movzbl	-1(%rsi, %rdx, 1), %ecx
	mov	(%rdi), %ah		# in big endian
	mov	(%rsi), %ch
	sub	%ecx, %eax
	ret

.L0304:	movzwl	-2(%rdi, %rdx, 1), %ecx
	movzwl	-2(%rsi, %rdx, 1), %edx
	movzwl	(%rdi), %eax
	movzwl	(%rsi), %esi
	bswap	%ecx			# convert to big endian
	bswap	%edx			# dito for edx, (e)ax, and (e)si
	rol	$8, %ax			# ROLW is used here so the upper two
	rol	$8, %si			# bytes stay clear, allowing us to
	sub	%edx, %ecx		# save a SBB compared to .L0508
	sbb	%esi, %eax
	or	%eax, %ecx		# nonzero if not equal
	setnz	%al
	ret

.L0508:	mov	-4(%rdi, %rdx, 1), %ecx
	mov	-4(%rsi, %rdx, 1), %edx
	mov	(%rdi), %edi
	mov	(%rsi), %esi
	bswap	%ecx			# compare in big endian
	bswap	%edx
	bswap	%edi
	bswap	%esi
	sub	%edx, %ecx
	sbb	%esi, %edi
	sbb	%eax, %eax		# -1 if less, 0 if greater or equal
	or	%edi, %ecx		# nonzero if not equal
	setnz	%al			# negative if <, 0 if =, 1 if >
	ret

.L0916:	mov	-8(%rdi, %rdx, 1), %rcx
	mov	-8(%rsi, %rdx, 1), %rdx
	mov	(%rdi), %rdi
	mov	(%rsi), %rsi
	bswap	%rcx			# compare in big endian
	bswap	%rdx
	bswap	%rdi
	bswap	%rsi
	sub	%rdx, %rcx
	sbb	%rsi, %rdi
	sbb	%eax, %eax		# -1 if less, 0 if greater or equal
	or	%rdi, %rcx		# nonzero if not equal
	setnz	%al			# negative if <, 0 if =, 1 if >
	ret

	/* compare 17+ bytes */
.Lgt16:	mov	(%rdi), %r8		# process first 16 bytes
	mov	(%rsi), %r9
	mov	$32, %ecx
	cmp	%r8, %r9		# mismatch in head?
	cmove	8(%rdi), %r8		# if not, try second pair
	cmove	8(%rsi), %r9
	cmp	%rdx, %rcx
	jae	.Ltail

	/* main loop processing 16 bytes per iteration */
	ALIGN_TEXT
0:	mov	-16(%rdi, %rcx, 1), %r10
	mov	-16(%rsi, %rcx, 1), %r11
	cmp	%r10, %r11		# mismatch in fist pair?
	cmove	-8(%rdi, %rcx, 1), %r10	# if not, try second pair
	cmove	-8(%rsi, %rcx, 1), %r11
	cmp	%r8, %r9		# was there a mismatch previously?
	cmove	%r10, %r8		# apply new pair if there was not
	cmove	%r11, %r9
	add	$16, %rcx
	cmp	%rdx, %rcx
	jb	0b

.Ltail:	mov	-8(%rdi, %rdx, 1), %r10
	mov	-8(%rsi, %rdx, 1), %r11
	cmp	%r8, %r9
	cmove	-16(%rdi, %rdx, 1), %r8
	cmove	-16(%rsi, %rdx, 1), %r9
	bswap	%r10			# compare in big endian
	bswap	%r11
	bswap	%r8
	bswap	%r9
	sub	%r11, %r10
	sbb	%r9, %r8
	sbb	%eax, %eax		# -1 if less, 0 if greater or equal
	or	%r10, %r8		# nonzero if not equal
	setnz	%al			# negative if <, 0 if =, 1 if >
	ret
ARCHEND(timingsafe_memcmp, scalar)

ARCHENTRY(timingsafe_memcmp, baseline)
	cmp	$16, %rdx		# at least 17 bytes to process?
	ja	.Lgt16b

	cmp	$8, %edx		# at least 9 bytes to process?
	ja	.L0916b

	cmp	$4, %edx		# at least 5 bytes to process?
	ja	.L0508b

	cmp	$2, %edx		# at least 3 bytes to process?
	ja	.L0304b

	test	%edx, %edx		# buffer empty?
	jnz	.L0102b

	xor	%eax, %eax		# empty buffer always matches
	ret

.L0102b:
	movzbl	-1(%rdi, %rdx, 1), %eax	# load 1--2 bytes from first buffer
	movzbl	-1(%rsi, %rdx, 1), %ecx
	mov	(%rdi), %ah		# in big endian
	mov	(%rsi), %ch
	sub	%ecx, %eax
	ret

.L0304b:
	movzwl	-2(%rdi, %rdx, 1), %ecx
	movzwl	-2(%rsi, %rdx, 1), %edx
	movzwl	(%rdi), %eax
	movzwl	(%rsi), %esi
	bswap	%ecx			# convert to big endian
	bswap	%edx			# dito for edx, (e)ax, and (e)si
	rol	$8, %ax			# ROLW is used here so the upper two
	rol	$8, %si			# bytes stay clear, allowing us to
	sub	%edx, %ecx		# save a SBB compared to .L0508
	sbb	%esi, %eax
	or	%eax, %ecx		# nonzero if not equal
	setnz	%al
	ret

.L0508b:
	mov	-4(%rdi, %rdx, 1), %ecx
	mov	-4(%rsi, %rdx, 1), %edx
	mov	(%rdi), %edi
	mov	(%rsi), %esi
	bswap	%ecx			# compare in big endian
	bswap	%edx
	bswap	%edi
	bswap	%esi
	sub	%edx, %ecx
	sbb	%esi, %edi
	sbb	%eax, %eax		# -1 if less, 0 if greater or equal
	or	%edi, %ecx		# nonzero if not equal
	setnz	%al			# negative if <, 0 if =, 1 if >
	ret

.L0916b:
	mov	-8(%rdi, %rdx, 1), %rcx
	mov	-8(%rsi, %rdx, 1), %rdx
	mov	(%rdi), %rdi
	mov	(%rsi), %rsi
	bswap	%rcx			# compare in big endian
	bswap	%rdx
	bswap	%rdi
	bswap	%rsi
	sub	%rdx, %rcx
	sbb	%rsi, %rdi
	sbb	%eax, %eax		# -1 if less, 0 if greater or equal
	or	%rdi, %rcx		# nonzero if not equal
	setnz	%al			# negative if <, 0 if =, 1 if >
	ret

	/* compare 17+ bytes */
.Lgt16b:
	movdqu		(%rdi), %xmm0
	movdqu		(%rsi), %xmm1
	mov		$32, %ecx
	movdqa		%xmm0, %xmm2
	pminub		%xmm1, %xmm0	# min(a, b)
	pcmpeqb		%xmm1, %xmm2	# a == b
	pcmpeqb		%xmm1, %xmm0	# b == min(a, b) -> a >= b
	pmovmskb	%xmm2, %eax	# bit set where a == b
	pmovmskb	%xmm0, %r8d	# bit set where a > b

	cmp		%rdx, %rcx	# enough left for a full iteration?
	jae		.Ltailb

	/* main loop processing 16 bytes per iteration */
	ALIGN_TEXT
0:	movdqu		-16(%rdi, %rcx, 1), %xmm0
	movdqu		-16(%rsi, %rcx, 1), %xmm1
	add		$16, %rcx
	movdqa		%xmm0, %xmm2
	pminub		%xmm1, %xmm0	# min(a, b)
	pcmpeqb		%xmm1, %xmm2	# a == b
	pcmpeqb		%xmm1, %xmm0	# b == min(a, b) -> a >= b
	pmovmskb	%xmm2, %r9d
	pmovmskb	%xmm0, %r10d
	cmp		$0xffff, %eax	# has there been a mismatch already?
	cmove		%r9d, %eax	# if not, perhaps in this iteration?
	cmove		%r10d, %r8d
	cmp		%rdx, %rcx
	jb		0b

.Ltailb:
	movdqu		-16(%rdi, %rdx, 1), %xmm0
	movdqu		-16(%rsi, %rdx, 1), %xmm1
	movdqa		%xmm0, %xmm2
	pminub		%xmm1, %xmm0	# min(a, b)
	pcmpeqb		%xmm1, %xmm2	# a == b
	pcmpeqb		%xmm1, %xmm0	# b == min(a, b) -> a >= b
	pmovmskb	%xmm2, %esi
	pmovmskb	%xmm0, %edi
	cmp		$0xffff, %eax	# has there been a mismatch already?
	cmove		%esi, %eax	# if not, perhaps in the tail?
	cmovne		%r8d, %edi

	/* turn data in eax, r8d into negative/zero/positive result */
	lea		1(%rax), %ecx
	xor		$0xffff, %eax	# bits set where there is a mismatch
	and		%ecx, %eax	# single bit for first mismatch or 0
	and		%eax, %edi	# single bit if first mismatch was >
	neg		%eax
	lea		(%rax, %rdi, 2), %eax # 2 * (a >= b) - (a != 0)
	ret
ARCHEND(timingsafe_memcmp, baseline)

	.section .note.GNU-stack,"",%progbits
