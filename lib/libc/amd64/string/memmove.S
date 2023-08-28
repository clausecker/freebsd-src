/*-
 * Copyright (c) 2014, Intel Corporation
 * Copyright (c) 2018, 2023 The FreeBSD Foundation
 * All rights reserved.
 *
 * Portions of this software were developed by Mateusz Guzik <mjg@FreeBSD.org>
 * and Robert Clausecker <fuz@FreeBSD.org> under sponsorship from the FreeBSD
 * Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *  * this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *  * this list of conditions and the following disclaimer in the documentation
 *  * and/or other materials provided with the distribution.
 *
 *  * Neither the name of Intel Corporation nor the names of its contributors
 *  * may be used to endorse or promote products derived from this software
 *  * without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <machine/asm.h>

#include "amd64_archlevel.h"

/* Values are optimized for Core Architecture */
#define SHARED_CACHE_SIZE (4096*1024)  /* Core Architecture L2 Cache */
#define SHARED_CACHE_SIZE_HALF (SHARED_CACHE_SIZE / 2)

/*
 * Note: this routine was written with kernel use in mind (read: no simd),
 * it is only present in userspace as a temporary measure until something
 * better gets imported.
 */

#define	ALIGN_TEXT	.p2align 4,0x90 /* 16-byte alignment, nop filled */

/*
 * memmove(dst, src, cnt)
 *         rdi, rsi, rdx
 */

#ifdef MEMCPY
#define memmove memcpy
#endif

ARCHFUNCS(memmove)
	ARCHFUNC(memmove, scalar)
	ARCHFUNC(memmove, baseline)
ENDARCHFUNCS(memmove)

/*
 * Register state at entry is supposed to be as follows:
 * rdi - destination
 * rsi - source
 * rdx - count
 *
 * The macro possibly clobbers the above and: rcx, r8, r9, 10
 * It does not clobber rax nor r11.
 */
.macro MEMMOVE erms overlap begin end
	\begin

	/*
	 * For sizes 0..32 all data is read before it is written, so there
	 * is no correctness issue with direction of copying.
	 */
	cmpq	$32,%rcx
	jbe	101632f

.if \overlap == 1
	movq	%rdi,%r8
	subq	%rsi,%r8
	cmpq	%rcx,%r8	/* overlapping && src < dst? */
	jb	2f
.endif

	cmpq	$256,%rcx
	ja	1256f

	ALIGN_TEXT
103200:
	movq	(%rsi),%rdx
	movq	%rdx,(%rdi)
	movq	8(%rsi),%rdx
	movq	%rdx,8(%rdi)
	movq	16(%rsi),%rdx
	movq	%rdx,16(%rdi)
	movq	24(%rsi),%rdx
	movq	%rdx,24(%rdi)
	leaq	32(%rsi),%rsi
	leaq	32(%rdi),%rdi
	subq	$32,%rcx
	cmpq	$32,%rcx
	jae	103200b
	cmpb	$0,%cl
	jne	101632f
	\end
	ret
	ALIGN_TEXT
101632:
	cmpb	$16,%cl
	jl	100816f
	movq	(%rsi),%rdx
	movq	8(%rsi),%r8
	movq	-16(%rsi,%rcx),%r9
	movq	-8(%rsi,%rcx),%r10
	movq	%rdx,(%rdi)
	movq	%r8,8(%rdi)
	movq	%r9,-16(%rdi,%rcx)
	movq	%r10,-8(%rdi,%rcx)
	\end
	ret
	ALIGN_TEXT
100816:
	cmpb	$8,%cl
	jl	100408f
	movq	(%rsi),%rdx
	movq	-8(%rsi,%rcx),%r8
	movq	%rdx,(%rdi)
	movq	%r8,-8(%rdi,%rcx,)
	\end
	ret
	ALIGN_TEXT
100408:
	cmpb	$4,%cl
	jl	100204f
	movl	(%rsi),%edx
	movl	-4(%rsi,%rcx),%r8d
	movl	%edx,(%rdi)
	movl	%r8d,-4(%rdi,%rcx)
	\end
	ret
	ALIGN_TEXT
