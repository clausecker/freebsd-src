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
	sub	$4, %rdx	# 4 chars left to compare?
	jbe	.Ltail

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
	ja	0b

	/* end of string within the next 4 characters */
.Ltail:	cmp	$-4, %edx	# end of string reached immediately?
	jz	.Leq
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

ARCHENTRY(strncmp, baseline)
	push		%rbx
	sub		$1, %rdx	# RDX--, so RDX points to the last byte to compare
	jb		.Lempty		# where there any bytes to compare at all?

	lea		15(%rdi), %r8d	# end of head
	lea		15(%rsi), %r9d
	mov		%edi, %eax
	mov		%esi, %ebx
	xor		%edi, %r8d	# bits that changed between first and last byte
	xor		%esi, %r9d
	and		$~0xf, %rdi	# align heads to 16 bytes
	and		$~0xf, %rsi
	or		%r8d, %r9d
	and		$0xf, %eax	# offset from alignment
	and		$0xf, %ebx
	movdqa		(%rdi), %xmm0	# load aligned heads
	movdqa		(%rsi), %xmm2
	pxor		%xmm1, %xmm1
	cmp		$16, %rdx	# end of buffer within the first 32 bytes?
	jb		.Llt16

	test		$PAGE_SIZE, %r9d # did the page change?
	jz		0f		# if not, take fast path


	/* heads may cross page boundary, avoid unmapped loads */
	movdqa		%xmm0, -32(%rsp) # stash copies of the heads on the stack
	movdqa		%xmm2, -16(%rsp)
	mov		$-1, %r8d
	mov		$-1, %r9d
	mov		%eax, %ecx
	shl		%cl, %r8d	# string head in XMM0
	mov		%ebx, %ecx
	shl		%cl, %r9d	# string head in XMM2
	pcmpeqb		%xmm1, %xmm0
	pcmpeqb		%xmm1, %xmm2
	pmovmskb	%xmm0, %r10d
	pmovmskb	%xmm2, %r11d
	test		%r8d, %r10d	# NUL byte present in first string?
	lea		-32(%rsp), %r8
	cmovz		%rdi, %r8
	test		%r9d, %r11d	# NUL byte present in second string?
	lea		-16(%rsp), %r9
	cmovz		%rsi, %r9
	movdqu		(%r8, %rax, 1), %xmm0 # load true (or fake) heads
	movdqu		(%r9, %rbx, 1), %xmm4
	jmp		1f

	/* rdx == 0 */
.Lempty:
	xor		%eax, %eax	# zero-length buffers compare equal
	pop		%rbx
	ret

0:	movdqu		(%rdi, %rax, 1), %xmm0 # load true heads
	movdqu		(%rsi, %rbx, 1), %xmm4
1:	pxor		%xmm2, %xmm2
	pcmpeqb		%xmm0, %xmm2	# NUL byte present?
	pcmpeqb		%xmm0, %xmm4	# which bytes match?
	pandn		%xmm4, %xmm2	# match and not NUL byte?
	pmovmskb	%xmm2, %r9d
	xor		$0xffff, %r9d	# mismatch or NUL byte?
	jnz		.Lhead_mismatch

	/* load head and second chunk */
	movdqa		16(%rdi), %xmm2	# load second chunks
	movdqa		16(%rsi), %xmm3
	sub		%rax, %rdx	# account for length of RDI chunk
	sub		%rbx, %rax	# is a&0xf >= b&0xf?
	jb		.Lswapped	# if not, proceed with swapped operands
	jmp		.Lnormal

	/* buffer ends within the first 16 bytes */
.Llt16:	test		$PAGE_SIZE, %r9d # did the page change?
	jz		0f		# if not, take fast path

	/* heads may cross page boundary */
	movdqa		%xmm0, -32(%rsp) # stash copies of the heads on the stack
	movdqa		%xmm2, -16(%rsp)
	mov		$-1, %r8d
	mov		$-1, %r9d
	mov		%eax, %ecx
	shl		%cl, %r8d	# string head in XMM0
	mov		%ebx, %ecx
	shl		%cl, %r9d	# string head in XMM2
	pcmpeqb		%xmm1, %xmm0
	pcmpeqb		%xmm1, %xmm2
	pmovmskb	%xmm0, %r10d
	pmovmskb	%xmm2, %r11d
	lea		(%rdx, %rax, 1), %ecx # location of last buffer byte in xmm0
	bts		%ecx, %r10d	# treat as if NUL byte present
	lea		(%rdx, %rbx, 1), %ecx
	bts		%ecx, %r11d
	test		%r8w, %r10w	# NUL byte present in first string head?
	lea		-32(%rsp), %r8
	cmovz		%rdi, %r8
	test		%r9w, %r11w	# NUL byte present in second string head?
	lea		-16(%rsp), %r9
	cmovz		%rsi, %r9
	movdqu		(%r8, %rax, 1), %xmm0 # load true (or fake) heads
	movdqu		(%r9, %rbx, 1), %xmm4
	jmp		1f

