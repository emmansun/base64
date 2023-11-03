// Reference:
// https://github.com/aklomp/base64/blob/master/lib/arch/ssse3/enc_loop.c
// https://gist.github.com/emmansun/c0f174a614a005f80f51b033500fd7fc
//go:build amd64 && !purego
// +build amd64,!purego

#include "textflag.h"

// shuffle byte order for input 12 butes
DATA reshuffle_mask<>+0x00(SB)/8, $0x0405030401020001
DATA reshuffle_mask<>+0x08(SB)/8, $0x0a0b090a07080607
GLOBL reshuffle_mask<>(SB), (NOPTR+RODATA), $16

DATA mulhi_mask<>+0x00(SB)/8, $0x0FC0FC000FC0FC00
DATA mulhi_mask<>+0x08(SB)/8, $0x0FC0FC000FC0FC00
GLOBL mulhi_mask<>(SB), (NOPTR+RODATA), $16

DATA mulhi_const<>+0x00(SB)/8, $0x0400004004000040
DATA mulhi_const<>+0x08(SB)/8, $0x0400004004000040
GLOBL mulhi_const<>(SB), (NOPTR+RODATA), $16

DATA mullo_mask<>+0x00(SB)/8, $0x003F03F0003F03F0
DATA mullo_mask<>+0x08(SB)/8, $0x003F03F0003F03F0
GLOBL mullo_mask<>(SB), (NOPTR+RODATA), $16

DATA mullo_const<>+0x00(SB)/8, $0x0100001001000010
DATA mullo_const<>+0x08(SB)/8, $0x0100001001000010
GLOBL mullo_const<>(SB), (NOPTR+RODATA), $16

DATA range_0_end<>+0x00(SB)/8, $0x1919191919191919
DATA range_0_end<>+0x08(SB)/8, $0x1919191919191919
GLOBL range_0_end<>(SB), (NOPTR+RODATA), $16

DATA range_1_end<>+0x00(SB)/8, $0x3333333333333333
DATA range_1_end<>+0x08(SB)/8, $0x3333333333333333
GLOBL range_1_end<>(SB), (NOPTR+RODATA), $16

// below constants for std decode
// nibble mask
DATA nibble_mask<>+0x00(SB)/8, $0x2F2F2F2F2F2F2F2F
DATA nibble_mask<>+0x08(SB)/8, $0x2F2F2F2F2F2F2F2F
GLOBL nibble_mask<>(SB), (NOPTR+RODATA), $16

DATA stddec_lut_hi<>+0x00(SB)/8, $0x0804080402011010
DATA stddec_lut_hi<>+0x08(SB)/8, $0x1010101010101010
GLOBL stddec_lut_hi<>(SB), (NOPTR+RODATA), $16

DATA stddec_lut_lo<>+0x00(SB)/8, $0x1111111111111115
DATA stddec_lut_lo<>+0x08(SB)/8, $0x1A1B1B1B1A131111
GLOBL stddec_lut_lo<>(SB), (NOPTR+RODATA), $16

DATA stddec_lut_roll<>+0x00(SB)/8, $0xB9B9BFBF04131000
DATA stddec_lut_roll<>+0x08(SB)/8, $0x0000000000000000
GLOBL stddec_lut_roll<>(SB), (NOPTR+RODATA), $16

// below constants for url decode
DATA urldec_lut_hi<>+0x00(SB)/8, $0x2804080402011010
DATA urldec_lut_hi<>+0x08(SB)/8, $0x1010101010101010
GLOBL urldec_lut_hi<>(SB), (NOPTR+RODATA), $16

DATA urldec_lut_lo<>+0x00(SB)/8, $0x1111111111111115
DATA urldec_lut_lo<>+0x08(SB)/8, $0x331B1A1B1B131111
GLOBL urldec_lut_lo<>(SB), (NOPTR+RODATA), $16

DATA urldec_lut_roll<>+0x00(SB)/8, $0xB9E0BFBF04110000
DATA urldec_lut_roll<>+0x08(SB)/8, $0x00000000000000B9
GLOBL urldec_lut_roll<>(SB), (NOPTR+RODATA), $16

// 0x5E mask
DATA url_5e_mask<>+0x00(SB)/8, $0x5E5E5E5E5E5E5E5E
DATA url_5e_mask<>+0x08(SB)/8, $0x5E5E5E5E5E5E5E5E
GLOBL url_5e_mask<>(SB), (NOPTR+RODATA), $16

// below for decode reshuffle
DATA dec_reshuffle_const0<>+0x00(SB)/8, $0x0140014001400140
DATA dec_reshuffle_const0<>+0x08(SB)/8, $0x0140014001400140
GLOBL dec_reshuffle_const0<>(SB), (NOPTR+RODATA), $16

