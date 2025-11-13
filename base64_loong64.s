// Copyright 2025 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build !purego

// The instruction references include
// https://gitlab.quantr.hk/quantr/toolchain/qemu/-/blob/master/target/loongarch/insns.decode
// https://jia.je/unofficial-loongarch-intrinsics-guide

#include "textflag.h"

DATA base64_const<>+0x00(SB)/8, $0x0405030401020001 // shuffle byte order for input 12 bytes
DATA base64_const<>+0x08(SB)/8, $0x0a0b090a07080607 
DATA base64_const<>+0x10(SB)/8, $0x0FC0FC000FC0FC00 // mulhi mask
DATA base64_const<>+0x18(SB)/8, $0x0FC0FC000FC0FC00
DATA base64_const<>+0x20(SB)/8, $0x0006000a0006000a // shift right mask
DATA base64_const<>+0x28(SB)/8, $0x0006000a0006000a
DATA base64_const<>+0x30(SB)/8, $0x003F03F0003F03F0 // mullo mask
DATA base64_const<>+0x38(SB)/8, $0x003F03F0003F03F0
DATA base64_const<>+0x40(SB)/8, $0x0008000400080004 // shift left mask
DATA base64_const<>+0x48(SB)/8, $0x0008000400080004
DATA base64_const<>+0x50(SB)/8, $0x3333333333333333 // range 1 end
DATA base64_const<>+0x58(SB)/8, $0x3333333333333333 // range 1 end
DATA base64_const<>+0x60(SB)/8, $0x1919191919191919 // range 0 end
DATA base64_const<>+0x68(SB)/8, $0x1919191919191919 // range 0 end
GLOBL base64_const<>(SB), (NOPTR+RODATA), $112

DATA decode_const<>+0x00(SB)/8, $0x0804080402011010 // standard decode lut hi
DATA decode_const<>+0x08(SB)/8, $0x1010101010101010
DATA decode_const<>+0x10(SB)/8, $0x1111111111111115 // standard decode lut lo
DATA decode_const<>+0x18(SB)/8, $0x1A1B1B1B1A131111
DATA decode_const<>+0x20(SB)/8, $0x2F2F2F2F2F2F2F2F // standard decode mask
DATA decode_const<>+0x28(SB)/8, $0x2F2F2F2F2F2F2F2F
DATA decode_const<>+0x30(SB)/8, $0xB9B9BFBF04131000 // standard decode lut roll
DATA decode_const<>+0x38(SB)/8, $0x0000000000000000
DATA decode_const<>+0x40(SB)/8, $0x2804080402011010 // url decode lut hi
DATA decode_const<>+0x48(SB)/8, $0x1010101010101010
DATA decode_const<>+0x50(SB)/8, $0x1111111111111115 // url decode lut lo
DATA decode_const<>+0x58(SB)/8, $0x331B1A1B1B131111
DATA decode_const<>+0x60(SB)/8, $0x5E5E5E5E5E5E5E5E // url decode mask
DATA decode_const<>+0x68(SB)/8, $0x5E5E5E5E5E5E5E5E
DATA decode_const<>+0x70(SB)/8, $0xB9E0BFBF04110000 // url decode lut roll
DATA decode_const<>+0x78(SB)/8, $0x00000000000000B9
DATA decode_const<>+0x80(SB)/8, $0x0140014001400140 // decode reshufling constant 0
DATA decode_const<>+0x88(SB)/8, $0x0140014001400140
DATA decode_const<>+0x90(SB)/8, $0x0001100000011000 // decode reshufling constant 1
DATA decode_const<>+0x98(SB)/8, $0x0001100000011000
DATA decode_const<>+0xA0(SB)/8, $0x090A040506000102 // decode reshufling mask
DATA decode_const<>+0xA8(SB)/8, $0xFFFFFFFF0C0D0E08
GLOBL decode_const<>(SB), (NOPTR+RODATA), $176

#define RESHUFFLE_MASK V0
#define SHIFT_RIGHT_MASK V1
#define MULHI_MASK V2
#define SHIFT_LEFT_MASK V3
#define MULLO_MASK V4
#define RANGE1_END V5
#define RANGE0_END V6
#define LUT V7

//func encodeAsm(dst, src []byte, lut *[16]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVV dst_base+0(FP), R5
	MOVV src_base+24(FP), R6
	MOVV src_len+32(FP), R7
	MOVV lut+48(FP), R8

	MOVV $base64_const<>(SB), R9
	VMOVQ (0*16)(R9), RESHUFFLE_MASK
	VMOVQ (1*16)(R9), MULHI_MASK
	VMOVQ (2*16)(R9), SHIFT_RIGHT_MASK
	VMOVQ (3*16)(R9), MULLO_MASK
	VMOVQ (4*16)(R9), SHIFT_LEFT_MASK
	VMOVQ (5*16)(R9), RANGE1_END
	VMOVQ (6*16)(R9), RANGE0_END
	VMOVQ (R8), LUT

	MOVV $16, R10
	MOVV R5, R11 			 // save dst pointer
	
loop:
		VMOVQ (R6), V8               // load 16 bytes input
		WORD $0xd502108              // VSHUFB RESHUFFLE_MASK, V8, V8, V8   // reshuffle bytes
		VANDV MULHI_MASK, V8, V9
		VSRLH SHIFT_RIGHT_MASK, V9, V9
		VANDV MULLO_MASK, V8, V8
		VSLLH SHIFT_LEFT_MASK, V8, V8
		VORV V9, V8, V8

		WORD $0x704c1509             // VSSUBBU RANGE1_END, V8, V9
		WORD $0x700820ca             // VSLTBU V8, RANGE0_END, V10
		VSUBB V10, V9, V9
		WORD $0xd549ce9              // VSHUFB V9, LUT, LUT, V9
		VADDB V9, V8, V8
		VMOVQ V8, (R5)               // store 16 bytes output

		ADDV $12, R6, R6
		SUBV $12, R7, R7
		ADDV $16, R5, R5

		BGEU R7, R10, loop
