// Copyright 2025 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build !purego

#include "textflag.h"

#define ZERO R0
#define RSP R3
#define res_ptr R4


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

		WORD $0x704c1509              // VSSUBBU RANGE1_END, V8, V9
		WORD $0x700420ca              // VSLEBU V8, RANGE0_END, V10
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

//func decodeStdAsm(dst, src []byte) int
TEXT ·decodeStdAsm(SB),NOSPLIT,$0
	RET

//func decodeUrlAsmdst, src []byte) int
TEXT ·decodeUrlAsm(SB),NOSPLIT,$0
	RET