DATA dec_reshuffle_const1<>+0x00(SB)/8, $0x0001100000011000
DATA dec_reshuffle_const1<>+0x08(SB)/8, $0x0001100000011000
GLOBL dec_reshuffle_const1<>(SB), (NOPTR+RODATA), $16

DATA dec_reshuffle_const2<>+0x00(SB)/8, $0x090A040506000102
DATA dec_reshuffle_const2<>+0x08(SB)/8, $0xFFFFFFFF0C0D0E08
GLOBL dec_reshuffle_const2<>(SB), (NOPTR+RODATA), $16

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

#define SSE_RESHUFFLE(in_out) \
	PMADDUBSW dec_reshuffle_const0<>(SB), in_out;  \
	PMADDWL dec_reshuffle_const1<>(SB), in_out;    \
	PSHUFB dec_reshuffle_const2<>(SB), in_out

#define AVX_RESHUFFLE(in_out) \
	VPMADDUBSW dec_reshuffle_const0<>(SB), in_out, in_out;  \
	VPMADDWD dec_reshuffle_const1<>(SB), in_out, in_out;    \
	VPSHUFB dec_reshuffle_const2<>(SB), in_out, in_out

#define AVX2_RESHUFFLE(in_out, mask0, mask1, mask2) \
	VPMADDUBSW mask0, in_out, in_out;  \
	VPMADDWD mask1, in_out, in_out;    \
	VPSHUFB mask2, in_out, in_out

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

//func decodeStdSIMD(dst, src []byte) int
TEXT ·decodeStdSIMD(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), AX
	MOVQ src_base+24(FP), BX
	MOVQ src_len+32(FP), CX

	CMPB ·useAVX2(SB), $1
	JE   avx2

	CMPB ·useAVX(SB), $1
	JE   avx

	PXOR X12, X12

loop:
	CMPQ CX, $24
	JB done

	MOVOU (BX), X0
	MOVOU X0, X1
	MOVOU X0, X2

	PSRLL $4, X1
	PAND nibble_mask<>(SB), X1     // hi_nibbles
	PAND nibble_mask<>(SB), X2     // lo_nibbles
	MOVOU stddec_lut_hi<>(SB), X10 // lut_hi
	PSHUFB X1, X10                 // hi
	MOVOU stddec_lut_lo<>(SB), X11 // lut_lo
	PSHUFB X2, X11                 // lo

	// validate
	PAND X11, X10    // hi & lo
	PCMPGTB X12, X10 // compare with zero
	PMOVMSKB X10, SI // mm_movemask_epi8
	CMPQ SI, $0
	JNE done

	// translate
	MOVOU nibble_mask<>(SB), X2
	PCMPEQB X0, X2                  // compare nibble mask with in
	PADDB X2, X1                    // add eq_2F with hi_nibbles
	MOVOU stddec_lut_roll<>(SB), X2
	PSHUFB X1, X2                   // shuffle lut roll
	PADDB X2, X0                    // Now simply add the delta values to the input

	SSE_RESHUFFLE(X0)
	MOVOU X0, (AX)

	SUBQ $16, CX
	LEAQ 12(AX), AX
	LEAQ 16(BX), BX
	JMP loop

done:
	MOVQ CX, ret+48(FP)
	RET

avx:
	VMOVDQU stddec_lut_hi<>(SB), X10 // lut_hi
	VMOVDQU stddec_lut_lo<>(SB), X11 // lut_lo
	VMOVDQU stddec_lut_roll<>(SB), X13
	VPXOR X12, X12, X12

avx_loop:
	CMPQ CX, $24
	JB avx_done

	VMOVDQU (BX), X0

	VPSRLD $4, X0, X1
	VPAND nibble_mask<>(SB), X1, X1 // hi_nibbles
	VPAND nibble_mask<>(SB), X0, X2 // lo_nibbles
	VPSHUFB X1, X10, X3             // hi
	VPSHUFB X2, X11, X4             // lo

	// validate
	VPAND X4, X3, X3     // hi & lo
	VPCMPGTB X12, X3, X3 // compare with zero
	VPMOVMSKB X3, SI
	CMPQ SI, $0
	JNE avx_done

	// translate
	VPCMPEQB nibble_mask<>(SB), X0, X2 // compare nibble mask with in
	VPADDB X2, X1, X1                  // add eq_2F with hi_nibbles
	VPSHUFB X1, X13, X2                // shuffle lut roll
	VPADDB X2, X0, X0                  // Now simply add the delta values to the input

	AVX_RESHUFFLE(X0)
	VMOVDQU X0, (AX)

	SUBQ $16, CX
	LEAQ 12(AX), AX
	LEAQ 16(BX), BX
	JMP avx_loop

