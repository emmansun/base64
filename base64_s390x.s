// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build !purego

#include "textflag.h"

DATA base64_const<>+0x00(SB)/8, $0x0f0e0d0c0b0a0908 // enccoding, byte order
DATA base64_const<>+0x08(SB)/8, $0x0706050403020100
DATA base64_const<>+0x10(SB)/8, $0x0a0b090a07080607 // enccoding, reshufling
DATA base64_const<>+0x18(SB)/8, $0x0405030401020001
DATA base64_const<>+0x20(SB)/8, $0x0fc0fc000fc0fc00 // mulhi mask
DATA base64_const<>+0x28(SB)/8, $0x0fc0fc000fc0fc00
DATA base64_const<>+0x30(SB)/8, $0x0400004004000040 // mulhi const
DATA base64_const<>+0x38(SB)/8, $0x0400004004000040
DATA base64_const<>+0x40(SB)/8, $0x003F03F0003F03F0 // mullo mask
DATA base64_const<>+0x48(SB)/8, $0x003F03F0003F03F0
DATA base64_const<>+0x50(SB)/8, $0x0100001001000010 // mullo const
DATA base64_const<>+0x58(SB)/8, $0x0100001001000010
GLOBL base64_const<>(SB), (NOPTR+RODATA), $96

DATA decode_const<>+0x00(SB)/8, $0x1010010204080408 // standard decode lut hi
DATA decode_const<>+0x08(SB)/8, $0x1010101010101010
DATA decode_const<>+0x10(SB)/8, $0x1511111111111111 // standard decode lut lo
DATA decode_const<>+0x18(SB)/8, $0x1111131A1B1B1B1A
DATA decode_const<>+0x20(SB)/8, $0x00101304BFBFB9B9 // standard decode lut roll
DATA decode_const<>+0x28(SB)/8, $0x0000000000000000
DATA decode_const<>+0x30(SB)/8, $0x4001400140014001 // reshuffle const0
DATA decode_const<>+0x38(SB)/8, $0x4001400140014001
DATA decode_const<>+0x40(SB)/8, $0x1000000110000001 // reshuffle const1
DATA decode_const<>+0x48(SB)/8, $0x1000000110000001
DATA decode_const<>+0x50(SB)/8, $0x010203050607090a // reshuffle mask
DATA decode_const<>+0x58(SB)/8, $0x0b0d0e0f00000000
DATA decode_const<>+0x60(SB)/8, $0x1010010204080428 // url decode lut hi
DATA decode_const<>+0x68(SB)/8, $0x1010101010101010
DATA decode_const<>+0x70(SB)/8, $0x1511111111111111 // url decode lut lo
DATA decode_const<>+0x78(SB)/8, $0x1111131B1B1A1B33
DATA decode_const<>+0x80(SB)/8, $0x00001104BFBFE0B9 // url decode lut roll
DATA decode_const<>+0x88(SB)/8, $0xB900000000000000
GLOBL decode_const<>(SB), (NOPTR+RODATA), $144

#define REV_BYTES V0
#define RESHUFFLE_MASK V1
#define MULHI_MASK V2
#define MULHI_CONST V3
#define MULLO_MASK V4
#define MULLO_CONST V5
#define RANGE1_END V6
#define RANGE0_END V7
#define LUT V8
#define ZERO V9
#define NEG V10

#define X0 V11
#define X1 V12
#define X2 V13

// check the byte in src1 is greater than the byte in src2
// mask is 0xFF (-1) for greater and 0x00 for others.
#define VCGTB(src1, src2, mask) \
	VSB src1, src2, mask        \
	VMXB NEG, mask, mask        \ 
	VMNB ZERO, mask, mask

//func encodeAsm(dst, src []byte, lut *[16]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R1
	MOVD src_base+24(FP), R2
	MOVD src_len+32(FP), R3
	MOVD lut+48(FP), R4
	VL (R4), LUT

	MOVD $base64_const<>(SB), R5
	VLM (R5), REV_BYTES, MULLO_CONST
	VREPIB $0x33, RANGE1_END
	VREPIB $0x19, RANGE0_END
	VREPIB $0xff, NEG
	VZERO ZERO

	MOVD $0, R4
loop:
	VL (R2), X0
	VPERM X0, X0, RESHUFFLE_MASK, X0
	VN X0, MULHI_MASK, X1
	VMLHH X1, MULHI_CONST, X1
	VN X0, MULLO_MASK, X2
	VMLHW X2, MULLO_CONST, X2
	VO X1, X2, X0

	VSB RANGE1_END, X0, X1
	VMXB ZERO, X1, X1

	VCGTB(X0, RANGE0_END, X2) // mask is 0xFF (-1) for range #[1..4] and 0x00 for range #0.
	VSB X2, X1, X1

	VPERM LUT, LUT, X1, X2
	VAB X2, X0, X0

	VPERM X0, X0, REV_BYTES, X0
	VST X0, 0(R1)(R4*1)

	ADD $16, R4
	LAY 12(R2), R2
	SUB $12, R3
	CMPBGE R3, $16, loop