100204:
	cmpb	$2,%cl
	jl	100001f
	movzwl	(%rsi),%edx
	movzwl	-2(%rsi,%rcx),%r8d
	movw	%dx,(%rdi)
	movw	%r8w,-2(%rdi,%rcx)
	\end
	ret
	ALIGN_TEXT
100001:
	cmpb	$1,%cl
	jl	100000f
	movb	(%rsi),%dl
	movb	%dl,(%rdi)
100000:
	\end
	ret

	ALIGN_TEXT
1256:
	testb	$15,%dil
	jnz	100f
.if \erms == 1
	rep
	movsb
.else
	shrq	$3,%rcx                         /* copy by 64-bit words */
	rep
	movsq
	movq	%rdx,%rcx
	andl	$7,%ecx                         /* any bytes left? */
	jne	100408b
.endif
	\end
	ret
100:
	movq	(%rsi),%r8
	movq	8(%rsi),%r9
	movq	%rdi,%r10
	movq	%rdi,%rcx
	andq	$15,%rcx
	leaq	-16(%rdx,%rcx),%rdx
	neg	%rcx
	leaq	16(%rdi,%rcx),%rdi
	leaq	16(%rsi,%rcx),%rsi
	movq	%rdx,%rcx
.if \erms == 1
	rep
	movsb
	movq	%r8,(%r10)
	movq	%r9,8(%r10)
.else
	shrq	$3,%rcx                         /* copy by 64-bit words */
	rep
	movsq
	movq	%r8,(%r10)
	movq	%r9,8(%r10)
	movq	%rdx,%rcx
	andl	$7,%ecx                         /* any bytes left? */
	jne	100408b
.endif
	\end
	ret

.if \overlap == 1
	/*
	 * Copy backwards.
	 */
        ALIGN_TEXT
2:
	cmpq	$256,%rcx
	ja	2256f

	leaq	-8(%rdi,%rcx),%rdi
	leaq	-8(%rsi,%rcx),%rsi

	cmpq	$32,%rcx
	jb	2016f

	ALIGN_TEXT
2032:
	movq	(%rsi),%rdx
	movq	%rdx,(%rdi)
	movq	-8(%rsi),%rdx
	movq	%rdx,-8(%rdi)
	movq	-16(%rsi),%rdx
	movq	%rdx,-16(%rdi)
	movq	-24(%rsi),%rdx
	movq	%rdx,-24(%rdi)
	leaq	-32(%rsi),%rsi
	leaq	-32(%rdi),%rdi
	subq	$32,%rcx
	cmpq	$32,%rcx
	jae	2032b
	cmpb	$0,%cl
	jne	2016f
	\end
	ret
	ALIGN_TEXT
2016:
	cmpb	$16,%cl
	jl	2008f
	movq	(%rsi),%rdx
	movq	%rdx,(%rdi)
	movq	-8(%rsi),%rdx
	movq	%rdx,-8(%rdi)
	subb	$16,%cl
	jz	2000f
	leaq	-16(%rsi),%rsi
	leaq	-16(%rdi),%rdi
2008:
	cmpb	$8,%cl
	jl	2004f
	movq	(%rsi),%rdx
	movq	%rdx,(%rdi)
	subb	$8,%cl
	jz	2000f
	leaq	-8(%rsi),%rsi
	leaq	-8(%rdi),%rdi
2004:
	cmpb	$4,%cl
	jl	2002f
	movl	4(%rsi),%edx
	movl	%edx,4(%rdi)
	subb	$4,%cl
	jz	2000f
	leaq	-4(%rsi),%rsi
	leaq	-4(%rdi),%rdi
2002:
	cmpb	$2,%cl
	jl	2001f
	movw	6(%rsi),%dx
	movw	%dx,6(%rdi)
	subb	$2,%cl
	jz	2000f
	leaq	-2(%rsi),%rsi
	leaq	-2(%rdi),%rdi
2001:
	cmpb	$1,%cl
	jl	2000f
	movb	7(%rsi),%dl
	movb	%dl,7(%rdi)
2000:
	\end
	ret
	ALIGN_TEXT
2256:
	std
	leaq	-8(%rdi,%rcx),%rdi
	leaq	-8(%rsi,%rcx),%rsi
	shrq	$3,%rcx
	rep
	movsq
	cld
	movq	%rdx,%rcx
	andb	$7,%cl
	jne	2004b
	\end
	ret
