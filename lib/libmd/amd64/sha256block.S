/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 Robert Clausecker <fuz@FreeBSD.org>
 */

#include <machine/asm.h>

.macro	mix	a, b, c, d, e, f, g, h, w, k
	mov	\f, %ebp
	add	$\k, \h			# h + k[i]
	xor	\g, %ebp		# f ^ g
	add	\w, \h			# h + k[i] + w[i]
	mov	\e, %edx
	mov	\e, %ecx
	and	\e, %ebp		# e & (f ^ g)
	ror	$6, %edx
	ror	$11, %ecx
	xor	\g, %ebp		# g ^ e & (f ^ g) == e ? f : g
	xor	%edx, %ecx		# (e >>> 6) ^ (e >>> 11)
	add	%ebp, \h		# h + k[i] + w[i] + ch
	ror	$25-6, %edx
	mov	\c, %ebp
	xor	%edx, %ecx		# S1 = (e >>> 6) ^ (e >>> 11) ^ (e >>> 25)
	and	\b, %ebp		# b & c
	add	%ecx, \h		# temp1 = h + k[i] + w[i] + ch + S1
	add	\h, \d
	add	%ebp, \h		# temp1 + (b & c)
	mov	\c, %ebp
	xor	\b, %ebp		# b ^ c
	mov	\a, %edx
	mov	\a, %ecx
	and	\a, %ebp		# a & (b ^ c)
	ror	$2, %ecx
	ror	$13, %edx
	add	%ebp, \h		# temp1 + (b & c) + (a & (b ^ c)) = temp1 + maj(a,b,c)
	xor	%ecx, %edx		# (a >>> 2) ^ (a >>> 13)
	ror	$22-2, %ecx
	xor	%ecx, %edx		# S0 = (a >>> 2) ^ (a >>> 13) ^ (a >>> 22)
	add	%edx, \h		# temp1 + maj(a, b, c) + S0
.endm

.macro	round0	a, b, c, d, e, f, g, h, i, k
	mov	((\i)*4)(%rsi), %ecx
	bswap	%ecx
	mov	%ecx, ((\i)*4)(%rsp)
	mix	\a, \b, \c, \d, \e, \f, \g, \h, %ecx, \k
.endm

.macro	rounds0 i, k0, k1, k2, k3, k4, k5, k6, k7
	round0	%eax,  %ebx,  %r8d,  %r9d,  %r10d, %r11d, %r12d, %edi,  \i + 0, \k0
	round0	%edi,  %eax,  %ebx,  %r8d,  %r9d,  %r10d, %r11d, %r12d, \i + 1, \k1
	round0	%r12d, %edi,  %eax,  %ebx,  %r8d,  %r9d,  %r10d, %r11d, \i + 2, \k2
	round0	%r11d, %r12d, %edi,  %eax,  %ebx,  %r8d,  %r9d,  %r10d, \i + 3, \k3
	round0	%r10d, %r11d, %r12d, %edi,  %eax,  %ebx,  %r8d,  %r9d,  \i + 4, \k4
	round0	%r9d,  %r10d, %r11d, %r12d, %edi,  %eax,  %ebx,  %r8d,  \i + 5, \k5
	round0	%r8d,  %r9d,  %r10d, %r11d, %r12d, %edi,  %eax,  %ebx,  \i + 6, \k6
	round0	%ebx,  %r8d,  %r9d,  %r10d, %r11d, %r12d, %edi,  %eax,  \i + 7, \k7
.endm

	/* the scheduled message is deposited into ECX */
.macro	sched	i
	mov	(((\i)-15)%16*4)(%rsp), %ecx
	mov	(((\i)-2)%16*4)(%rsp), %edx
	mov	%ecx, %ebp
	ror	$18-7, %ecx
	xor	%ebp, %ecx		# w[i-15] >>> (18 - 7) ^ w[i-15]
	shr	$3, %ebp
	ror	$7, %ecx		# w[i-15] >>> 18 ^ w[i-15] >>> 7
	xor	%ebp, %ecx		# w[i-15] >>> 18 ^ w[i-15] >>> 7 ^ w[i-15] >> 3
	mov	%edx, %ebp
	ror	$19-17, %edx
	xor	%ebp, %edx		# w[i-2] >>> (19-17) ^ w[i-2]
	shr	$10, %ebp
	ror	$17, %edx		# w[i-2] >>> 19 ^ w[i-2] >>> 17
	xor	%ebp, %edx		# w[i-2] >>> 19 ^ w[i-2] >>> 17 ^ w[i-2] >> 10
	add	(((\i)-16)%16*4)(%rsp), %ecx
	add	(((\i)-7)%16*4)(%rsp), %edx
	add	%edx, %ecx
	mov	%ecx, ((\i)%16*4)(%rsp)
.endm

.macro	round	a, b, c, d, e, f, g, h, i, k
	sched	\i
	mix	\a, \b, \c, \d, \e, \f, \g, \h, %ecx, \k
.endm

.macro	rounds	i, k0, k1, k2, k3, k4, k5, k6, k7
	round	%eax,  %ebx,  %r8d,  %r9d,  %r10d, %r11d, %r12d, %edi,  \i + 0, \k0
	round	%edi,  %eax,  %ebx,  %r8d,  %r9d,  %r10d, %r11d, %r12d, \i + 1, \k1
	round	%r12d, %edi,  %eax,  %ebx,  %r8d,  %r9d,  %r10d, %r11d, \i + 2, \k2
	round	%r11d, %r12d, %edi,  %eax,  %ebx,  %r8d,  %r9d,  %r10d, \i + 3, \k3
	round	%r10d, %r11d, %r12d, %edi,  %eax,  %ebx,  %r8d,  %r9d,  \i + 4, \k4
	round	%r9d,  %r10d, %r11d, %r12d, %edi,  %eax,  %ebx,  %r8d,  \i + 5, \k5
	round	%r8d,  %r9d,  %r10d, %r11d, %r12d, %edi,  %eax,  %ebx,  \i + 6, \k6
	round	%ebx,  %r8d,  %r9d,  %r10d, %r11d, %r12d, %edi,  %eax,  \i + 7, \k7
.endm

	// SHA256_Transform(state, msg)
ENTRY(_libmd_SHA256_Transform)
	push	%rbp
	push	%rbx
	push	%r12
	push	%r13
	push	%rdi			// rdi: state

	sub	$64, %rsp		// 64 bytes for round keys

	mov	(%rdi), %eax		// load state variables
	mov	4(%rdi), %ebx
	mov	8(%rdi), %r8d
	mov	12(%rdi), %r9d
	mov	16(%rdi), %r10d
	mov	20(%rdi), %r11d
	mov	24(%rdi), %r12d
	mov	28(%rdi), %edi

	rounds0	 0, 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
	rounds0	 8, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
	rounds	16, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
	rounds	24, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
	rounds	32, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
	rounds	40, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
	rounds	48, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
	rounds	56, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2

	mov	64(%rsp), %rbp		// state pointer

	add	%eax, (%rbp)
	add	%ebx, 4(%rbp)
	add	%r8d, 8(%rbp)
	add	%r9d, 12(%rbp)
	add	%r10d, 16(%rbp)
	add	%r11d, 20(%rbp)
	add	%r12d, 24(%rbp)
	add	%edi, 28(%rbp)

	add	$64+8, %rsp
	pop	%r13
	pop	%r12
	pop	%rbx
	pop	%rbp
	ret
END(_libmd_SHA256_Transform)

	.section .note.GNU-stack,"",%progbits