done:
	SUBV R11, R5
	MOVV R5, ret+56(FP)
	RET

#undef RESHUFFLE_MASK
#undef SHIFT_RIGHT_MASK
#undef MULHI_MASK
#undef SHIFT_LEFT_MASK
#undef MULLO_MASK
#undef RANGE1_END
#undef RANGE0_END
#undef LUT

#define NIBBLE_MASK V0
#define LUT_HI V1
#define LUT_LO V2
#define DECODE_END V3
#define LUT_ROLL V4
#define RESHUFFLE_CONST0 V5
#define RESHUFFLE_CONST1 V6
#define RESHUFFLE_MASK V7

//func decodeStdAsm(dst, src []byte) int
TEXT ·decodeStdAsm(SB),NOSPLIT,$0
	MOVV dst_base+0(FP), R5
	MOVV src_base+24(FP), R6
	MOVV src_len+32(FP), R7

	MOVV $decode_const<>(SB), R8
	VMOVQ (0*16)(R8), LUT_HI
	VMOVQ (1*16)(R8), LUT_LO
	VMOVQ (2*16)(R8), DECODE_END
	VMOVQ (3*16)(R8), LUT_ROLL
	VMOVQ (8*16)(R8), RESHUFFLE_CONST0
	VMOVQ (9*16)(R8), RESHUFFLE_CONST1
	VMOVQ (10*16)(R8), RESHUFFLE_MASK
	MOVV $24, R10
loop:
		VMOVQ (R6), V8        // load 16 bytes input
		// validate the input data
		VSRLB $4, V8, V9      // high nibble
		VANDB $0xf, V8, V10   // low nibble
		WORD $0xd54842b       // VSHUFB V9, LUT_HI, LUT_HI, V11
		WORD $0xd55084a       // VSHUFB V10, LUT_LO, LUT_LO, V10
		VANDV V11, V10, V10
		VSETEQV V10, FCC0
		BFPF done

		// translate
		VSEQB V8, DECODE_END, V10 // compare 0x2F with input bytes
		VADDB V9, V10, V10        // add eq_2F with hi_nibbles
		WORD $0xd55108a           // VSHUFB V10, LUT_ROLL, LUT_ROLL, V10
		VADDB V10, V8, V8         // Now simply add the delta values to the input

		// reshuffle output bytes
		VMULWEVHBU V8, RESHUFFLE_CONST0, V9
		WORD $0x70b620a9          // vmaddwod.h.bu V8, RESHUFFLE_CONST0, V9              

		VMULWEVWHU V9, RESHUFFLE_CONST1, V8
		WORD $0x70b6a4c8          // vmaddwod.w.hu V9, RESHUFFLE_CONST1, V8

		WORD $0xd53a108           // VSHUFB RESHUFFLE_MASK, V8, V8, V8
		VMOVQ V8, (R5)            // store 12 bytes output

		ADDV $12, R5, R5
		SUBV $16, R7, R7
		ADDV $16, R6, R6
		BGEU R7, R10, loop
done:
	MOVV R7, ret+48(FP)
	RET

//func decodeUrlAsmdst, src []byte) int
TEXT ·decodeUrlAsm(SB),NOSPLIT,$0
	MOVV dst_base+0(FP), R5
	MOVV src_base+24(FP), R6
	MOVV src_len+32(FP), R7

	MOVV $decode_const<>(SB), R8
	VMOVQ (4*16)(R8), LUT_HI
	VMOVQ (5*16)(R8), LUT_LO
	VMOVQ (6*16)(R8), DECODE_END
	VMOVQ (7*16)(R8), LUT_ROLL
	VMOVQ (8*16)(R8), RESHUFFLE_CONST0
	VMOVQ (9*16)(R8), RESHUFFLE_CONST1
	VMOVQ (10*16)(R8), RESHUFFLE_MASK
	MOVV $24, R10
loop:
		VMOVQ (R6), V8        // load 16 bytes input
		// validate the input data
		VSRLB $4, V8, V9      // high nibble
		VANDB $0xf, V8, V10   // low nibble
		WORD $0xd54842b       // VSHUFB V9, LUT_HI, LUT_HI, V11
		WORD $0xd55084a       // VSHUFB V10, LUT_LO, LUT_LO, V10
		VANDV V11, V10, V10
		VSETEQV V10, FCC0
		BFPF done

		// translate
		WORD $0x7008206a          // compare 0x5E with input bytes: VSLTBU V8, DECODE_END, V10
		VSUBB V10, V9, V10        // sub gt_5E with hi_nibbles
		WORD $0xd55108a           // VSHUFB V10, LUT_ROLL, LUT_ROLL, V10
		VADDB V10, V8, V8         // Now simply add the delta values to the input

		// reshuffle output bytes
		VMULWEVHBU V8, RESHUFFLE_CONST0, V9
		WORD $0x70b620a9          // vmaddwod.h.bu V8, RESHUFFLE_CONST0, V9              

		VMULWEVWHU V9, RESHUFFLE_CONST1, V8
		WORD $0x70b6a4c8          // vmaddwod.w.hu V9, RESHUFFLE_CONST1, V8

		WORD $0xd53a108           // VSHUFB RESHUFFLE_MASK, V8, V8, V8
		VMOVQ V8, (R5)            // store 12 bytes output

		ADDV $12, R5, R5
		SUBV $16, R7, R7
		ADDV $16, R6, R6
		BGEU R7, R10, loop
done:
	MOVV R7, ret+48(FP)
	RET
