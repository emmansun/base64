// Reference:
// https://github.com/aklomp/base64/blob/master/lib/arch/ssse3/enc_loop.c
// https://github.com/aklomp/base64/blob/master/lib/arch/ssse3/dec_loop.c
// https://gist.github.com/emmansun/c0f174a614a005f80f51b033500fd7fc
// Faster Base64 Encoding and Decoding using AVX2 Instructions
//go:build amd64 && !purego

#include "textflag.h"

// shuffle byte order for input 12 bytes
DATA reshuffle_mask<>+0x00(SB)/8, $0x0405030401020001
DATA reshuffle_mask<>+0x08(SB)/8, $0x0a0b090a07080607
GLOBL reshuffle_mask<>(SB), (NOPTR+RODATA), $16

// shuffle byte order for input 32 bytes
DATA reshuffle_mask32<>+0x00(SB)/8, $0x0809070805060405
DATA reshuffle_mask32<>+0x08(SB)/8, $0x0e0f0d0e0b0c0a0b
DATA reshuffle_mask32<>+0x10(SB)/8, $0x0405030401020001
DATA reshuffle_mask32<>+0x18(SB)/8, $0x0a0b090a07080607
GLOBL reshuffle_mask32<>(SB), (NOPTR+RODATA), $32

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

// const value 25
DATA range_0_end<>+0x00(SB)/8, $0x1919191919191919
DATA range_0_end<>+0x08(SB)/8, $0x1919191919191919
GLOBL range_0_end<>(SB), (NOPTR+RODATA), $16

// const value 51
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

// const value 94
DATA url_const_5e<>+0x00(SB)/8, $0x5E5E5E5E5E5E5E5E
DATA url_const_5e<>+0x08(SB)/8, $0x5E5E5E5E5E5E5E5E
GLOBL url_const_5e<>(SB), (NOPTR+RODATA), $16

// below for decode reshuffle
DATA dec_reshuffle_const0<>+0x00(SB)/8, $0x0140014001400140
DATA dec_reshuffle_const0<>+0x08(SB)/8, $0x0140014001400140
GLOBL dec_reshuffle_const0<>(SB), (NOPTR+RODATA), $16

DATA dec_reshuffle_const1<>+0x00(SB)/8, $0x0001100000011000
DATA dec_reshuffle_const1<>+0x08(SB)/8, $0x0001100000011000
GLOBL dec_reshuffle_const1<>(SB), (NOPTR+RODATA), $16

DATA dec_reshuffle_mask<>+0x00(SB)/8, $0x090A040506000102
DATA dec_reshuffle_mask<>+0x08(SB)/8, $0xFFFFFFFF0C0D0E08
GLOBL dec_reshuffle_mask<>(SB), (NOPTR+RODATA), $16

