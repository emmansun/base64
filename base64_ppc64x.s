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

DATA decode_const<>+0x00(SB)/8, $0x1010010204080408 // standard decode lut hi
DATA decode_const<>+0x08(SB)/8, $0x1010101010101010
DATA decode_const<>+0x10(SB)/8, $0x1511111111111111 // standard decode lut lo
DATA decode_const<>+0x18(SB)/8, $0x1111131A1B1B1B1A
DATA decode_const<>+0x20(SB)/8, $0x2F2F2F2F2F2F2F2F // standard decode mask
DATA decode_const<>+0x28(SB)/8, $0x2F2F2F2F2F2F2F2F
DATA decode_const<>+0x30(SB)/8, $0x00101304BFBFB9B9 // standard decode lut roll
DATA decode_const<>+0x38(SB)/8, $0x0000000000000000
DATA decode_const<>+0x40(SB)/8, $0x1010010204080428 // url decode lut hi
DATA decode_const<>+0x48(SB)/8, $0x1010101010101010
DATA decode_const<>+0x50(SB)/8, $0x1511111111111111 // url decode lut lo
DATA decode_const<>+0x58(SB)/8, $0x1111131B1B1A1B33
DATA decode_const<>+0x60(SB)/8, $0x5E5E5E5E5E5E5E5E // url decode mask
DATA decode_const<>+0x68(SB)/8, $0x5E5E5E5E5E5E5E5E
DATA decode_const<>+0x70(SB)/8, $0x00001104BFBFE0B9 // url decode lut roll
DATA decode_const<>+0x78(SB)/8, $0xB900000000000000
DATA decode_const<>+0x80(SB)/8, $0x4001400140014001 // decode reshufling constant 0
DATA decode_const<>+0x88(SB)/8, $0x4001400140014001
DATA decode_const<>+0x90(SB)/8, $0x1000000110000001 // decode reshufling constant 1
DATA decode_const<>+0x98(SB)/8, $0x1000000110000001
DATA decode_const<>+0xA0(SB)/8, $0x0A09070605030201 // decode reshufling mask for ppc64le
DATA decode_const<>+0xA8(SB)/8, $0x000000000F0E0D0B
DATA decode_const<>+0xB0(SB)/8, $0x010203050607090A // decode reshufling mask for ppc64
DATA decode_const<>+0xB8(SB)/8, $0x0B0D0E0F00000000
GLOBL decode_const<>(SB), (NOPTR+RODATA), $192

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
		VSUBUBS X0, RANGE1_END, X1
		VCMPGTUB X0, RANGE0_END, X2
		VSUBUBM X1, X2, X1
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

#undef RESHUFFLE_MASK
#undef SHIFT_RIGHT_MASK
#undef MULHI_MASK
#undef SHIFT_LEFT_MASK
#undef MULLO_MASK
#undef RANGE1_END
#undef RANGE0_END
#undef LUT
#undef X0
#undef X1
#undef X2

#define NIBBLE_MASK V1
#define LUT_HI V2
#define LUT_LO V3
#define DECODE_END V4
#define LUT_ROLL V5
#define RESHUFFLE_CONST0 V6
#define RESHUFFLE_CONST1 V7
#define RESHUFFLE_MASK V8
#define FOUR V9

#define X0 V10
#define X1 V11
#define X2 V12
#define X3 V13
#define ZERO V14

//func decodeStdAsm(dst, src []byte) int
TEXT ·decodeStdAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R4
	MOVD src_base+24(FP), R5
	MOVD src_len+32(FP), R6

	// Load constants
#ifdef GOARCH_ppc64le	
	MOVD $base64_const<>(SB), R8
	LXVD2X (R8), REV_BYTES
#endif
	VSPLTISB $0, ZERO
	VSPLTISB $0x4, FOUR
	VSPLTISB $0x0F, NIBBLE_MASK
	MOVD $decode_const<>(SB), R8
	LXVD2X (R8), LUT_HI
	MOVD $0x10, R9
	LXVD2X (R8)(R9), LUT_LO
	MOVD $0x20, R9
	LXVD2X (R8)(R9), DECODE_END
	MOVD $0x30, R9
	LXVD2X (R8)(R9), LUT_ROLL
	MOVD $0x80, R9
	LXVD2X (R8)(R9), RESHUFFLE_CONST0
	MOVD $0x90, R9
	LXVD2X (R8)(R9), RESHUFFLE_CONST1
#ifdef GOARCH_ppc64le
	MOVD $0xA0, R9