done:
	MOVD R4, ret+56(FP)
	RET

#undef RESHUFFLE_MASK
#undef MULHI_CONST
#undef MULHI_MASK
#undef MULLO_CONST
#undef MULLO_MASK
#undef RANGE1_END
#undef RANGE0_END
#undef LUT
#undef ZERO
#undef NEG
#undef X0
#undef X1
#undef X2

#define LUT_HI V0
#define LUT_LO V1
#define LUT_ROLL V2
#define RESHUFFLE_CONST0 V3
#define RESHUFFLE_CONST1 V4
#define RESHUFFLE_MASK V5
#define ZERO V6
#define NEG V7
#define NIBBLE_MASK V8
#define DECODE_CONST V9
#define X0 V10
#define X1 V11
#define X2 V12
#define X3 V13

//func decodeStdAsm(dst, src []byte) int
TEXT ·decodeStdAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R1
	MOVD src_base+24(FP), R2
	MOVD src_len+32(FP), R3

	MOVD $decode_const<>(SB), R4
	VLM (R4), LUT_HI, RESHUFFLE_MASK
	VREPIB $0x0f, NIBBLE_MASK
	VREPIB $0x2f, DECODE_CONST
	VZERO ZERO

loop:
		VL (R2), X0
		// validate the input
		VESRLF $4, X0, X1
		VN X1, NIBBLE_MASK, X1 // high nibbles
		VN X0, NIBBLE_MASK, X2
		VPERM LUT_HI, LUT_HI, X1, X3
		VPERM LUT_LO, LUT_LO, X2, X2
		VN X2, X3, X2
		VCEQGS ZERO, X2, X2
		BNE done

		// decode the input
		VCEQB DECODE_CONST, X0, X2
		VAB X2, X1, X1
		VPERM LUT_ROLL, LUT_ROLL, X1, X2
		VAB X0, X2, X0

		VMLEB RESHUFFLE_CONST0, X0, X1
		VMLOB RESHUFFLE_CONST0, X0, X2
		VAH X1, X2, X0
		VMLEH RESHUFFLE_CONST1, X0, X1
		VMLOH RESHUFFLE_CONST1, X0, X2
		VAF X1, X2, X0

		VPERM X0, X0, RESHUFFLE_MASK, X0
		VST X0, (R1)

		LAY 16(R2), R2
		LAY 12(R1), R1
		SUB $16, R3
		CMPBGE R3, $24, loop

done:
	MOVD R3, ret+48(FP)
	RET
#undef LUT_HI
#undef LUT_LO
#undef LUT_ROLL
#undef RESHUFFLE_CONST0
#undef RESHUFFLE_CONST1
#undef RESHUFFLE_MASK

#define RESHUFFLE_CONST0 V0
#define RESHUFFLE_CONST1 V1
#define RESHUFFLE_MASK V2
#define LUT_HI V3
#define LUT_LO V4
#define LUT_ROLL V5

//func decodeUrlAsm(dst, src []byte) int
TEXT ·decodeUrlAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R1
	MOVD src_base+24(FP), R2
	MOVD src_len+32(FP), R3

	MOVD $decode_const<>(SB), R4
	VLM (R4), LUT_HI, RESHUFFLE_MASK
	VREPIB $0xff, NEG
	VREPIB $0x0f, NIBBLE_MASK
	VREPIB $0x5e, DECODE_CONST
	VZERO ZERO

loop:
		VL (R2), X0
		// validate the input
		VESRLF $4, X0, X1
		VN X1, NIBBLE_MASK, X1 // high nibbles
		VN X0, NIBBLE_MASK, X2
		VPERM LUT_HI, LUT_HI, X1, X3
		VPERM LUT_LO, LUT_LO, X2, X2
		VN X2, X3, X2
		VCEQGS ZERO, X2, X2
		BNE done

		// decode the input
		VCGTB(X0, DECODE_CONST, X2)
		VSB X2, X1, X1
		VPERM LUT_ROLL, LUT_ROLL, X1, X2
		VAB X0, X2, X0

		VMLEB RESHUFFLE_CONST0, X0, X1
		VMLOB RESHUFFLE_CONST0, X0, X2
		VAH X1, X2, X0
		VMLEH RESHUFFLE_CONST1, X0, X1
		VMLOH RESHUFFLE_CONST1, X0, X2
		VAF X1, X2, X0

		VPERM X0, X0, RESHUFFLE_MASK, X0
		VST X0, (R1)

		LAY 16(R2), R2
		LAY 12(R1), R1
		SUB $16, R3
		CMPBGE R3, $24, loop

done:
	MOVD R3, ret+48(FP)
	RET