avx_done:
	MOVQ CX, ret+48(FP)
	RET

avx2:
	VBROADCASTI128 nibble_mask<>(SB), Y9
	VBROADCASTI128 stddec_lut_hi<>(SB), Y10   // lut_hi
	VBROADCASTI128 stddec_lut_lo<>(SB), Y11   // lut_lo
	VBROADCASTI128 stddec_lut_roll<>(SB), Y12 // lut_lo
	VBROADCASTI128 dec_reshuffle_const0<>(SB), Y6
	VBROADCASTI128 dec_reshuffle_const1<>(SB), Y7
	VBROADCASTI128 dec_reshuffle_const2<>(SB), Y8

avx2_loop:
	CMPQ CX, $40
	JB avx2_one
	
	VMOVDQU (BX), Y0
	VPSRLD $4, Y0, Y1
	VPAND Y9, Y1, Y1    // hi_nibbles
	VPAND Y9, Y0, Y2    // lo_nibbles
	VPSHUFB Y1, Y10, Y3 // hi
	VPSHUFB Y2, Y11, Y4 // lo

	// validate
	VPTEST Y3, Y4
	JNZ avx2_done

	// translate
	VPCMPEQB Y9, Y0, Y2 // compare nibble mask with in
	VPADDB Y2, Y1, Y1   // add eq_2F with hi_nibbles
	VPSHUFB Y1, Y12, Y2 // shuffle lut roll
	VPADDB Y2, Y0, Y0   // Now simply add the delta values to the input

	AVX2_RESHUFFLE(Y0, Y6, Y7, Y8)
	VEXTRACTI128 $1, Y0, X1
	VMOVDQU X0, (AX)
	VMOVDQU X1, 12(AX)
	
	SUBQ $32, CX
	LEAQ 24(AX), AX
	LEAQ 32(BX), BX
	JMP avx2_loop

avx2_one:
	CMPQ CX, $24
	JB avx2_done

	VMOVDQU (BX), X0
	VPSRLD $4, X0, X1
	VPAND X9, X1, X1    // hi_nibbles
	VPAND X9, X0, X2    // lo_nibbles
	VPSHUFB X1, X10, X3 // hi
	VPSHUFB X2, X11, X4 // lo

	// validate
	VPTEST X3, X4
	JNZ avx2_done

	// translate
	VPCMPEQB X9, X0, X2 // compare nibble mask with in
	VPADDB X2, X1, X1   // add eq_2F with hi_nibbles
	VPSHUFB X1, X12, X2 // shuffle lut roll
	VPADDB X2, X0, X0   // Now simply add the delta values to the input

	AVX2_RESHUFFLE(X0, X6, X7, X8)
	VMOVDQU X0, (AX)
	SUBQ $16, CX

avx2_done:
	MOVQ CX, ret+48(FP)
	VZEROUPPER
	RET

//func decodeUrlSIMD(dst, src []byte) int
TEXT ·decodeUrlSIMD(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), AX
	MOVQ src_base+24(FP), BX
	MOVQ src_len+32(FP), CX

	CMPB ·useAVX2(SB), $1
	JE   avx2

	CMPB ·useAVX(SB), $1
	JE   avx

	PXOR X12, X12

loop:
	CMPQ CX, $24
	JB done

	MOVOU (BX), X0
	MOVOU X0, X1
	MOVOU X0, X2

	PSRLL $4, X1
	PAND nibble_mask<>(SB), X1     // hi_nibbles
	PAND nibble_mask<>(SB), X2     // lo_nibbles
	MOVOU urldec_lut_hi<>(SB), X10 // lut_hi
	PSHUFB X1, X10                 // hi
	MOVOU urldec_lut_lo<>(SB), X11 // lut_lo
	PSHUFB X2, X11                 // lo

	// validate
	PAND X11, X10    // hi & lo
	PCMPGTB X12, X10 // compare with zero
	PMOVMSKB X10, SI // mm_movemask_epi8
	CMPQ SI, $0
	JNE done

	// translate
	MOVOU X0, X2
	PCMPGTB url_5e_mask<>(SB), X2 // compare 0x5E mask with in
	PSUBB X2, X1                  // sub gt_5E with hi_nibbles
	MOVOU urldec_lut_roll<>(SB), X2
	PSHUFB X1, X2                 // shuffle lut roll
	PADDB X2, X0                  // Now simply add the delta values to the input

	SSE_RESHUFFLE(X0)
	MOVOU X0, (AX)

	SUBQ $16, CX
	LEAQ 12(AX), AX
	LEAQ 16(BX), BX
	JMP loop

