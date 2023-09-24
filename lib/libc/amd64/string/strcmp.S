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
	ARCHFUNC(strcmp, baseline)
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

ARCHENTRY(strcmp, baseline)
	mov		%edi, %eax
	mov		%esi, %edx
	and		$0xf, %eax	# offset from alignment
	and		$0xf, %edx	# offset from alignment
	and		$~0xf, %rdi	# align buffers to 16 bytes
	and		$~0xf, %rsi

	/* ensure RDI has alignment offset greater-than or equal to RSI's offset */
	mov		%eax, %ecx
	mov		%rdi, %r8
	cmp		%edx, %eax	# is (a&0xf) >= (b&0xf)?
	cmovb		%rsi, %rdi	# if not, swap RDI and RSI
	cmovb		%r8, %rsi
	cmovb		%edx, %eax	# as well as EAX and EDX
	cmovb		%ecx, %edx
	sbb		%ecx, %ecx	# EAX >= EDX ? 0 : -1

	movdqa		(%rsi), %xmm1
	movdqa		(%rdi), %xmm0	# load aligned heads

	push		%rcx		# free ECX for shift amounts
	movdqu		%xmm1, -16(%rsp) # stash a copy of (RSI) for use in runt cases
	mov		$-1, %r8d
	mov		$-1, %r9d
	pxor		%xmm2, %xmm2
	pxor		%xmm3, %xmm3
	mov		%eax, %ecx
	shl		%cl, %r8d	# bits in XMM0 that are part of the string
	mov		%edx, %ecx
	shl		%cl, %r9d	# bits in XMM1 that are part of the string
	pcmpeqb		%xmm0, %xmm2	# NUL byte present in first string?
	pcmpeqb		%xmm1, %xmm3	# NUL byte present in second string?
	pmovmskb	%xmm2, %r10d
	and		%r8d, %r10d	# EOS in first chunk of (RDI)?
	jnz		.Lrdi_runt

	sub		%rdx, %rax
	movdqu		(%rdi, %rax, 1), %xmm4	# chunk of first string corresponding to (RSI)
	pcmpeqb		%xmm1, %xmm4	# where do they match?
	pandn		%xmm4, %xmm3	# where do they match and are not NUL?
	pmovmskb	%xmm3, %r10d
	xor		$0xffff, %r10d	# where do they mismatch or are NUL?
	and		%r9d, %r10d	# ... within the first chunk of (RSI)?
	jnz		.Learly_mismatch_or_nul

	lea		16(%rsi), %rdx	# point RDX to offset in second string
	sub		%rax, %rdx	# corresponding to RDI+16 in first string
	add		$16, %rdi	# advance aligned pointers
	add		$16, %rsi

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
0:	movdqu		(%rdx), %xmm0	# chunk of 2nd string corresponding to RDI?
	pxor		%xmm1, %xmm1
	pcmpeqb		(%rsi), %xmm1	# end of string in RSI?
	pcmpeqb		(%rdi), %xmm0	# where do the chunks match?
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	add		$16, %rdx
	add		$16, %rsi
	add		$16, %rdi
	test		%r8d, %r8d
	jnz		.Lnul_found
	xor		$0xffff, %r9d	# any mismatches?
	jz		0b

	/* a mismatch has been found between RDX and RSI */
.Lmismatch:
	tzcnt		%r9d, %r9d	# where is the mismatch?
	movzbl		-16(%rdx, %r9, 1), %ecx
	movzbl		-16(%rdi, %r9, 1), %eax
	pop		%rdx		# string swap indicator
	sub		%ecx, %eax	# difference of the mismatching chars
	xor		%edx, %eax	# negate difference if strings were swapped
	sub		%edx, %eax
	ret

	/* a NUL has been found in RSI */
.Lnul_found:
	mov		%eax, %ecx
	shl		%cl, %r8d	# adjust NUL mask to positions in RDI/RDX
	lea		-1(%r8), %r10d
	xor		$0xffff, %r9d	# turn matches into mismatches
	xor		%r8d, %r10d	# all bytes in the string (including NUL)
	or		%r8d, %r9d	# NUL bytes also count as mismatches
	and		%r10w, %r9w	# was there a mismatch in the string?
	jnz		.Lmismatch

	/*
	 * (RDI) == (RSI) and NUL is past the string.
	 * Compare (RSI) with the corresponding part
	 * of the other string until the NUL byte.
	 */
	movdqu		-16(%rdi, %rax, 1), %xmm0
	pcmpeqb		-16(%rsi), %xmm0
	add		%rax, %rdi	# advance RDI to correspond to RSI
	shr		%cl, %r10d	# turn RDI/RDX string mask into RSI string mask
	pmovmskb	%xmm0, %eax	# mask of matches
	not		%eax		# mask of mismatches
	and		%r10d, %eax	# mask of mismatches in string
	bsf		%eax, %ecx	# location of first mismatch
	cmovz		%eax, %ecx	# or 0 if there is none
	movzbl		-16(%rdi, %rcx, 1), %eax
	movzbl		-16(%rsi, %rcx, 1), %ecx
	pop		%rdx		# string swap indicator
	sub		%ecx, %eax
	xor		%edx, %eax
	sub		%edx, %eax
	ret

	/*
	 * RDI has an early NUL byte.  Due to the invariant established
	 * earlier, this means that either the other string must end
	 * before a 16 byte boundary, too, or the two strings have a
	 * mismatch before said boundary.  So it is sufficient to just
	 * compare these two prefixes.
	 */
.Lrdi_runt:
	sub		%rax, %rdx		# adjustment from RSI to RDI alignment
	movdqu		-16(%rsp, %rdx, 1), %xmm1 # load RDI-aligned copy of RSI strin
	lea		-1(%r10), %r11d
	xor		%r10d, %r11d		# characters not after end of string in RDI
	and		%r8d, %r11d		# characters in string in RDI
	pcmpeqb		%xmm1, %xmm0		# are the two strings identical?
	pmovmskb	%xmm0, %eax		# let's find out
	lea		-16(%rsp, %rdx, 1), %rsi
	not		%eax			# mismatches between the chunks
	and		%r11d, %eax		# mismatches between the string
	cmovz		%r11d, %eax		# or all chars in the string if no mismatch
	tzcnt		%eax, %eax		# location of first mismatch (or first char if none)
	movzbl		(%rsi, %rax, 1), %ecx	# characters at location of mismatch
	movzbl		(%rdi, %rax, 1), %eax
	pop		%rdx			# string swap indicator
	sub		%ecx, %eax
	xor		%edx, %eax
	sub		%edx, %eax
	ret	

	/* RSI and RDI mismatch or end in the head */
.Learly_mismatch_or_nul:
	tzcnt		%r10d, %r10d		# offset of first mismatch or NUL from RDI
	lea		(%rdi, %rax, 1), %rdi	# address of 2nd string chunk corresponding to RDI
	movzbl		(%rsi, %r10, 1), %ecx
	movzbl		(%rdi, %r10, 1), %eax	# characters at location of mismatch
	pop		%rdx			# string swap indicator
	sub		%ecx, %eax
	xor		%edx, %eax
	sub		%edx, %eax
	ret
ARCHEND(strcmp, baseline)

	.section .note.GNU-stack,"",%progbits