// Requires SSSE3
#define SSE_ENC(in_out, lut, tmp1, tmp2) \
	\ // enc reshuffle
	\ // Input, bytes MSB to LSB:
	\ // 0 0 0 0 l k j i h g f e d c b a
	PSHUFB reshuffle_mask<>(SB), in_out;           \
	\ // in_out, bytes MSB to LSB:
	\ // k l j k
	\ // h i g h
	\ // e f d e
	\ // b c a b	
	MOVOU in_out, tmp1;                            \
	PAND mulhi_mask<>(SB), tmp1;                   \
	\ // bits, upper case are most significant bits, lower case are least significant bits
	\ // 0000kkkk LL000000 JJJJJJ00 00000000
	\ // 0000hhhh II000000 GGGGGG00 00000000
	\ // 0000eeee FF000000 DDDDDD00 00000000
	\ // 0000bbbb CC000000 AAAAAA00 00000000	
	PMULHUW mulhi_const<>(SB), tmp1;               \ // shift right high 16 bits by 6 and low 16 bits by 10 bits
	\ // 00000000 00kkkkLL 00000000 00JJJJJJ
	\ // 00000000 00hhhhII 00000000 00GGGGGG
	\ // 00000000 00eeeeFF 00000000 00DDDDDD
	\ // 00000000 00bbbbCC 00000000 00AAAAAA	 
	PAND mullo_mask<>(SB), in_out;                 \
	\ // 00000000 00llllll 000000jj KKKK0000
	\ // 00000000 00iiiiii 000000gg HHHH0000
	\ // 00000000 00ffffff 000000dd EEEE0000
	\ // 00000000 00cccccc 000000aa BBBB0000	
	PMULLW mullo_const<>(SB), in_out;              \ // shift left high 16 bits by 8 bits, and low 16 bits by 4 bits
	\ // 00llllll 00000000 00jjKKKK 00000000
	\ // 00iiiiii 00000000 00ggHHHH 00000000
	\ // 00ffffff 00000000 00ddEEEE 00000000
	\ // 00cccccc 00000000 00aaBBBB 00000000	
	POR tmp1, in_out;                              \
	\ // 00llllll 00kkkkLL 00jjKKKK 00JJJJJJ
	\ // 00iiiiii 00hhhhII 00ggHHHH 00GGGGGG
	\ // 00ffffff 00eeeeFF 00ddEEEE 00DDDDDD
	\ // 00cccccc 00bbbbCC 00aaBBBB 00AAAAAA	
	\ // enc translate
	MOVOU in_out, tmp1;                            \
	MOVOU in_out, tmp2;                            \
	PSUBUSB range_1_end<>(SB), tmp2;               \ // Create LUT indices from the input. The index for range #0 is right, others are 1 less than expected.
	PCMPGTB range_0_end<>(SB), tmp1;               \ // mask is 0xFF (-1) for range #[1..4] and 0x00 for range #0.
	PSUBB tmp1, tmp2;                              \ // Subtract -1, so add 1 to indices for range #[1..4]. All indices are now correct.
	MOVOU lut, tmp1;                               \
	PSHUFB tmp2, tmp1;                             \ // get offsets and add offsets to input value.
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
	VPSUBUSB range_1_end<>(SB), in_out, tmp1;      \ // Create LUT indices from the input. The index for range #0 is right, others are 1 less than expected.
	VPCMPGTB range_0_end<>(SB), in_out, tmp2;      \ // mask is 0xFF (-1) for range #[1..4] and 0x00 for range #0.
	VPSUBB tmp2, tmp1, tmp1;                       \ // Subtract -1, so add 1 to indices for range #[1..4]. All indices are now correct.
	VPSHUFB tmp1, lut, tmp1;                       \ // get offsets and add offsets to input value.
	VPADDB tmp1, in_out, in_out

#define AVX2_ENC_RESUFFLE(in_out, tmp, mulhi_mask, mulhi_const, mullo_mask, mullo_const) \
	VPAND mulhi_mask, in_out, tmp;                     \
	VPMULHUW mulhi_const, tmp, tmp;                    \
	VPAND mullo_mask, in_out, in_out;                  \
	VPMULLW mullo_const, in_out, in_out;               \
	VPOR tmp, in_out, in_out

#define AVX2_ENC_TRANSLATE(in_out, range1, range0, lut, tmp1, tmp2)     \
	VPSUBUSB range1, in_out, tmp1;                    \ // Create LUT indices from the input. The index for range #0 is right, others are 1 less than expected.
	VPCMPGTB range0, in_out, tmp2;                    \ // mask is 0xFF (-1) for range #[1..4] and 0x00 for range #0.
	VPSUBB tmp2, tmp1, tmp1;                          \ // Subtract -1, so add 1 to indices for range #[1..4]. All indices are now correct.
	VPSHUFB tmp1, lut, tmp1;                          \ // get offsets and add offsets to input value.
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

avx2_first:
	CMPQ CX, $28
	JB avx2_one

	// load data, bytes MSB to LSB:
	// 0 0 0 0 x w v u t s r q p o n m
	// 0 0 0 0 l k j i h g f e d c b a
	VMOVDQU (BX), X0
	VMOVDQU 12(BX), X1
	VINSERTI128 $1, X1, Y0, Y0

	// enc reshuffle
	VPSHUFB Y6, Y0, Y0
	AVX2_ENC_RESUFFLE(Y0, Y1, Y7, Y8, Y9, Y10)

	// enc translate
	AVX2_ENC_TRANSLATE(Y0, Y12, Y11, Y13, Y1, Y2)

	// store encoded
	VMOVDQU Y0, (AX)(SI*1) 

	ADDQ $32, SI
	SUBQ $24, CX

	LEAQ 24(BX), BX	

