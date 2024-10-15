// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (ppc64 || ppc64le) && !purego

#include "textflag.h"

DATA base64_const<>+0x00(SB)/8, $0x0706050403020100 // for PPC64LE byte order
DATA base64_const<>+0x08(SB)/8, $0x0f0e0d0c0b0a0908
DATA base64_const<>+0x10(SB)/8, $0x0d0c0e0d000f0100 // for PPC64LE reshufling
DATA base64_const<>+0x18(SB)/8, $0x0302040306050706
DATA base64_const<>+0x20(SB)/8, $0x0a0b090a07080607 // for PPC64 reshufling
DATA base64_const<>+0x28(SB)/8, $0x0405030401020001
DATA base64_const<>+0x30(SB)/8, $0x0fc0fc000fc0fc00 // mulhi mask
DATA base64_const<>+0x38(SB)/8, $0x0fc0fc000fc0fc00
DATA base64_const<>+0x40(SB)/8, $0x0006000a0006000a // shift right mask
DATA base64_const<>+0x48(SB)/8, $0x0006000a0006000a
DATA base64_const<>+0x50(SB)/8, $0x003F03F0003F03F0 // mullo mask
DATA base64_const<>+0x58(SB)/8, $0x003F03F0003F03F0
DATA base64_const<>+0x60(SB)/8, $0x0008000400080004 // shift left mask
DATA base64_const<>+0x68(SB)/8, $0x0008000400080004
DATA base64_const<>+0x70(SB)/8, $0x3333333333333333 // range 1 end
DATA base64_const<>+0x78(SB)/8, $0x3333333333333333 // range 1 end
DATA base64_const<>+0x80(SB)/8, $0x1919191919191919 // range 0 end
DATA base64_const<>+0x88(SB)/8, $0x1919191919191919 // range 0 end
GLOBL base64_const<>(SB), (NOPTR+RODATA), $144

#define REV_BYTES V0
#define RESHUFFLE_MASK V1
#define SHIFT_RIGHT_MASK V2
#define MULHI_MASK V3
#define SHIFT_LEFT_MASK V4
#define MULLO_MASK V5
#define RANGE1_END V6
#define RANGE0_END V7
#define LUT V8

#define X0 V9
#define X1 V10
#define X2 V11

//func encodeAsm(dst, src []byte, lut *[16]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R4
	MOVD src_base+24(FP), R5
	MOVD src_len+32(FP), R6
	MOVD lut+48(FP), R7
	LXVD2X (R7), LUT

	// Load constants
	MOVD $base64_const<>(SB), R8
	LXVD2X (R8), REV_BYTES
#ifdef GOARCH_ppc64le
	VPERM LUT, LUT, REV_BYTES, LUT	
	MOVD $0x10, R9
#else
	XXPERMDI REV_BYTES, REV_BYTES, $2, REV_BYTES
	MOVD $0x20, R9
#endif
	LXVD2X (R8)(R9), RESHUFFLE_MASK
	MOVD $0x30, R9
	LXVD2X (R8)(R9), MULHI_MASK
	MOVD $0x40, R9
	LXVD2X (R8)(R9), SHIFT_RIGHT_MASK
	MOVD $0x50, R9
	LXVD2X (R8)(R9), MULLO_MASK
	MOVD $0x60, R9
	LXVD2X (R8)(R9), SHIFT_LEFT_MASK
	MOVD $0x70, R9
	LXVD2X (R8)(R9), RANGE1_END
	MOVD $0x80, R9
	LXVD2X (R8)(R9), RANGE0_END

	MOVD $0, R7
	MOVD R7, R8

loop:
		LXVD2X (R5)(R8), X0
		VPERM X0, X0, RESHUFFLE_MASK, X0
		VOR X0, X0, X1
		VAND X1, MULHI_MASK, X1
		VSRH X1, SHIFT_RIGHT_MASK, X1
		VAND X0, MULLO_MASK, X0
		VSLH X0, SHIFT_LEFT_MASK, X0
		VOR X0, X1, X0
		VSUBUBS RANGE1_END, X0, X1
		VCMPGTUB RANGE0_END, X0, X2
		VSUBUBM X2, X1, X1
		VPERM LUT, LUT, X1, X2
		VADDUBM X2, X0, X0

#ifdef GOARCH_ppc64le
		XXPERMDI X0, X0, $2, X0
#else
		VPERM X0, X0, REV_BYTES, X0
#endif
		STXVD2X X0, (R4)(R7)
		ADD $-12, R6
		ADD $16, R7
		ADD $12, R8
		CMP R6, $16
		BGE loop

done:
	MOVD R7, ret+56(FP)
	RET