.endif
.endm


.macro MEMMOVE_BEGIN
	movq	%rdi,%rax
	movq	%rdx,%rcx
.endm

.macro MEMMOVE_END
.endm

ARCHENTRY(memmove, scalar)
	MEMMOVE erms=0 overlap=1 begin=MEMMOVE_BEGIN end=MEMMOVE_END
ARCHEND(memmove, scalar)

#ifndef L
# define L(label)       .L##label
#endif

#define PUSH(REG)	push REG;
#define POP(REG)	pop REG;

#define ENTRANCE	PUSH (%rbx);
#define RETURN_END	POP (%rbx); ret
#define RETURN		RETURN_END;

ARCHENTRY(memmove, baseline)
	ENTRANCE
	mov	%rdi, %rax

/* Check whether we should copy backward or forward.  */
	cmp	%rsi, %rdi
	je	L(mm_return)
	jg	L(mm_len_0_or_more_backward)

/* Now do checks for lengths. We do [0..16], [0..32], [0..64], [0..128]
	separately.  */
	cmp	$16, %rdx
	jbe	L(mm_len_0_16_bytes_forward)

	cmp	$32, %rdx
	ja	L(mm_len_32_or_more_forward)

/* Copy [0..32] and return.  */
	movdqu	(%rsi), %xmm0
	movdqu	-16(%rsi, %rdx), %xmm1
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, -16(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_len_32_or_more_forward):
	cmp	$64, %rdx
	ja	L(mm_len_64_or_more_forward)

/* Copy [0..64] and return.  */
	movdqu	(%rsi), %xmm0
	movdqu	16(%rsi), %xmm1
	movdqu	-16(%rsi, %rdx), %xmm2
	movdqu	-32(%rsi, %rdx), %xmm3
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, 16(%rdi)
	movdqu	%xmm2, -16(%rdi, %rdx)
	movdqu	%xmm3, -32(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_len_64_or_more_forward):
	cmp	$128, %rdx
	ja	L(mm_len_128_or_more_forward)

/* Copy [0..128] and return.  */
	movdqu	(%rsi), %xmm0
	movdqu	16(%rsi), %xmm1
	movdqu	32(%rsi), %xmm2
	movdqu	48(%rsi), %xmm3
	movdqu	-64(%rsi, %rdx), %xmm4
	movdqu	-48(%rsi, %rdx), %xmm5
	movdqu	-32(%rsi, %rdx), %xmm6
	movdqu	-16(%rsi, %rdx), %xmm7
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, 16(%rdi)
	movdqu	%xmm2, 32(%rdi)
	movdqu	%xmm3, 48(%rdi)
	movdqu	%xmm4, -64(%rdi, %rdx)
	movdqu	%xmm5, -48(%rdi, %rdx)
	movdqu	%xmm6, -32(%rdi, %rdx)
	movdqu	%xmm7, -16(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_len_128_or_more_forward):
/* Aligning the address of destination.  */
/*  save first unaligned 64 bytes */
	movdqu	(%rsi), %xmm0
	movdqu	16(%rsi), %xmm1
	movdqu	32(%rsi), %xmm2
	movdqu	48(%rsi), %xmm3

	lea	64(%rdi), %r8
	and	$-64, %r8  /* r8 now aligned to next 64 byte boundary */
	sub	%rdi, %rsi /* rsi = src - dst = diff */

	movdqu	(%r8, %rsi), %xmm4
	movdqu	16(%r8, %rsi), %xmm5
	movdqu	32(%r8, %rsi), %xmm6
	movdqu	48(%r8, %rsi), %xmm7

	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, 16(%rdi)
	movdqu	%xmm2, 32(%rdi)
	movdqu	%xmm3, 48(%rdi)
	movdqa	%xmm4, (%r8)
	movaps	%xmm5, 16(%r8)
	movaps	%xmm6, 32(%r8)
	movaps	%xmm7, 48(%r8)
	add	$64, %r8

	lea	(%rdi, %rdx), %rbx
	and	$-64, %rbx
	cmp	%r8, %rbx
	jbe	L(mm_copy_remaining_forward)

	cmp	$SHARED_CACHE_SIZE_HALF, %rdx
	jae	L(mm_large_page_loop_forward)

	.p2align 4