avx2_loop_28:
	CMPQ CX, $28
	JB avx2_one

	// load data, bytes MSB to LSB:
	// 0 0 0 0 x w v u t s r q p o n m
	// l k j i h g f e d c b a 0 0 0 0	
	VMOVDQU -4(BX), Y0

	// enc reshuffle
	VPSHUFB reshuffle_mask32<>(SB), Y0, Y0
	AVX2_ENC_RESUFFLE(Y0, Y1, Y7, Y8, Y9, Y10)

	// enc translate
	AVX2_ENC_TRANSLATE(Y0, Y12, Y11, Y13, Y1, Y2)

	// store encoded
	VMOVDQU Y0, (AX)(SI*1) 

	ADDQ $32, SI
	SUBQ $24, CX

	LEAQ 24(BX), BX	
	JMP avx2_loop_28

avx2_one:
	CMPQ CX, $16
	JB avx2_done

	// load data
	VMOVDQU (BX), X0

	// enc reshuffle
	VPSHUFB X6, X0, X0
	AVX2_ENC_RESUFFLE(X0, X1, X7, X8, X9, X10)

	// enc translate
	AVX2_ENC_TRANSLATE(X0, X12, X11, X13, X1, X2)

	// store encoded
	VMOVDQU X0, (AX)(SI*1) 
	ADDQ $16, SI

avx2_done:
	MOVQ SI, ret+56(FP)
	VZEROUPPER
	RET

#define SSE_DECODE_VALIDATE(in, hi_nibbles, tmp, lut_hi, lut_lo, zero, out) \
	MOVOU in, hi_nibbles;                 \
	MOVOU in, tmp;                        \
	PSRLL $4, hi_nibbles;                 \
	PAND nibble_mask<>(SB), hi_nibbles;   \ // hi_nibbles
	PAND nibble_mask<>(SB), tmp;          \ // lo_nibbles
	PSHUFB hi_nibbles, lut_hi;            \ // hi
	PSHUFB tmp, lut_lo;                   \ // lo
	\// validate
	PAND lut_lo, lut_hi;                  \ // hi & lo
	PCMPGTB zero, lut_hi;                 \ // compare with zero
	PMOVMSKB lut_hi, out;                 \ // mm_movemask_epi8

#define AVX_DECODE_VALIDATE(in, hi_nibbles, tmp1, tmp2, lut_hi, lut_lo, zero, out) \
	VPSRLD $4, in, hi_nibbles;                         \
	VPAND nibble_mask<>(SB), hi_nibbles, hi_nibbles;   \ // hi_nibbles
	VPAND nibble_mask<>(SB), in, tmp1;                 \ // lo_nibbles
	VPSHUFB hi_nibbles, lut_hi, tmp2;                  \ // hi
	VPSHUFB tmp1, lut_lo, tmp1;                        \ // lo
	\// validate
	VPAND tmp1, tmp2, tmp2;                            \ // hi & lo
	VPCMPGTB zero, tmp2, tmp2;                         \ // compare with zero
	VPMOVMSKB tmp2, out

#define AVX2_DECODE_HI_LO(in, hi_nibbles, hi, lo, nibble_mask, lut_hi, lut_lo) \
	VPSRLD $4, in, hi_nibbles;                    \
	VPAND nibble_mask, hi_nibbles, hi_nibbles;    \ // hi_nibbles
	VPAND nibble_mask, in, lo;                    \ // lo_nibbles
	VPSHUFB hi_nibbles, lut_hi, hi;               \ // hi
	VPSHUFB lo, lut_lo, lo;                       \ // lo