done:
	MOVQ CX, ret+48(FP)
	RET

avx:
	VMOVDQU urldec_lut_hi<>(SB), X10 // lut_hi
	VMOVDQU urldec_lut_lo<>(SB), X11 // lut_lo
	VMOVDQU urldec_lut_roll<>(SB), X13
	VPXOR X12, X12, X12

avx_loop:
	CMPQ CX, $24
	JB avx_done

	VMOVDQU (BX), X0

	VPSRLD $4, X0, X1
	VPAND nibble_mask<>(SB), X1, X1 // hi_nibbles
	VPAND nibble_mask<>(SB), X0, X2 // lo_nibbles
	VPSHUFB X1, X10, X3             // hi
	VPSHUFB X2, X11, X4             // lo

	// validate
	VPAND X4, X3, X3     // hi & lo
	VPCMPGTB X12, X3, X3 // compare with zero
	VPMOVMSKB X3, SI
	CMPQ SI, $0
	JNE avx_done

	// translate
	VPCMPGTB url_5e_mask<>(SB), X0, X2 // compare 0x5E mask with in
	VPSUBB X2, X1, X1                  // sub gt_5E with hi_nibbles
	VPSHUFB X1, X13, X2                // shuffle lut roll
	VPADDB X2, X0, X0                  // Now simply add the delta values to the input

	AVX_RESHUFFLE(X0)
	VMOVDQU X0, (AX)

	SUBQ $16, CX
	LEAQ 12(AX), AX
	LEAQ 16(BX), BX
	JMP avx_loop

avx_done:
	MOVQ CX, ret+48(FP)
	RET

avx2:
	VBROADCASTI128 nibble_mask<>(SB), Y9
	VBROADCASTI128 urldec_lut_hi<>(SB), Y10   // lut_hi
	VBROADCASTI128 urldec_lut_lo<>(SB), Y11   // lut_lo
	VBROADCASTI128 urldec_lut_roll<>(SB), Y12 // lut_lo
	VBROADCASTI128 dec_reshuffle_const0<>(SB), Y6
	VBROADCASTI128 dec_reshuffle_const1<>(SB), Y7
	VBROADCASTI128 dec_reshuffle_const2<>(SB), Y8
	VBROADCASTI128 url_5e_mask<>(SB), Y13

avx2_loop:
	CMPQ CX, $40
	JB avx2_one
	
	VMOVDQU (BX), Y0
	VPSRLD $4, Y0, Y1
	VPAND Y9, Y1, Y1    // hi_nibbles
	VPAND Y9, Y0, Y2    // lo_nibbles
	VPSHUFB Y1, Y10, Y3 // hi
	VPSHUFB Y2, Y11, Y4 // lo

	// validate
	VPTEST Y3, Y4
	JNZ avx2_done

	// translate
	VPCMPGTB Y13, Y0, Y2 // compare 0x5E mask with in
	VPSUBB Y2, Y1, Y1    // sub gt_5E with hi_nibbles
	VPSHUFB Y1, Y12, Y2  // shuffle lut roll
	VPADDB Y2, Y0, Y0    // Now simply add the delta values to the input

	AVX2_RESHUFFLE(Y0, Y6, Y7, Y8)
	VEXTRACTI128 $1, Y0, X1
	VMOVDQU X0, (AX)
	VMOVDQU X1, 12(AX)
	
	SUBQ $32, CX
	LEAQ 24(AX), AX
	LEAQ 32(BX), BX
	JMP avx2_loop

avx2_one:
	CMPQ CX, $24
	JB avx2_done

	VMOVDQU (BX), X0
	VPSRLD $4, X0, X1
	VPAND X9, X1, X1    // hi_nibbles
	VPAND X9, X0, X2    // lo_nibbles
	VPSHUFB X1, X10, X3 // hi
	VPSHUFB X2, X11, X4 // lo

	// validate
	VPTEST X3, X4
	JNZ avx2_done

	// translate
	VPCMPGTB X13, X0, X2 // compare 0x5E mask with in
	VPSUBB X2, X1, X1    // sub gt_5E with hi_nibbles
	VPSHUFB X1, X12, X2  // shuffle lut roll
	VPADDB X2, X0, X0    // Now simply add the delta values to the input

	AVX2_RESHUFFLE(X0, X6, X7, X8)
	VMOVDQU X0, (AX)
	SUBQ $16, CX

avx2_done:
	MOVQ CX, ret+48(FP)
	VZEROUPPER
	RET
