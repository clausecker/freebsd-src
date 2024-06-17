# include the MD5 hash function into the build

.PATH: ${SRCTOP}/sys/crypto/md5

SRCS+=	md5c.c

USE_ASM_SOURCES?= 1

.if ${USE_ASM_SOURCES} != 0 && !defined(BOOTSTRAPPING) && ${MK_MACHDEP_OPTIMIZATIONS} != no
.if exists(md5block_${MACHINE_ARCH}.S)
SRCS+=	md5block_${MACHINE_ARCH}.S
CFLAGS+= -DMD5_ASM
.endif
.endif
