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

	VSB X0, RANGE0_END, X2
	VMXB NEG, X2, X2
	VMNB ZERO, X2, X2
	//VMXB ZERO, X2, X2
	//VAB X2, X1, X1

	//VPERM LUT, LUT, X1, X2
	//VAB X2, X0, X0

	//VPERM X0, X0, REV_BYTES, X0
	VST X2, 0(R1)(R4*1)

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
#undef X0
#undef X1
#undef X2