L(mm_main_loop_forward):

	prefetcht0 128(%r8, %rsi)

	movdqu	(%r8, %rsi), %xmm0
	movdqu	16(%r8, %rsi), %xmm1
	movdqu	32(%r8, %rsi), %xmm2
	movdqu	48(%r8, %rsi), %xmm3
	movdqa	%xmm0, (%r8)
	movaps	%xmm1, 16(%r8)
	movaps	%xmm2, 32(%r8)
	movaps	%xmm3, 48(%r8)
	lea	64(%r8), %r8
	cmp	%r8, %rbx
	ja	L(mm_main_loop_forward)

L(mm_copy_remaining_forward):
	add	%rdi, %rdx
	sub	%r8, %rdx
/* We copied all up till %rdi position in the dst.
	In %rdx now is how many bytes are left to copy.
	Now we need to advance %r8. */
	lea	(%r8, %rsi), %r9

L(mm_remaining_0_64_bytes_forward):
	cmp	$32, %rdx
	ja	L(mm_remaining_33_64_bytes_forward)
	cmp	$16, %rdx
	ja	L(mm_remaining_17_32_bytes_forward)
	test	%rdx, %rdx
	.p2align 4,,2
	je	L(mm_return)

	cmpb	$8, %dl
	ja	L(mm_remaining_9_16_bytes_forward)
	cmpb	$4, %dl
	.p2align 4,,5
	ja	L(mm_remaining_5_8_bytes_forward)
	cmpb	$2, %dl
	.p2align 4,,1
	ja	L(mm_remaining_3_4_bytes_forward)
	movzbl	-1(%r9,%rdx), %esi
	movzbl	(%r9), %ebx
	movb	%sil, -1(%r8,%rdx)
	movb	%bl, (%r8)
	jmp	L(mm_return)

L(mm_remaining_33_64_bytes_forward):
	movdqu	(%r9), %xmm0
	movdqu	16(%r9), %xmm1
	movdqu	-32(%r9, %rdx), %xmm2
	movdqu	-16(%r9, %rdx), %xmm3
	movdqu	%xmm0, (%r8)
	movdqu	%xmm1, 16(%r8)
	movdqu	%xmm2, -32(%r8, %rdx)
	movdqu	%xmm3, -16(%r8, %rdx)
	jmp	L(mm_return)

L(mm_remaining_17_32_bytes_forward):
	movdqu	(%r9), %xmm0
	movdqu	-16(%r9, %rdx), %xmm1
	movdqu	%xmm0, (%r8)
	movdqu	%xmm1, -16(%r8, %rdx)
	jmp	L(mm_return)

L(mm_remaining_5_8_bytes_forward):
	movl	(%r9), %esi
	movl	-4(%r9,%rdx), %ebx
	movl	%esi, (%r8)
	movl	%ebx, -4(%r8,%rdx)
	jmp	L(mm_return)

L(mm_remaining_9_16_bytes_forward):
	mov	(%r9), %rsi
	mov	-8(%r9, %rdx), %rbx
	mov	%rsi, (%r8)
	mov	%rbx, -8(%r8, %rdx)
	jmp	L(mm_return)

L(mm_remaining_3_4_bytes_forward):
	movzwl	-2(%r9,%rdx), %esi
	movzwl	(%r9), %ebx
	movw	%si, -2(%r8,%rdx)
	movw	%bx, (%r8)
	jmp	L(mm_return)

L(mm_len_0_16_bytes_forward):
	testb	$24, %dl
	jne	L(mm_len_9_16_bytes_forward)
	testb	$4, %dl
	.p2align 4,,5
	jne	L(mm_len_5_8_bytes_forward)
	test	%rdx, %rdx
	.p2align 4,,2
	je	L(mm_return)
	testb	$2, %dl
	.p2align 4,,1
	jne	L(mm_len_2_4_bytes_forward)
	movzbl	-1(%rsi,%rdx), %ebx
	movzbl	(%rsi), %esi
	movb	%bl, -1(%rdi,%rdx)
	movb	%sil, (%rdi)
	jmp	L(mm_return)

