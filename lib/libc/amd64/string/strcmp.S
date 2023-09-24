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
	mov		%esi, %edx
	mov		%edi, %eax
	and		$~0xf, %rsi	# align buffers to 16 bytes
	and		$~0xf, %rdi
	movdqa		(%rsi), %xmm1
	movdqa		(%rdi), %xmm0	# load aligned heads
	and		$0xf, %eax	# offset from alignment
	and		$0xf, %edx	# offset from alignment
	movdqa		%xmm1, -24(%rsp) # stash copies of (RSI) and (RSI)
	movdqa		%xmm0, -40(%rsp) # for use in runt cases
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
	cmp		%edx, %eax	# is (a&0xf) >= (b&0xf)
	jb		.Lswapped	# if yes, proceed with swapped operands

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

	sub		%rdi, %rsi	# express RSI as distance from RDI
	mov		%rsi, %rdx	# point RDX to offset in second string
	sub		%rax, %rdx	# corresponding to RDI in first string
	add		$16, %rdi	# advance aligned pointers

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
0:	movdqu		(%rdi, %rdx, 1), %xmm0 # chunk of 2nd string corresponding to RDI?
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
	movdqu		16(%rdi, %rdx, 1), %xmm0 # chunk of 2nd string corresponding to RDI?
	pxor		%xmm1, %xmm1
	pcmpeqb		16(%rdi, %rsi, 1), %xmm1 # end of string in RSI?
	pcmpeqb		16(%rdi), %xmm0	# where do the chunks match?
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	add		$32, %rdi
	test		%r8d, %r8d
	jnz		.Lnul_found2
	xor		$0xffff, %r9d	# any mismatches?
	jz		0b

	sub		$16, %rdi	# roll back second increment

	/* a mismatch has been found between RDX and RSI */
.Lmismatch:
	tzcnt		%r9d, %r9d	# where is the mismatch?
	add		%rdi, %rdx	# turn RDX from offset to pointer
	movzbl		(%rdx, %r9, 1), %ecx
	movzbl		(%rdi, %r9, 1), %eax
	sub		%ecx, %eax	# difference of the mismatching chars
	ret

.Lnul_found2:
	sub		$16, %rdi	# roll back second increment

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
	movdqu		(%rdi, %rax, 1), %xmm0
	pcmpeqb		(%rdi, %rsi, 1), %xmm0
	add		%rdi, %rsi	# restore RSI pointer
	add		%rax, %rdi	# advance RDI to correspond to RSI
	shr		%cl, %r10d	# turn RDI/RDX string mask into RSI string mask
	pmovmskb	%xmm0, %eax	# mask of matches
	not		%eax		# mask of mismatches
	and		%r10d, %eax	# mask of mismatches in string
	bsf		%eax, %ecx	# location of first mismatch
	cmovz		%eax, %ecx	# or 0 if there is none
	movzbl		(%rdi, %rcx, 1), %eax
	movzbl		(%rsi, %rcx, 1), %ecx
	sub		%ecx, %eax
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
	movdqu		-24(%rsp, %rdx, 1), %xmm1 # load RDI-aligned copy of RSI string
	lea		-1(%r10), %r11d
	xor		%r10d, %r11d		# characters not after end of string in RDI
	and		%r8d, %r11d		# characters in string in RDI
	pcmpeqb		%xmm1, %xmm0		# are the two strings identical?
	pmovmskb	%xmm0, %eax		# let's find out
	lea		-24(%rsp, %rdx, 1), %rsi
	not		%eax			# mismatches between the chunks
	and		%r11d, %eax		# mismatches between the string
	cmovz		%r11d, %eax		# or all chars in the string if no mismatch
	tzcnt		%eax, %eax		# location of first mismatch (or first char if none)
	movzbl		(%rsi, %rax, 1), %ecx	# characters at location of mismatch
	movzbl		(%rdi, %rax, 1), %eax
	sub		%ecx, %eax
	ret	

	/* RSI and RDI mismatch or end in the head */
.Learly_mismatch_or_nul:
	tzcnt		%r10d, %r10d		# offset of first mismatch or NUL from RDI
	add		%rax, %rdi		# address of 2nd string chunk corresponding to RDI
	movzbl		(%rsi, %r10, 1), %ecx
	movzbl		(%rdi, %r10, 1), %eax	# characters at location of mismatch
	sub		%ecx, %eax
	ret

	/*
	 * If (a&0xf) < (b&0xf), we do the same thing but with swapped
	 * operands.  I found that this performs slightly better than
	 * using conditional moves to do the swap branchless.
	 */
