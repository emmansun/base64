// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build !purego

#include "textflag.h"

DATA base64_const<>+0x00(SB)/8, $0x0f0e0d0c0b0a0908 // enccoding, byte order
DATA base64_const<>+0x08(SB)/8, $0x0706050403020100
DATA base64_const<>+0x10(SB)/8, $0x0a0b090a07080607 // enccoding, reshufling
DATA base64_const<>+0x18(SB)/8, $0x0405030401020001
DATA base64_const<>+0x20(SB)/8, $0x1010010204080408 // STD LUT HI
DATA base64_const<>+0x28(SB)/8, $0x1010101010101010
DATA base64_const<>+0x30(SB)/8, $0x1511111111111111 // STD LUT LO
DATA base64_const<>+0x38(SB)/8, $0x1111131A1B1B1B1A
DATA base64_const<>+0x40(SB)/8, $0x00101304BFBFB9B9 // STD LUT ROLL
DATA base64_const<>+0x48(SB)/8, $0x0000000000000000
DATA base64_const<>+0x50(SB)/8, $0x1010010204080428 // URL LUT HI
DATA base64_const<>+0x58(SB)/8, $0x1010101010101010
DATA base64_const<>+0x60(SB)/8, $0x1511111111111111 // URL LUT LO
DATA base64_const<>+0x68(SB)/8, $0x1111131B1B1A1B33
DATA base64_const<>+0x70(SB)/8, $0x00001104BFBFE0B9 // URL LUT ROLL
DATA base64_const<>+0x78(SB)/8, $0xB900000000000000
DATA base64_const<>+0x80(SB)/8, $0x010203050607090a // RESHUFFLE MASK
DATA base64_const<>+0x88(SB)/8, $0x0b0d0e0f00000000
GLOBL base64_const<>(SB), (NOPTR+RODATA), $144

#define REV_BYTES V0
#define RESHUFFLE_MASK V1
#define MULHI_CONST V2
#define MULHI_MASK V3
#define MULLO_CONST V4
#define MULLO_MASK V5
#define RANGE1_END V6
#define RANGE0_END V7
#define LUT V8
#define ZERO V9

#define X0 V10
#define X1 V11
#define X2 V12

//func encodeAsm(dst, src []byte, lut *[16]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R1
	MOVD src_base+24(FP), R2
	MOVD src_len+32(FP), R3
	MOVD lut+48(FP), R4
	VL (R4), LUT

	MOVD $base64_const<>(SB), R5
	VLM (R5), REV_BYTES, RESHUFFLE_MASK
	VREPIF 0x0fc0fc00, MULHI_MASK
	VREPIF 0x04000040, MULHI_CONST
	VREPIF 0x003F03F0, MULLO_MASK
	VREPIF 0x01000010, MULLO_CONST
	VREPIB 0x33, RANGE1_END
	VREPIB 0x19, RANGE0_END
	VZERO ZERO

loop:
	VL (R2), X0
	VPERM X0, X0, RESHUFFLE_MASK, X0
	VN X0, MULHI_MASK, X1
	VMLHH(X1, MULHI_CONST, X1)
	VN X0, MULLO_MASK, X2
	VMLHW(X2, MULLO_CONST, X2)
	VO X1, X2, X0

	VSB RANGE1_END, X0, X1
	VMXB ZERO, X1, X1

	VECLB RANGE0_END, X0, X2
	VMXB ZERO, X2, X2
	VAB X2, X1, X1

	VPERM LUT, LUT, X1, X2
	VAB X2, X0, X0

	VPERM X0, X0, REV_BYTES, X0
	VST X0, (R1)

	LAY 12(R1), R1
	LAY 16(R2), R2
	SUB $16, R3
	CMPBGE R3, $48, loop

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
#undef X0
#undef X1
#undef X2