L(mm_len_2_4_bytes_forward):
	movzwl	-2(%rsi,%rdx), %ebx
	movzwl	(%rsi), %esi
	movw	%bx, -2(%rdi,%rdx)
	movw	%si, (%rdi)
	jmp	L(mm_return)

L(mm_len_5_8_bytes_forward):
	movl	(%rsi), %ebx
	movl	-4(%rsi,%rdx), %esi
	movl	%ebx, (%rdi)
	movl	%esi, -4(%rdi,%rdx)
	jmp	L(mm_return)

L(mm_len_9_16_bytes_forward):
	mov	(%rsi), %rbx
	mov	-8(%rsi, %rdx), %rsi
	mov	%rbx, (%rdi)
	mov	%rsi, -8(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_recalc_len):
/* Compute in %rdx how many bytes are left to copy after
	the main loop stops.  */
	mov 	%rbx, %rdx
	sub 	%rdi, %rdx
/* The code for copying backwards.  */
L(mm_len_0_or_more_backward):

/* Now do checks for lengths. We do [0..16], [16..32], [32..64], [64..128]
	separately.  */
	cmp	$16, %rdx
	jbe	L(mm_len_0_16_bytes_backward)

	cmp	$32, %rdx
	ja	L(mm_len_32_or_more_backward)

/* Copy [0..32] and return.  */
	movdqu	(%rsi), %xmm0
	movdqu	-16(%rsi, %rdx), %xmm1
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, -16(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_len_32_or_more_backward):
	cmp	$64, %rdx
	ja	L(mm_len_64_or_more_backward)

/* Copy [0..64] and return.  */
	movdqu	(%rsi), %xmm0
	movdqu	16(%rsi), %xmm1
	movdqu	-16(%rsi, %rdx), %xmm2
	movdqu	-32(%rsi, %rdx), %xmm3
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, 16(%rdi)
	movdqu	%xmm2, -16(%rdi, %rdx)
	movdqu	%xmm3, -32(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_len_64_or_more_backward):
	cmp	$128, %rdx
	ja	L(mm_len_128_or_more_backward)

/* Copy [0..128] and return.  */
	movdqu	(%rsi), %xmm0
	movdqu	16(%rsi), %xmm1
	movdqu	32(%rsi), %xmm2
	movdqu	48(%rsi), %xmm3
	movdqu	-64(%rsi, %rdx), %xmm4
	movdqu	-48(%rsi, %rdx), %xmm5
	movdqu	-32(%rsi, %rdx), %xmm6
	movdqu	-16(%rsi, %rdx), %xmm7
	movdqu	%xmm0, (%rdi)
	movdqu	%xmm1, 16(%rdi)
	movdqu	%xmm2, 32(%rdi)
	movdqu	%xmm3, 48(%rdi)
	movdqu	%xmm4, -64(%rdi, %rdx)
	movdqu	%xmm5, -48(%rdi, %rdx)
	movdqu	%xmm6, -32(%rdi, %rdx)
	movdqu	%xmm7, -16(%rdi, %rdx)
	jmp	L(mm_return)

L(mm_len_128_or_more_backward):
/* Aligning the address of destination. We need to save
	16 bits from the source in order not to overwrite them.  */
	movdqu	-16(%rsi, %rdx), %xmm0
	movdqu	-32(%rsi, %rdx), %xmm1
	movdqu	-48(%rsi, %rdx), %xmm2
	movdqu	-64(%rsi, %rdx), %xmm3

	lea	(%rdi, %rdx), %r9
	and	$-64, %r9 /* r9 = aligned dst */

	mov	%rsi, %r8
	sub	%rdi, %r8 /* r8 = src - dst, diff */

	movdqu	-16(%r9, %r8), %xmm4
	movdqu	-32(%r9, %r8), %xmm5
	movdqu	-48(%r9, %r8), %xmm6
	movdqu	-64(%r9, %r8), %xmm7

	movdqu	%xmm0, -16(%rdi, %rdx)
	movdqu	%xmm1, -32(%rdi, %rdx)
	movdqu	%xmm2, -48(%rdi, %rdx)
	movdqu	%xmm3, -64(%rdi, %rdx)
	movdqa	%xmm4, -16(%r9)
	movaps	%xmm5, -32(%r9)
	movaps	%xmm6, -48(%r9)
	movaps	%xmm7, -64(%r9)
	lea	-64(%r9), %r9

	lea	64(%rdi), %rbx
	and	$-64, %rbx

	cmp	%r9, %rbx
	jae	L(mm_recalc_len)

	cmp	$SHARED_CACHE_SIZE_HALF, %rdx
	jae	L(mm_large_page_loop_backward)

	.p2align 4