.Lswapped:
	pmovmskb	%xmm3, %r10d
	and		%r9d, %r10d	# EOS in first chunk of (RSI)?
	jnz		.Lrsi_runt

	sub		%rdx, %rax
	neg		%rax
	movdqu		(%rsi, %rax, 1), %xmm4	# chunk of first string corresponding to (RDI)
	pcmpeqb		%xmm0, %xmm4	# where do they match?
	pandn		%xmm4, %xmm2	# where do they match and are not NUL?
	pmovmskb	%xmm2, %r10d
	xor		$0xffff, %r10d	# where do they mismatch or are NUL?
	and		%r8d, %r10d	# ... within the first chunk of (RDI)?
	jnz		.Learly_mismatch_or_nuls

	sub		%rsi, %rdi	# express RDI as distance from RSI
	mov		%rdi, %rdx	# point RDX to offset in second string
	sub		%rax, %rdx	# corresponding to RSI in first string
	add		$16, %rsi	# advance aligned pointers

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
0:	movdqu		(%rsi, %rdx, 1), %xmm0 # chunk of 2nd string corresponding to RDI?
	pxor		%xmm1, %xmm1
	pcmpeqb		(%rsi, %rdi, 1), %xmm1 # end of string in RSI?
	pcmpeqb		(%rsi), %xmm0	# where do the chunks match?
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	test		%r8d, %r8d
	jnz		.Lnul_founds
	xor		$0xffff, %r9d	# any mismatches?
	jnz		.Lmismatchs

	/* main loop unrolled twice */
	movdqu		16(%rsi, %rdx, 1), %xmm0 # chunk of 2nd string corresponding to RDI?
	pxor		%xmm1, %xmm1
	pcmpeqb		16(%rsi, %rdi, 1), %xmm1 # end of string in RSI?
	pcmpeqb		16(%rsi), %xmm0	# where do the chunks match?
	pmovmskb	%xmm1, %r8d
	pmovmskb	%xmm0, %r9d
	add		$32, %rsi
	test		%r8d, %r8d
	jnz		.Lnul_found2s
	xor		$0xffff, %r9d	# any mismatches?
	jz		0b

	sub		$16, %rsi	# roll back second increment

	/* a mismatch has been found between RDX and RDI */
.Lmismatchs:
	tzcnt		%r9d, %r9d	# where is the mismatch?
	add		%rsi, %rdx	# turn RDX from offset to pointer
	movzbl		(%rdx, %r9, 1), %eax
	movzbl		(%rsi, %r9, 1), %ecx
	sub		%ecx, %eax	# difference of the mismatching chars
	ret

.Lnul_found2s:
	sub		$16, %rsi	# roll back second increment

	/* a NUL has been found in RSI */
.Lnul_founds:
	mov		%eax, %ecx
	shl		%cl, %r8d	# adjust NUL mask to positions in RDI/RDX
	lea		-1(%r8), %r10d
	xor		$0xffff, %r9d	# turn matches into mismatches
	xor		%r8d, %r10d	# all bytes in the string (including NUL)
	or		%r8d, %r9d	# NUL bytes also count as mismatches
	and		%r10w, %r9w	# was there a mismatch in the string?
	jnz		.Lmismatchs

	/*
	 * (RDI) == (RSI) and NUL is past the string.
	 * Compare (RDI) with the corresponding part
	 * of the other string until the NUL byte.
	 */
	movdqu		(%rsi, %rax, 1), %xmm0
	pcmpeqb		(%rsi, %rdi, 1), %xmm0
	add		%rsi, %rdi	# restore RSI pointer
	add		%rax, %rsi	# advance RDI to correspond to RSI
	shr		%cl, %r10d	# turn RDI/RDX string mask into RSI string mask
	pmovmskb	%xmm0, %eax	# mask of matches
	not		%eax		# mask of mismatches
	and		%r10d, %eax	# mask of mismatches in string
	bsf		%eax, %ecx	# location of first mismatch
	cmovz		%eax, %ecx	# or 0 if there is none
	movzbl		(%rdi, %rcx, 1), %eax
	movzbl		(%rsi, %rcx, 1), %ecx
	sub		%ecx, %eax
	ret

	/*
	 * RDI has an early NUL byte.  Due to the invariant established
	 * earlier, this means that either the other string must end
	 * before a 16 byte boundary, too, or the two strings have a
	 * mismatch before said boundary.  So it is sufficient to just
	 * compare these two prefixes.
	 */
.Lrsi_runt:
	sub		%rdx, %rax		# adjustment from RDI to RSI alignment
	movdqu		-40(%rsp, %rax, 1), %xmm0 # load RSI-aligned copy of RDI string
	lea		-1(%r10), %r11d
	xor		%r10d, %r11d		# characters not after end of string in RDI
	and		%r9d, %r11d		# characters in string in RDI
	pcmpeqb		%xmm1, %xmm0		# are the two strings identical?
	pmovmskb	%xmm0, %edx		# let's find out
	lea		-40(%rsp, %rax, 1), %rdi
	not		%edx			# mismatches between the chunks
	and		%r11d, %edx		# mismatches between the string
	cmovz		%r11d, %edx		# or all chars in the string if no mismatch
	tzcnt		%edx, %edx		# location of first mismatch (or first char if none)
	movzbl		(%rdi, %rdx, 1), %eax	# characters at location of mismatch
	movzbl		(%rsi, %rdx, 1), %ecx
	sub		%ecx, %eax
	ret	

	/* RSI and RDI mismatch or end in the head */
.Learly_mismatch_or_nuls:
	tzcnt		%r10d, %r10d		# offset of first mismatch or NUL from RDI
	add		%rax, %rsi		# address of 2nd string chunk corresponding to RDI
	movzbl		(%rsi, %r10, 1), %ecx
	movzbl		(%rdi, %r10, 1), %eax	# characters at location of mismatch
	sub		%ecx, %eax
	ret
ARCHEND(strcmp, baseline)

	.section .note.GNU-stack,"",%progbits
