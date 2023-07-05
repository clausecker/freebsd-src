/*-
 * Adapted by Guillaume Morin <guillaume@morinfr.org> from strcpy.S
 * written by J.T. Conklin <jtc@acorntoolworks.com>
 * Copyright (c) 2023 The FreeBSD Foundation
 *
 * Portions of this software were developed by Robert Clausecker
 * <fuz@FreeBSD.org> under sponsorship from the FreeBSD Foundation.
 *
 * Public domain.
 */

#include <machine/asm.h>
__FBSDID("$FreeBSD$");

#include "amd64_archlevel.h"

#define ALIGN_TEXT	.p2align 4, 0x90

	.weak stpcpy
	.set stpcpy, __stpcpy
ARCHFUNCS(__stpcpy)
	ARCHFUNC(__stpcpy, scalar)
	ARCHFUNC(__stpcpy, baseline)
ENDARCHFUNCS(__stpcpy)

/*
 * This stpcpy implementation copies a byte at a time until the
 * source pointer is aligned to a word boundary, it then copies by
 * words until it finds a word containing a zero byte, and finally
 * copies by bytes until the end of the string is reached.
 *
 * While this may result in unaligned stores if the source and
 * destination pointers are unaligned with respect to each other,
 * it is still faster than either byte copies or the overhead of
 * an implementation suitable for machines with strict alignment
 * requirements.
 */

ARCHENTRY(__stpcpy, scalar)
	movabsq $0x0101010101010101,%r8
	movabsq $0x8080808080808080,%r9

	/*
	 * Align source to a word boundary.
	 * Consider unrolling loop?
	 */
.Lalign:
	testb	$7,%sil
	je	.Lword_aligned
	movb	(%rsi),%dl
	incq	%rsi
	movb	%dl,(%rdi)
	incq	%rdi
	testb	%dl,%dl
	jne	.Lalign
	movq	%rdi,%rax
	dec	%rax
	ret

	ALIGN_TEXT
.Lloop:
	movq	%rdx,(%rdi)
	addq	$8,%rdi
.Lword_aligned:
	movq	(%rsi),%rdx
	movq	%rdx,%rcx
	addq	$8,%rsi
	subq	%r8,%rcx
	testq	%r9,%rcx
	je	.Lloop

	/*
	 * In rare cases, the above loop may exit prematurely. We must
	 * return to the loop if none of the bytes in the word equal 0.
	 */

	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 1st byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 2nd byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 3rd byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 4th byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 5th byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 6th byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	testb	%dl,%dl		/* 7th byte == 0? */
	je	.Ldone
	incq	%rdi

	shrq	$8,%rdx
	movb	%dl,(%rdi)
	incq	%rdi
	testb	%dl,%dl		/* 8th byte == 0? */
	jne	.Lword_aligned
	decq	%rdi

.Ldone:
	movq	%rdi,%rax
	ret
ARCHEND(__stpcpy, scalar)

ARCHENTRY(__stpcpy, baseline)
	mov	%esi, %ecx
	mov	%rdi, %rdx
	sub	%rsi, %rdi		# express destination as distance to surce
	pxor	%xmm1, %xmm1
	and	$~0xf, %rsi		# align source to 16 byte
	and	$0xf, %ecx		# misalignment in bytes

	movdqa	(%rsi), %xmm0
	pcmpeqb	%xmm1, %xmm0		# NUL byte present?
	pmovmskb %xmm0, %eax
	shr	%cl, %eax		# clear out matches in junk bytes
	bsf	%eax, %eax		# any match?
	jnz	.Lrunt

	/* first iteration: write head back if it succeeds */
	movdqa	16(%rsi), %xmm0		# 16 bytes of current iteration
	movdqu	(%rsi, %rcx, 1), %xmm2	# first 16 bytes of the string
	pxor	%xmm1, %xmm1
	pcmpeqb	%xmm0, %xmm1		# NUL byte present?
	pmovmskb %xmm0, %eax
	test	%eax, %eax
	jnz	.Lshorty

	movdqu	%xmm2, (%rdx)		# store beginning of string
	add	$16, %rsi		# advance to next iteration

	/* main loop */
	ALIGN_TEXT
0:	movdqu	%xmm0, (%rsi, %rdi, 1) # write back previous iteraion
	movdqa	16(%rsi), %xmm0		# load current iteraion
	pxor	%xmm1, %xmm1
	add	$16, %rsi
	pcmpeqb	%xmm0, %xmm1		# NUL byte present?
	pmovmskb %xmm0, %eax
	test	%eax, %eax
	jz	0b

	/* end of string after main loop has iterated */
	tzcnt	%eax, %eax
	add	%rsi, %rax		# point to NUL byte
	movdqu	-15(%rax), %xmm0	# last 16 bytes of string
	movdqu	%xmm0, -15(%rax, %rdi, 1) # copied to destination
	add	%rdi, %rax		# point to destination's NUL byte
	ret

	/* string spans two 16-byte lanes and is 2--32 bytes long */
.Lshorty:
	bsf	%eax, %eax		# bytes in second lane before NUL byte
	add	$16, %eax		# bytes in both lanes before NUL byte
	sub	%ecx, %eax		# LEN-1
	cmp	$16, %eax
	jbe	.Lrunt			# if less than 16 bytes, use runt logic

	/* string has 16--32 bytes: use two overlapping 16-byte moves */
	add	%rax, %rcx
	movdqu	-15(%rsi, %rcx, 1), %xmm0 # last 16 bytes of string
	movdqu	%xmm2, (%rdx)		# deposit first 16 bytes of string
	movdqu	%xmm0, -15(%rdx, %rax, 1) # deposit last 16 bytes of string
	ret

	/* runt: string has 1--16 bytes */
.Lrunt:	add	%rcx, %rsi		# pointer to beginning of string
	cmp	$8, %eax		# copy with two overlapping moves if possible
	jb	1f

	/* 8--16 bytes to copy: use two overlapping 8-byte moves */
	mov	(%rsi), %rcx		# load first 8 bytes of string
	mov	%rcx, (%rdx)		# deposit 8 bytes into output
	mov	-7(%rsi, %rax, 1), %rcx	# load last 8 bytes of string
	mov	%rcx, -7(%rdx, %rax, 1)	# and deposit
	add	%rdx, %rax		# point to NUL byte in dst
	ret

	/* 1--7 bytes to copy: use a move sled */
1:	add	%rax, %rsi		# pointer to NUL byte in src
	shl	$3, %eax		# 8*(LEN - 1)
	lea	2f(%rip), %rdx		# pointer to copy 1 bytes
	sub	%rax, %rdx		# pointer to copy LEN bytes
	jmp	*%rdx

#define MOVE(offset) \
	.p2align 3; \
	movzbl	offset(%rsi), %eax; \
	mov	%al, offset(%rsi, %rdi, 1)

	/* move slide: each entry copies 1 byte and is 8 bytes long */
	MOVE(-7)
	MOVE(-6)
	MOVE(-5)
	MOVE(-4)
	MOVE(-3)
	MOVE(-2)
	MOVE(-1)
2:	MOVE(0)

	lea	(%rsi, %rdi, 1), %rax	# pointer to NUL byte in dst
	ret
ARCHEND(__stpcpy, baseline)
	
	.section .note.GNU-stack,"",%progbits