0:	movdqu		(%rdi, %rax, 1), %xmm0 # load true heads
	movdqu		(%rsi, %rbx, 1), %xmm4
1:	pxor		%xmm2, %xmm2
	pcmpeqb		%xmm0, %xmm2	# NUL byte present?
	pcmpeqb		%xmm0, %xmm4	# which bytes match?
	pandn		%xmm4, %xmm2	# match and not NUL byte?
	pmovmskb	%xmm2, %r9d
	btr		%edx, %r9d	# induce mismatch in last byte of buffer
	xor		$0xffff, %r9d	# mismatch or NUL byte?

	/* mismatch in true heads */
.Lhead_mismatch:
	tzcnt		%r9d, %r9d	# where is the mismatch?
	add		%rax, %rdi	# return to true heads
	add		%rbx, %rsi
	movzbl		(%rdi, %r9, 1), %eax # mismatching characters
	movzbl		(%rsi, %r9, 1), %ecx
	sub		%ecx, %eax
	pop		%rbx
	ret

	/* rax >= 0 */
.Lnormal:
	lea		-16(%rdx, %rax, 1), %rdx # RDX points to buffer end in RSI
	neg		%rax
	movdqu		16(%rsi, %rax, 1), %xmm0
	sub		%rdi, %rsi	# express RSI as distance from RDI
	lea		(%rsi, %rax, 1), %rbx # point RBX to offset in second string
	neg		%rax		# ... corresponding to RDI
	pcmpeqb		%xmm3, %xmm1	# mismatch between chunks?
	pcmpeqb		%xmm2, %xmm0	# NUL present?
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	mov		$16, %ecx
	cmp		%rcx, %rdx	# does the buffer end within (RDI,RSI,1)?
	cmovb		%edx, %ecx	# ECX = min(16, RDX)
	add		$16, %rdi
	bts		%ecx, %r8d	# mark end-of-buffer as if there was a NUL byte
	test		%r8w, %r8w	# NUL or end of buffer found?
	jnz		.Lnul_found
	xor		$0xffff, %r9d
	jnz		.Lmismatch
	add		$16, %rdi	# advance aligned pointers
	sub		$48, %rdx	# end of buffer within first main loop iteration?
	jb		.Ltail		# if yes, process tail

	/*
	 * During the main loop, the layout of the two strings is something like:
	 *
	 *          v ------1------ v ------2------ v
	 *     RDI:    AAAAAAAAAAAAABBBBBBBBBBBBBBBB...
	 *     RSI: AAAAAAAAAAAAABBBBBBBBBBBBBBBBCCC...
	 *
	 * where v indicates the alignment boundaries and corresponding chunks
	 * of the strings have the same letters.  Chunk A has been checked in
	 * the previous iteration.  This iteration, we first check that string
	 * RSI doesn't end within region 2, then we compare chunk B between the
	 * two strings.  As RSI is known not to hold a NUL byte in regsions 1
	 * and 2 at this point, this also ensures that RDI has not ended yet.
	 */
	ALIGN_TEXT
0:	movdqu		(%rdi, %rbx, 1), %xmm0 # chunk of 2nd string correspodning to RDI
	pxor		%xmm1, %xmm1
	pcmpeqb		(%rdi, %rsi, 1), %xmm1 # end of string in RSI?
	pcmpeqb		(%rdi), %xmm0	# where do the chunks match?
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	test		%r8d, %r8d
	jnz		.Lnul_found
	xor		$0xffff, %r9d	# any mismatches?
	jnz		.Lmismatch

	/* main loop unrolled twice */
	movdqu		16(%rdi, %rbx, 1), %xmm0
	pxor		%xmm1, %xmm1
	pcmpeqb		16(%rdi, %rsi, 1), %xmm1
	pcmpeqb		16(%rdi), %xmm0
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	add		$32, %rdi
	test		%r8d, %r8d
	jnz		.Lnul_found2
	xor		$0xffff, %r9d
	jnz		.Lmismatch2
	sub		$32, %rdx	# end of buffer within next iteration?
	jae		0b

	/* end of buffer will occur in next 32 bytes */
.Ltail:	...

.Lmismatch2:
	sub		$16, %rdi

.Lmismatch:
	...

.Lnul_found2:
	sub		$16, %rdi

.Lnul_found:
	...

	/* rax < 0 */
.Lswapped:
	...
ARCHEND(strncmp, baseline)
	
	.section .note.GNU-stack,"",%progbits
