// Reference:
// https://github.com/aklomp/base64/blob/master/lib/arch/ssse3/enc_loop.c
// https://gist.github.com/emmansun/c0f174a614a005f80f51b033500fd7fc
//go:build amd64 && !purego
// +build amd64,!purego

#include "textflag.h"

// shuffle byte order for input 12 butes
DATA reshuffle_mask<>+0x00(SB)/8, $0x0405030401020001
DATA reshuffle_mask<>+0x08(SB)/8, $0x0a0b090a07080607
GLOBL reshuffle_mask<>(SB), 8, $16

DATA mulhi_mask<>+0x00(SB)/8, $0x0FC0FC000FC0FC00
DATA mulhi_mask<>+0x08(SB)/8, $0x0FC0FC000FC0FC00
GLOBL mulhi_mask<>(SB), 8, $16

DATA mulhi_const<>+0x00(SB)/8, $0x0400004004000040
DATA mulhi_const<>+0x08(SB)/8, $0x0400004004000040
GLOBL mulhi_const<>(SB), 8, $16

DATA mullo_mask<>+0x00(SB)/8, $0x003F03F0003F03F0
DATA mullo_mask<>+0x08(SB)/8, $0x003F03F0003F03F0
GLOBL mullo_mask<>(SB), 8, $16

DATA mullo_const<>+0x00(SB)/8, $0x0100001001000010
DATA mullo_const<>+0x08(SB)/8, $0x0100001001000010
GLOBL mullo_const<>(SB), 8, $16

DATA range_0_end<>+0x00(SB)/8, $0x1919191919191919
DATA range_0_end<>+0x08(SB)/8, $0x1919191919191919
GLOBL range_0_end<>(SB), 8, $16

DATA range_1_end<>+0x00(SB)/8, $0x3333333333333333
DATA range_1_end<>+0x08(SB)/8, $0x3333333333333333
GLOBL range_1_end<>(SB), 8, $16

// Requires SSSE3
#define SSE_ENC(in_out, lut, tmp1, tmp2) \
	\ // enc reshuffle
	PSHUFB reshuffle_mask<>(SB), in_out;           \
	MOVOU in_out, tmp1;                            \
	PAND mulhi_mask<>(SB), tmp1;                   \
	PMULHUW mulhi_const<>(SB), tmp1;               \
	PAND mullo_mask<>(SB), in_out;                 \
	PMULLW mullo_const<>(SB), in_out;              \
	POR tmp1, in_out;                              \
	\ // enc translate
	MOVOU in_out, tmp1;                            \
	MOVOU in_out, tmp2;                            \
	PSUBUSB range_1_end<>(SB), tmp2;               \
	PCMPGTB range_0_end<>(SB), tmp1;               \
	PSUBB tmp1, tmp2;                              \
	MOVOU lut, tmp1;                               \
	PSHUFB tmp2, tmp1;                             \
	PADDB tmp1, in_out

#define AVX_ENC(in_out, lut, tmp1, tmp2) \
	\ // enc reshuffle
	VPSHUFB reshuffle_mask<>(SB), in_out, in_out;  \
	VPAND mulhi_mask<>(SB), in_out, tmp1;          \
	VPMULHUW mulhi_const<>(SB), tmp1, tmp1;        \
	VPAND mullo_mask<>(SB), in_out, in_out;        \
	VPMULLW mullo_const<>(SB), in_out, in_out;     \
	VPOR tmp1, in_out, in_out;                     \
	\ // enc translate
	VPSUBUSB range_1_end<>(SB), in_out, tmp1;      \
	VPCMPGTB range_0_end<>(SB), in_out, tmp2;      \
	VPSUBB tmp2, tmp1, tmp1;                       \
	VPSHUFB tmp1, lut, tmp1;                       \
	VPADDB tmp1, in_out, in_out

//func encodeSIMD(dst, src []byte, lut *[16]byte) int
TEXT ·encodeSIMD(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), AX
	MOVQ src_base+24(FP), BX
	MOVQ src_len+32(FP), CX
	MOVQ lut+48(FP), SI

	CMPB ·useAVX2(SB), $1
	JE   avx2

	CMPB ·useAVX(SB), $1
	JE   avx

	MOVOU (SI), X3
	XORQ SI, SI

loop:
	CMPQ CX, $16
	JB done

	// enc reshuffle
	MOVOU (BX), X0
	
	SSE_ENC(X0, X3, X1, X2)

	// store encoded
	MOVOU X0, (AX)(SI*1) 

	ADDQ $16, SI
	SUBQ $12, CX

	LEAQ 12(BX), BX	
	JMP loop

done:
	MOVQ SI, ret+56(FP)
	RET

avx:
	VMOVDQU (SI), X3
	XORQ SI, SI

avx_loop:
	CMPQ CX, $16
	JB avx_done

	// load data
	VMOVDQU (BX), X0

	AVX_ENC(X0, X3, X1, X2)

	// store encoded
	VMOVDQU X0, (AX)(SI*1) 

	ADDQ $16, SI
	SUBQ $12, CX

	LEAQ 12(BX), BX	
	JMP avx_loop

avx_done:
	MOVQ SI, ret+56(FP)
	RET

avx2:
	VBROADCASTI128 reshuffle_mask<>(SB), Y6
	VBROADCASTI128 mulhi_mask<>(SB), Y7
	VBROADCASTI128 mulhi_const<>(SB), Y8
	VBROADCASTI128 mullo_mask<>(SB), Y9
	VBROADCASTI128 mullo_const<>(SB), Y10
	VBROADCASTI128 range_0_end<>(SB), Y11
	VBROADCASTI128 range_1_end<>(SB), Y12
	VBROADCASTI128 (SI), Y13
	XORQ SI, SI

avx2_loop_28:
	CMPQ CX, $28
	JB avx2_one

	// load data
	VMOVDQU (BX), X0
	VMOVDQU 12(BX), X1
	VINSERTI128 $1, X1, Y0, Y0

	// enc reshuffle
	VPSHUFB Y6, Y0, Y0
	VPAND Y7, Y0, Y1
	VPMULHUW Y8, Y1, Y1
	VPAND Y9, Y0, Y0
	VPMULLW Y10, Y0, Y0
	VPOR Y1, Y0, Y0

	// enc translate
	VPSUBUSB Y12, Y0, Y1
	VPCMPGTB Y11, Y0, Y2
	VPSUBB Y2, Y1, Y1
	VPSHUFB Y1, Y13, Y1
	VPADDB Y1, Y0, Y0

	// store encoded
	VMOVDQU Y0, (AX)(SI*1) 

	ADDQ $32, SI
	SUBQ $24, CX

	LEAQ 24(BX), BX	
	JMP avx2_loop_28

avx2_one:
	CMPQ CX, $16
	JB avx2_done

	// enc reshuffle
	VMOVDQU (BX), X0
	VPSHUFB X6, X0, X0
	VPAND X7, X0, X1
	VPMULHUW X8, X1, X1
	VPAND X9, X0, X0
	VPMULLW X10, X0, X0
	VPOR X1, X0, X0

	// enc translate
	VPSUBUSB X12, X0, X1
	VPCMPGTB X11, X0, X2
	VPSUBB X2, X1, X1
	VPSHUFB X1, X13, X1
	VPADDB X1, X0, X0

	// store encoded
	VMOVDQU X0, (AX)(SI*1) 
	ADDQ $16, SI

avx2_done:
	MOVQ SI, ret+56(FP)
	VZEROUPPER
	RET
