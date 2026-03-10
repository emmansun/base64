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

// AVX512 VBMI encode LUT (standard): LUT[i] = base64 char for 6-bit value i
// ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
DATA enc512_std_lut<>+0x00(SB)/8, $0x4847464544434241
DATA enc512_std_lut<>+0x08(SB)/8, $0x504F4E4D4C4B4A49
DATA enc512_std_lut<>+0x10(SB)/8, $0x5857565554535251
DATA enc512_std_lut<>+0x18(SB)/8, $0x6665646362615A59
DATA enc512_std_lut<>+0x20(SB)/8, $0x6E6D6C6B6A696867
DATA enc512_std_lut<>+0x28(SB)/8, $0x767574737271706F
DATA enc512_std_lut<>+0x30(SB)/8, $0x333231307A797877
DATA enc512_std_lut<>+0x38(SB)/8, $0x2F2B393837363534
GLOBL enc512_std_lut<>(SB), (NOPTR+RODATA), $64

// AVX512 VBMI encode LUT (URL-safe): same as std except [62]='-', [63]='_'
DATA enc512_url_lut<>+0x00(SB)/8, $0x4847464544434241
DATA enc512_url_lut<>+0x08(SB)/8, $0x504F4E4D4C4B4A49
DATA enc512_url_lut<>+0x10(SB)/8, $0x5857565554535251
DATA enc512_url_lut<>+0x18(SB)/8, $0x6665646362615A59
DATA enc512_url_lut<>+0x20(SB)/8, $0x6E6D6C6B6A696867
DATA enc512_url_lut<>+0x28(SB)/8, $0x767574737271706F
DATA enc512_url_lut<>+0x30(SB)/8, $0x333231307A797877
DATA enc512_url_lut<>+0x38(SB)/8, $0x5F2D393837363534
GLOBL enc512_url_lut<>(SB), (NOPTR+RODATA), $64

// AVX512 multishift encode shuffle table. This keeps the proven VBMI layout
// used by public AVX512 base64 implementations: each 32-bit chunk is arranged
// as [s1,s0,s2,s1], and two such chunks share a qword for VPMULTISHIFTQB.
DATA enc512_ms_shuffle<>+0x00(SB)/8, $0x0405030401020001
DATA enc512_ms_shuffle<>+0x08(SB)/8, $0x0A0B090A07080607
DATA enc512_ms_shuffle<>+0x10(SB)/8, $0x10110F100D0E0C0D
DATA enc512_ms_shuffle<>+0x18(SB)/8, $0x1617151613141213
DATA enc512_ms_shuffle<>+0x20(SB)/8, $0x1C1D1B1C191A1819
DATA enc512_ms_shuffle<>+0x28(SB)/8, $0x222321221F201E1F
DATA enc512_ms_shuffle<>+0x30(SB)/8, $0x2829272825262425
DATA enc512_ms_shuffle<>+0x38(SB)/8, $0x2E2F2D2E2B2C2A2B
GLOBL enc512_ms_shuffle<>(SB), (NOPTR+RODATA), $64

// AVX512 multishift encode selectors. Each qword repeats [10,4,22,16,42,36,54,48]
// for the [s1,s0,s2,s1 | s4,s3,s5,s4] packing above, producing 8 sextets.
// Store one 128-bit block and broadcast it to ZMM in the hot path.
DATA enc512_ms_shift<>+0x00(SB)/8, $0x3036242A1016040A
DATA enc512_ms_shift<>+0x08(SB)/8, $0x3036242A1016040A
GLOBL enc512_ms_shift<>(SB), (NOPTR+RODATA), $16