L(mm_main_loop_backward):

	prefetcht0 -128(%r9, %r8)

	movdqu	-64(%r9, %r8), %xmm0
	movdqu	-48(%r9, %r8), %xmm1
	movdqu	-32(%r9, %r8), %xmm2
	movdqu	-16(%r9, %r8), %xmm3
	movdqa	%xmm0, -64(%r9)
	movaps	%xmm1, -48(%r9)
	movaps	%xmm2, -32(%r9)
	movaps	%xmm3, -16(%r9)
	lea	-64(%r9), %r9
	cmp	%r9, %rbx
	jb	L(mm_main_loop_backward)
	jmp	L(mm_recalc_len)

/* Copy [0..16] and return.  */
L(mm_len_0_16_bytes_backward):
	testb	$24, %dl
	jnz	L(mm_len_9_16_bytes_backward)
	testb	$4, %dl
	.p2align 4,,5
	jnz	L(mm_len_5_8_bytes_backward)
	test	%rdx, %rdx
	.p2align 4,,2
	je	L(mm_return)
	testb	$2, %dl
	.p2align 4,,1
	jne	L(mm_len_3_4_bytes_backward)
	movzbl	-1(%rsi,%rdx), %ebx
	movzbl	(%rsi), %ecx
	movb	%bl, -1(%rdi,%rdx)
	movb	%cl, (%rdi)
	jmp	L(mm_return)

L(mm_len_3_4_bytes_backward):
	movzwl	-2(%rsi,%rdx), %ebx
	movzwl	(%rsi), %ecx
	movw	%bx, -2(%rdi,%rdx)
	movw	%cx, (%rdi)
	jmp	L(mm_return)

L(mm_len_9_16_bytes_backward):
	movl	-4(%rsi,%rdx), %ebx
	movl	-8(%rsi,%rdx), %ecx
	movl	%ebx, -4(%rdi,%rdx)
	movl	%ecx, -8(%rdi,%rdx)
	sub	$8, %rdx
	jmp	L(mm_len_0_16_bytes_backward)

L(mm_len_5_8_bytes_backward):
	movl	(%rsi), %ebx
	movl	-4(%rsi,%rdx), %ecx
	movl	%ebx, (%rdi)
	movl	%ecx, -4(%rdi,%rdx)

L(mm_return):
	RETURN

/* Big length copy forward part.  */

	.p2align 4
L(mm_large_page_loop_forward):
	movdqu	(%r8, %rsi), %xmm0
	movdqu	16(%r8, %rsi), %xmm1
	movdqu	32(%r8, %rsi), %xmm2
	movdqu	48(%r8, %rsi), %xmm3
	movntdq	%xmm0, (%r8)
	movntdq	%xmm1, 16(%r8)
	movntdq	%xmm2, 32(%r8)
	movntdq	%xmm3, 48(%r8)
	lea 	64(%r8), %r8
	cmp	%r8, %rbx
	ja	L(mm_large_page_loop_forward)
	sfence
	jmp	L(mm_copy_remaining_forward)

/* Big length copy backward part.  */
	.p2align 4
L(mm_large_page_loop_backward):
	movdqu	-64(%r9, %r8), %xmm0
	movdqu	-48(%r9, %r8), %xmm1
	movdqu	-32(%r9, %r8), %xmm2
	movdqu	-16(%r9, %r8), %xmm3
	movntdq	%xmm0, -64(%r9)
	movntdq	%xmm1, -48(%r9)
	movntdq	%xmm2, -32(%r9)
	movntdq	%xmm3, -16(%r9)
	lea 	-64(%r9), %r9
	cmp	%r9, %rbx
	jb	L(mm_large_page_loop_backward)
	sfence
	jmp	L(mm_recalc_len)
ARCHEND(memmove, baseline)

	.section .note.GNU-stack,"",%progbits