// uses PMADDUBSW (_mm_maddubs_epi16) / PMADDWL (_mm_madd_epi16) and PSHUFB to reshuffle bits.
//
// in bits, upper case are most significant bits, lower case are least significant bits
// 00llllll 00kkkkLL 00jjKKKK 00JJJJJJ
// 00iiiiii 00hhhhII 00ggHHHH 00GGGGGG
// 00ffffff 00eeeeFF 00ddEEEE 00DDDDDD
// 00cccccc 00bbbbCC 00aaBBBB 00AAAAAA
//
// out bits, upper case are most significant bits, lower case are least significant bits:
// 00000000 00000000 00000000 00000000
// LLllllll KKKKkkkk JJJJJJjj IIiiiiii
// HHHHhhhh GGGGGGgg FFffffff EEEEeeee
// DDDDDDdd CCcccccc BBBBbbbb AAAAAAaa
#define SSE_DECODE_RESHUFFLE(in_out) \
	PMADDUBSW dec_reshuffle_const0<>(SB), in_out;  \ // swap and merge adjacent 6-bit fields
	\ // 0000kkkk LLllllll 0000JJJJ JJjjKKKK
	\ // 0000hhhh IIiiiiii 0000GGGG GGggHHHH
	\ // 0000eeee FFffffff 0000DDDD DDddEEEE
	\ // 0000bbbb CCcccccc 0000AAAA AAaaBBBB	
	PMADDWL dec_reshuffle_const1<>(SB), in_out;    \ // swap and merge 12-bit words into a 24-bit word
	\ // 00000000 JJJJJJjj KKKKkkkk LLllllll
	\ // 00000000 GGGGGGgg HHHHhhhh IIiiiiii
	\ // 00000000 DDDDDDdd EEEEeeee FFffffff
	\ // 00000000 AAAAAAaa BBBBbbbb CCcccccc	
	PSHUFB dec_reshuffle_mask<>(SB), in_out

#define AVX_DECODE_RESHUFFLE(in_out) \
	VPMADDUBSW dec_reshuffle_const0<>(SB), in_out, in_out;  \ // swap and merge adjacent 6-bit fields
	VPMADDWD dec_reshuffle_const1<>(SB), in_out, in_out;    \ // swap and merge 12-bit words into a 24-bit word
	VPSHUFB dec_reshuffle_mask<>(SB), in_out, in_out

#define AVX2_DECODE_RESHUFFLE(in_out, mask0, mask1, mask2) \
	VPMADDUBSW mask0, in_out, in_out;  \ // swap and merge adjacent 6-bit fields
	VPMADDWD mask1, in_out, in_out;    \ // swap and merge 12-bit words into a 24-bit word
	VPSHUFB mask2, in_out, in_out

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

	// load data
	MOVOU (BX), X0

	// validate
	MOVOU stddec_lut_hi<>(SB), X10 // lut_hi
	MOVOU stddec_lut_lo<>(SB), X11 // lut_lo
	SSE_DECODE_VALIDATE(X0, X1, X2, X10, X11, X12, SI)
	CMPQ SI, $0
	JNE done

	// translate
	MOVOU nibble_mask<>(SB), X2
	PCMPEQB X0, X2                  // compare 0x2F with in
	PADDB X2, X1                    // add eq_2F with hi_nibbles
	MOVOU stddec_lut_roll<>(SB), X2
	PSHUFB X1, X2                   // shuffle lut roll
	PADDB X2, X0                    // Now simply add the delta values to the input

	SSE_DECODE_RESHUFFLE(X0)
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

	// load data
	VMOVDQU (BX), X0

	// valiate
	AVX_DECODE_VALIDATE(X0, X1, X2, X3, X10, X11, X12, SI)
	CMPQ SI, $0
	JNE avx_done

	// translate
	VPCMPEQB nibble_mask<>(SB), X0, X2 // compare 0x2F with in
	VPADDB X2, X1, X1                  // add eq_2F with hi_nibbles
	VPSHUFB X1, X13, X2                // shuffle lut roll
	VPADDB X2, X0, X0                  // Now simply add the delta values to the input

	AVX_DECODE_RESHUFFLE(X0)
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
	VBROADCASTI128 dec_reshuffle_mask<>(SB), Y8