#else
	MOVD $0xB0, R9
#endif		
	LXVD2X (R8)(R9), RESHUFFLE_MASK	

	MOVD $0, R7
	MOVD R7, R8
loop:
		// load data
		LXVD2X (R5)(R7), X0
#ifdef GOARCH_ppc64le
		VPERM X0, X0, REV_BYTES, X0
#endif
		// validate input
		VSRB X0, FOUR, X1 // high nibble
		VAND X0, NIBBLE_MASK, X2
		VPERM LUT_HI, LUT_HI, X1, X3
		VPERM LUT_LO, LUT_LO, X2, X2
		VAND X3, X2, X2
		VCMPEQUBCC X2, ZERO, X3
		BGE CR6, done

		// translate
		VCMPEQUB X0, DECODE_END, X2
		VADDUBM X1, X2, X1

		VPERM LUT_ROLL, LUT_ROLL, X1, X1
		VADDUBM X0, X1, X0

		// PMADDUBSW
		VMULEUB X0, RESHUFFLE_CONST0, X1
		VMULOUB X0, RESHUFFLE_CONST0, X2
		VADDUHM X1, X2, X0
		// PMADDWD
		VMULEUH X0, RESHUFFLE_CONST1, X1
		VMULOUH X0, RESHUFFLE_CONST1, X2
		VADDUWM X1, X2, X0

		VPERM X0, X0, RESHUFFLE_MASK, X0
		STXVD2X X0, (R4)(R8)

		ADD $-16, R6
		ADD $16, R7
		ADD $12, R8
		CMP R6, $24
		BGE loop

done:
	MOVD R6, ret+48(FP)
	RET

//func decodeUrlAsm(dst, src []byte) int
TEXT ·decodeUrlAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R4
	MOVD src_base+24(FP), R5
	MOVD src_len+32(FP), R6

	// Load constants
#ifdef GOARCH_ppc64le	
	MOVD $base64_const<>(SB), R8
	LXVD2X (R8), REV_BYTES
#endif
	VSPLTISB $0, ZERO
	VSPLTISB $0x4, FOUR
	VSPLTISB $0x0F, NIBBLE_MASK
	MOVD $decode_const<>(SB), R8
	MOVD $0x40, R9
	LXVD2X (R8)(R9), LUT_HI
	MOVD $0x50, R9
	LXVD2X (R8)(R9), LUT_LO
	MOVD $0x60, R9
	LXVD2X (R8)(R9), DECODE_END
	MOVD $0x70, R9
	LXVD2X (R8)(R9), LUT_ROLL
	MOVD $0x80, R9
	LXVD2X (R8)(R9), RESHUFFLE_CONST0
	MOVD $0x90, R9
	LXVD2X (R8)(R9), RESHUFFLE_CONST1
#ifdef GOARCH_ppc64le
	MOVD $0xA0, R9
#else
	MOVD $0xB0, R9
#endif		
	LXVD2X (R8)(R9), RESHUFFLE_MASK	

	MOVD $0, R7
	MOVD R7, R8
loop:
		// load data
		LXVD2X (R5)(R7), X0
#ifdef GOARCH_ppc64le
		VPERM X0, X0, REV_BYTES, X0
#endif
		// validate input
		VSRB X0, FOUR, X1 // high nibble 
		VAND X0, NIBBLE_MASK, X2
		VPERM LUT_HI, LUT_HI, X1, X3
		VPERM LUT_LO, LUT_LO, X2, X2
		VAND X3, X2, X2
		VCMPEQUBCC X2, ZERO, X3
		BGE CR6, done

		// translate
		VCMPGTUB X0, DECODE_END, X2
		VSUBUBM X1, X2, X1

		VPERM LUT_ROLL, LUT_ROLL, X1, X1
		VADDUBM X0, X1, X0

		// PMADDUBSW
		VMULEUB X0, RESHUFFLE_CONST0, X1
		VMULOUB X0, RESHUFFLE_CONST0, X2
		VADDUHM X1, X2, X0
		// PMADDWD 
		VMULEUH X0, RESHUFFLE_CONST1, X1
		VMULOUH X0, RESHUFFLE_CONST1, X2
		VADDUWM X1, X2, X0

		VPERM X0, X0, RESHUFFLE_MASK, X0
		STXVD2X X0, (R4)(R8)

		ADD $-16, R6
		ADD $16, R7
		ADD $12, R8
		CMP R6, $24
		BGE loop

done:
	MOVD R6, ret+48(FP)
	RET