// AVX512 decode output compress table: uses VPERMB to compact 64 bytes → 48 bytes.
// After VPMADDUBSW+VPMADDWD+VPSHUFB (per-lane), valid decoded bytes are at positions [0..11]
// in each 16-byte lane (contiguous); bytes [12..15] are zero (VPSHUFB 0xFF mask entries).
// This table's first 48 entries pick 12 valid bytes from each of the 4 lanes:
// lane0=[0..11], lane1=[16..27], lane2=[32..43], lane3=[48..59]
DATA dec512_compress<>+0x00(SB)/8, $0x0706050403020100
DATA dec512_compress<>+0x08(SB)/8, $0x131211100B0A0908
DATA dec512_compress<>+0x10(SB)/8, $0x1B1A191817161514
DATA dec512_compress<>+0x18(SB)/8, $0x2726252423222120
DATA dec512_compress<>+0x20(SB)/8, $0x333231302B2A2928
DATA dec512_compress<>+0x28(SB)/8, $0x3B3A393837363534
DATA dec512_compress<>+0x30(SB)/8, $0x0000000000000000
DATA dec512_compress<>+0x38(SB)/8, $0x0000000000000000
GLOBL dec512_compress<>(SB), (NOPTR+RODATA), $64

// AVX512 decode std LUT low half: LUT[0..63], 0xFF=illegal, 6-bit value for legal base64 chars
DATA stddec512_lut_lo<>+0x00(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA stddec512_lut_lo<>+0x08(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA stddec512_lut_lo<>+0x10(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA stddec512_lut_lo<>+0x18(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA stddec512_lut_lo<>+0x20(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA stddec512_lut_lo<>+0x28(SB)/8, $0x3FFFFFFF3EFFFFFF
DATA stddec512_lut_lo<>+0x30(SB)/8, $0x3B3A393837363534
DATA stddec512_lut_lo<>+0x38(SB)/8, $0xFFFFFFFFFFFF3D3C
GLOBL stddec512_lut_lo<>(SB), (NOPTR+RODATA), $64

// AVX512 decode std LUT high half: LUT[64..127]
DATA stddec512_lut_hi<>+0x00(SB)/8, $0x06050403020100FF
DATA stddec512_lut_hi<>+0x08(SB)/8, $0x0E0D0C0B0A090807
DATA stddec512_lut_hi<>+0x10(SB)/8, $0x161514131211100F
DATA stddec512_lut_hi<>+0x18(SB)/8, $0xFFFFFFFFFF191817
DATA stddec512_lut_hi<>+0x20(SB)/8, $0x201F1E1D1C1B1AFF
DATA stddec512_lut_hi<>+0x28(SB)/8, $0x2827262524232221
DATA stddec512_lut_hi<>+0x30(SB)/8, $0x302F2E2D2C2B2A29
DATA stddec512_lut_hi<>+0x38(SB)/8, $0xFFFFFFFFFF333231
GLOBL stddec512_lut_hi<>(SB), (NOPTR+RODATA), $64

// AVX512 decode url LUT low half: LUT[0..63]
DATA urldec512_lut_lo<>+0x00(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA urldec512_lut_lo<>+0x08(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA urldec512_lut_lo<>+0x10(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA urldec512_lut_lo<>+0x18(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA urldec512_lut_lo<>+0x20(SB)/8, $0xFFFFFFFFFFFFFFFF
DATA urldec512_lut_lo<>+0x28(SB)/8, $0xFFFF3EFFFFFFFFFF
DATA urldec512_lut_lo<>+0x30(SB)/8, $0x3B3A393837363534
DATA urldec512_lut_lo<>+0x38(SB)/8, $0xFFFFFFFFFFFF3D3C
GLOBL urldec512_lut_lo<>(SB), (NOPTR+RODATA), $64

// AVX512 decode url LUT high half: LUT[64..127]
DATA urldec512_lut_hi<>+0x00(SB)/8, $0x06050403020100FF
DATA urldec512_lut_hi<>+0x08(SB)/8, $0x0E0D0C0B0A090807
DATA urldec512_lut_hi<>+0x10(SB)/8, $0x161514131211100F
DATA urldec512_lut_hi<>+0x18(SB)/8, $0x3FFFFFFFFF191817
DATA urldec512_lut_hi<>+0x20(SB)/8, $0x201F1E1D1C1B1AFF
DATA urldec512_lut_hi<>+0x28(SB)/8, $0x2827262524232221
DATA urldec512_lut_hi<>+0x30(SB)/8, $0x302F2E2D2C2B2A29
DATA urldec512_lut_hi<>+0x38(SB)/8, $0xFFFFFFFFFF333231
GLOBL urldec512_lut_hi<>(SB), (NOPTR+RODATA), $64

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

//func encodeAsm(dst, src []byte, lut *[16]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), AX
	MOVQ src_base+24(FP), BX
	MOVQ src_len+32(FP), CX
	MOVQ lut+48(FP), SI

	CMPQ CX, $64
	JB   enc_not_avx512
	CMPB ·useAVX512VBMI(SB), $1
	JE   avx512
enc_not_avx512:
	CMPB ·useAVX2(SB), $1
	JE   avx2

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

avx2_head:
	CMPQ CX, $28
	JB avx2_tail

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

avx2_loop:
		CMPQ CX, $28
		JB avx2_tail

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
		JMP avx2_loop

avx2_tail:
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

avx512:
	// Determine which 64-byte AVX512 encode LUT to use based on the 16-byte SSE lut passed in.
	// Standard lut has byte[12]=0xED; URL lut has byte[12]=0xEF.
	MOVQ SI, R9       // save lut pointer for AVX2 tail fallback
	MOVBLZX 12(SI), R8
	CMPB R8, $0xED
	JNE avx512_url_enc
	VMOVDQU32 enc512_std_lut<>(SB), Z4
	JMP avx512_enc_start
avx512_url_enc:
	VMOVDQU32 enc512_url_lut<>(SB), Z4
avx512_enc_start:
	VMOVDQU32 enc512_ms_shuffle<>(SB), Z5
	VBROADCASTI32X4 enc512_ms_shift<>(SB), Z6
	XORQ SI, SI       // SI = output byte offset

avx512_loop:
		// Require 64 bytes of input so the 64-byte ZMM load is always safe.
		// We process 48 of the 64 loaded bytes per iteration.
		CMPQ CX, $64
		JB avx512_done

		// Load 64 bytes from input (only first 48 are used; spread indices 0..47 ignore rest)
		VMOVDQU32 (BX), Z0

		// Reorder bytes into the multishift-friendly [s1,s0,s2,s1] pattern.
		VPERMB Z0, Z5, Z0

		// Extract 8 sextets from each qword in one instruction.
		VPMULTISHIFTQB Z6, Z0, Z0

		// Map 6-bit indices to base64 characters
		VPERMB Z4, Z0, Z0

		// Store 64 encoded bytes
		VMOVDQU32 Z0, (AX)(SI*1)

		ADDQ $64, SI
		SUBQ $48, CX
		LEAQ 48(BX), BX
		JMP avx512_loop

avx512_done:
	// Fall back to AVX2 for the remaining tail (CX in [16..63]).
	// The multishift path does not preserve AVX2 mulhi/mullo constants in Y7-Y10,
	// so reload the full AVX2 encode state before jumping into avx2_head.
	CMPQ CX, $16
	JB avx512_ret
	VBROADCASTI128 reshuffle_mask<>(SB), Y6
	VBROADCASTI128 mulhi_mask<>(SB), Y7
	VBROADCASTI128 mulhi_const<>(SB), Y8
	VBROADCASTI128 mullo_mask<>(SB), Y9
	VBROADCASTI128 mullo_const<>(SB), Y10
	VBROADCASTI128 range_0_end<>(SB), Y11
	VBROADCASTI128 range_1_end<>(SB), Y12
	VBROADCASTI128 (R9), Y13
	JMP avx2_head
avx512_ret:
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


#define AVX2_DECODE_RESHUFFLE(in_out, mask0, mask1, mask2) \
	VPMADDUBSW mask0, in_out, in_out;  \ // swap and merge adjacent 6-bit fields
	VPMADDWD mask1, in_out, in_out;    \ // swap and merge 12-bit words into a 24-bit word
	VPSHUFB mask2, in_out, in_out

//func decodeStdAsm(dst, src []byte) int
TEXT ·decodeStdAsm(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), AX
	MOVQ src_base+24(FP), BX
	MOVQ src_len+32(FP), CX

	CMPQ CX, $64
	JB   stddec_not_avx512
	CMPB ·useAVX512VBMI(SB), $1
	JE   avx512
stddec_not_avx512:
	CMPB ·useAVX2(SB), $1
	JE   avx2

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
		JB avx2_tail

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

avx2_tail:
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

avx512:
	// Load decode LUT split into two 64-byte halves for VPERMI2B.
	// Z4 = LUT[0..63] (standard), Z5 = LUT[64..127] (standard)
	VMOVDQU32 stddec512_lut_lo<>(SB), Z4
	VMOVDQU32 stddec512_lut_hi<>(SB), Z5
	VBROADCASTI32X4 dec_reshuffle_const0<>(SB), Z6
	VBROADCASTI32X4 dec_reshuffle_const1<>(SB), Z7
	VBROADCASTI32X4 dec_reshuffle_mask<>(SB), Z8
	VMOVDQU32 dec512_compress<>(SB), Z3   // compress permutation table (loaded once)

avx512_loop:
		CMPQ CX, $64
		JB avx512_done

		// Load 64 base64-encoded input bytes
		VMOVDQU32 (BX), Z0

		// Validate + translate: VPERMI2B uses Z0[i] bit6 to choose Z4 or Z5,
		// mapping each input char to its 6-bit decoded value (0xFF if illegal).
		// After this, Z0 is modified in-place with the translated values.
		VPERMI2B Z5, Z4, Z0

		// Detect any illegal characters (0xFF has bit7 set; valid values are 0x00..0x3F)
		VPXORD Z2, Z2, Z2          // Z2 = 0
		VPCMPB $1, Z2, Z0, K1      // K1[i] = 1 if Z0[i] < 0 (bit7 set = invalid char)
		KTESTQ K1, K1
		JNZ avx512_done             // bail on any invalid byte; caller handles via generic

		// Reshuffle 4×6-bit → 3×8-bit per 4-byte group (512-bit wide)
		VPMADDUBSW Z6, Z0, Z0      // merge pairs: [00aaaaaa 00bbbbbb] → [00000000 aaaaaabb bbbb0000]
		VPMADDWD Z7, Z0, Z0        // merge quads: produce 24-bit groups in 32-bit lanes
		VPSHUFB Z8, Z0, Z0         // per-lane: pack 3 valid bytes per 4, discard junk byte

		// Compress 64 bytes (3 valid + 1 junk per 4) → 48 contiguous bytes using VPERMB.
		// VPERMB Z0, Z3, Z0 means Z0[i] = old_Z0[Z3[i] & 63]: use Z3 as gather indices into Z0.
		VPERMB Z0, Z3, Z0

		// Store 48 output bytes: 32-byte YMM store + extract lane 2 for last 16
		VMOVDQU Y0, (AX)
		VEXTRACTI32X4 $2, Z0, X1
		VMOVDQU X1, 32(AX)

		SUBQ $64, CX
		LEAQ 48(AX), AX
		LEAQ 64(BX), BX
		JMP avx512_loop

avx512_done:
	// Fall back to AVX2 for the remaining tail (CX in [24..63]).
	// Y6-Y8 (dec_reshuffle_const0/1, dec_reshuffle_mask) are already valid as
	// the lower 256 bits of Z6-Z8; no VZEROUPPER needed (AVX2 uses VEX encoding).
	CMPQ CX, $24
	JB avx512_ret
	VBROADCASTI128 nibble_mask<>(SB), Y9
	VBROADCASTI128 stddec_lut_hi<>(SB), Y10
	VBROADCASTI128 stddec_lut_lo<>(SB), Y11
	VBROADCASTI128 stddec_lut_roll<>(SB), Y12
	JMP avx2_loop
avx512_ret:
	MOVQ CX, ret+48(FP)
	VZEROUPPER
	RET

//func decodeUrlAsm(dst, src []byte) int
TEXT ·decodeUrlAsm(SB),NOSPLIT,$0
	MOVQ dst_base+0(FP), AX
	MOVQ src_base+24(FP), BX
	MOVQ src_len+32(FP), CX

	CMPQ CX, $64
	JB   urldec_not_avx512
	CMPB ·useAVX512VBMI(SB), $1
	JE   avx512
urldec_not_avx512:
	CMPB ·useAVX2(SB), $1
	JE   avx2

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
		JB avx2_tail
	
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

avx2_tail:
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

avx512:
	// Load URL-safe decode LUT split into two 64-byte halves for VPERMI2B.
	// Z4 = LUT[0..63] (url), Z5 = LUT[64..127] (url)
	VMOVDQU32 urldec512_lut_lo<>(SB), Z4
	VMOVDQU32 urldec512_lut_hi<>(SB), Z5
	VBROADCASTI32X4 dec_reshuffle_const0<>(SB), Z6
	VBROADCASTI32X4 dec_reshuffle_const1<>(SB), Z7
	VBROADCASTI32X4 dec_reshuffle_mask<>(SB), Z8
	VMOVDQU32 dec512_compress<>(SB), Z3   // compress permutation table (loaded once)

avx512_loop:
		CMPQ CX, $64
		JB avx512_done

		// Load 64 base64-encoded input bytes
		VMOVDQU32 (BX), Z0

		// Validate + translate: VPERMI2B uses Z0[i] bit6 to choose Z4 or Z5.
		VPERMI2B Z5, Z4, Z0

		// Detect any illegal characters (0xFF has bit7 set; valid values are 0x00..0x3F)
		VPXORD Z2, Z2, Z2          // Z2 = 0
		VPCMPB $1, Z2, Z0, K1      // K1[i] = 1 if Z0[i] < 0 (bit7 set = invalid char)
		KTESTQ K1, K1
		JNZ avx512_done             // bail on any invalid byte

		// Reshuffle 4×6-bit → 3×8-bit per 4-byte group (512-bit wide)
		VPMADDUBSW Z6, Z0, Z0
		VPMADDWD Z7, Z0, Z0
		VPSHUFB Z8, Z0, Z0

		// Compress 64 bytes → 48 contiguous bytes using VPERMB.
		// VPERMB Z0, Z3, Z0 means Z0[i] = old_Z0[Z3[i] & 63]: use Z3 as gather indices into Z0.
		VPERMB Z0, Z3, Z0

		// Store 48 output bytes: 32-byte YMM store + extract lane 2 for last 16
		VMOVDQU Y0, (AX)
		VEXTRACTI32X4 $2, Z0, X1
		VMOVDQU X1, 32(AX)

		SUBQ $64, CX
		LEAQ 48(AX), AX
		LEAQ 64(BX), BX
		JMP avx512_loop

avx512_done:
	// Fall back to AVX2 for the remaining tail (CX in [24..63]).
	// Y6-Y8 (dec_reshuffle_const0/1, dec_reshuffle_mask) are already valid as
	// the lower 256 bits of Z6-Z8; no VZEROUPPER needed (AVX2 uses VEX encoding).
	CMPQ CX, $24
	JB avx512_ret
	VBROADCASTI128 nibble_mask<>(SB), Y9
	VBROADCASTI128 urldec_lut_hi<>(SB), Y10
	VBROADCASTI128 urldec_lut_lo<>(SB), Y11
	VBROADCASTI128 urldec_lut_roll<>(SB), Y12
	VBROADCASTI128 url_const_5e<>(SB), Y13
	JMP avx2_loop
avx512_ret:
	MOVQ CX, ret+48(FP)
	VZEROUPPER
	RET