avx2_loop:
	CMPQ CX, $40
	JB avx2_one

	// load data	
	VMOVDQU (BX), Y0

	// validate
	AVX2_DECODE_HI_LO(Y0, Y1, Y3, Y4, Y9, Y10, Y11)
	VPTEST Y3, Y4
	JNZ avx2_done

	// translate
	VPCMPEQB Y9, Y0, Y2 // compare 0x2F with in
	VPADDB Y2, Y1, Y1   // add eq_2F with hi_nibbles
	VPSHUFB Y1, Y12, Y2 // shuffle lut roll
	VPADDB Y2, Y0, Y0   // Now simply add the delta values to the input

	AVX2_DECODE_RESHUFFLE(Y0, Y6, Y7, Y8)
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

	// load data
	VMOVDQU (BX), X0

	// validate
	AVX2_DECODE_HI_LO(X0, X1, X3, X4, X9, X10, X11)
	VPTEST X3, X4
	JNZ avx2_done

	// translate
	VPCMPEQB X9, X0, X2 // compare 0x2F with in
	VPADDB X2, X1, X1   // add eq_2F with hi_nibbles
	VPSHUFB X1, X12, X2 // shuffle lut roll
	VPADDB X2, X0, X0   // Now simply add the delta values to the input

	AVX2_DECODE_RESHUFFLE(X0, X6, X7, X8)
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

	// load data
	MOVOU (BX), X0

	// validate
	MOVOU urldec_lut_hi<>(SB), X10 // lut_hi
	MOVOU urldec_lut_lo<>(SB), X11 // lut_lo
	SSE_DECODE_VALIDATE(X0, X1, X2, X10, X11, X12, SI)
	CMPQ SI, $0
	JNE done

	// translate
	MOVOU X0, X2
	PCMPGTB url_const_5e<>(SB), X2 // compare 0x5E with in
	PSUBB X2, X1                  // sub gt_5E with hi_nibbles
	MOVOU urldec_lut_roll<>(SB), X2
	PSHUFB X1, X2                 // shuffle lut roll
	PADDB X2, X0                  // Now simply add the delta values to the input

	SSE_DECODE_RESHUFFLE(X0)
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

	// load data
	VMOVDQU (BX), X0

	// validate
	AVX_DECODE_VALIDATE(X0, X1, X2, X3, X10, X11, X12, SI)
	CMPQ SI, $0
	JNE avx_done

	// translate
	VPCMPGTB url_const_5e<>(SB), X0, X2 // compare 0x5E with in
	VPSUBB X2, X1, X1                  // sub gt_5E with hi_nibbles
	VPSHUFB X1, X13, X2                // shuffle lut roll
	VPADDB X2, X0, X0                  // Now simply add the delta values to the input

	AVX_DECODE_RESHUFFLE(X0)
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
	VBROADCASTI128 dec_reshuffle_mask<>(SB), Y8
	VBROADCASTI128 url_const_5e<>(SB), Y13

avx2_loop:
	CMPQ CX, $40
	JB avx2_one
	
	// load data
	VMOVDQU (BX), Y0

	// validate
	AVX2_DECODE_HI_LO(Y0, Y1, Y3, Y4, Y9, Y10, Y11)
	VPTEST Y3, Y4
	JNZ avx2_done

	// translate
	VPCMPGTB Y13, Y0, Y2 // compare 0x5E with in
	VPSUBB Y2, Y1, Y1    // sub gt_5E with hi_nibbles
	VPSHUFB Y1, Y12, Y2  // shuffle lut roll
	VPADDB Y2, Y0, Y0    // Now simply add the delta values to the input

	AVX2_DECODE_RESHUFFLE(Y0, Y6, Y7, Y8)
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

	// load data
	VMOVDQU (BX), X0

	// validate
	AVX2_DECODE_HI_LO(X0, X1, X3, X4, X9, X10, X11)
	VPTEST X3, X4
	JNZ avx2_done

	// translate
	VPCMPGTB X13, X0, X2 // compare 0x5E with in
	VPSUBB X2, X1, X1    // sub gt_5E with hi_nibbles
	VPSHUFB X1, X12, X2  // shuffle lut roll
	VPADDB X2, X0, X0    // Now simply add the delta values to the input

	AVX2_DECODE_RESHUFFLE(X0, X6, X7, X8)
	VMOVDQU X0, (AX)
	SUBQ $16, CX

avx2_done:
	MOVQ CX, ret+48(FP)
	VZEROUPPER
	RET
