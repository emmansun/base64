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
		VAND X0, MULHI_MASK, X1
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
		// PMADDWD: vmsumuhm X0, X0, RESHUFFLE_CONST1, ZERO
		WORD $0x114A3BA6

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
		// PMADDWD: vmsumuhm X0, X0, RESHUFFLE_CONST1, ZERO
		WORD $0x114A3BA6

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

// Power9+ encode: same as encodeAsm but uses STXVB16X on ppc64le (eliminates XXPERMDI).
// Uses concrete V register names to avoid conflicts with decode macro definitions above.
// V0=REV_BYTES V1=RESHUFFLE_MASK V2=SHIFT_RIGHT_MASK V3=MULHI_MASK V4=SHIFT_LEFT_MASK
// V5=MULLO_MASK V6=RANGE1_END V7=RANGE0_END V8=LUT V9=X0 V10=X1 V11=X2
//func encodeP9Asm(dst, src []byte, lut *[16]byte) int
TEXT ·encodeP9Asm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R4
	MOVD src_base+24(FP), R5
	MOVD src_len+32(FP), R6
	MOVD lut+48(FP), R7
	LXVD2X (R7), V8 // LUT

	// Load constants
	MOVD $base64_const<>(SB), R8
	LXVD2X (R8), V0 // REV_BYTES
#ifdef GOARCH_ppc64le
	VPERM V8, V8, V0, V8 // VPERM LUT, LUT, REV_BYTES, LUT
	MOVD $0x10, R9
#else
	XXPERMDI V0, V0, $2, V0 // XXPERMDI REV_BYTES, REV_BYTES, $2, REV_BYTES
	MOVD $0x20, R9
#endif
	LXVD2X (R8)(R9), V1 // RESHUFFLE_MASK
	MOVD $0x30, R9
	LXVD2X (R8)(R9), V3 // MULHI_MASK
	MOVD $0x40, R9
	LXVD2X (R8)(R9), V2 // SHIFT_RIGHT_MASK
	MOVD $0x50, R9
	LXVD2X (R8)(R9), V5 // MULLO_MASK
	MOVD $0x60, R9
	LXVD2X (R8)(R9), V4 // SHIFT_LEFT_MASK
	MOVD $0x70, R9
	LXVD2X (R8)(R9), V6 // RANGE1_END
	MOVD $0x80, R9
	LXVD2X (R8)(R9), V7 // RANGE0_END

	MOVD $0, R7
	MOVD R7, R8

p9encodeloop:
		LXVD2X (R5)(R8), V9 // X0
		VPERM V9, V9, V1, V9     // VPERM X0, X0, RESHUFFLE_MASK, X0
		VAND V9, V3, V10         // VAND X0, MULHI_MASK, X1
		VSRH V10, V2, V10        // VSRH X1, SHIFT_RIGHT_MASK, X1
		VAND V9, V5, V9          // VAND X0, MULLO_MASK, X0
		VSLH V9, V4, V9          // VSLH X0, SHIFT_LEFT_MASK, X0
		VOR V9, V10, V9          // VOR X0, X1, X0
		VSUBUBS V9, V6, V10      // VSUBUBS X0, RANGE1_END, X1
		VCMPGTUB V9, V7, V11     // VCMPGTUB X0, RANGE0_END, X2
		VSUBUBM V10, V11, V10    // VSUBUBM X1, X2, X1
		VPERM V8, V8, V10, V11   // VPERM LUT, LUT, X1, X2
		VADDUBM V11, V9, V9      // VADDUBM X2, X0, X0

#ifdef GOARCH_ppc64le
		XXPERMDI V9, V9, $2, V9  // swap 8-byte halves before STXVD2X (same as encodeAsm)
		STXVD2X V9, (R4)(R7)
#else
		VPERM V9, V9, V0, V9     // VPERM X0, X0, REV_BYTES, X0
		STXVD2X V9, (R4)(R7)
#endif
		ADD $-12, R6
		ADD $16, R7
		ADD $12, R8
		CMP R6, $16
		BGE p9encodeloop

done_p9encode:
	MOVD R7, ret+56(FP)
	RET

// Power9+ standard decode: uses LXVB16X (natural byte-order load) instead of
// LXVD2X + VPERM(REV_BYTES) on ppc64le, and VMSUMUHM for PMADDWD.
//func decodeStdP9Asm(dst, src []byte) int
TEXT ·decodeStdP9Asm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R4
	MOVD src_base+24(FP), R5
	MOVD src_len+32(FP), R6

	// No REV_BYTES loading: LXVB16X gives natural byte order on ppc64le directly.
	// (On ppc64 BE, LXVB16X == LXVD2X; ppc64 BE never needed REV_BYTES here.)
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
p9stdloop:
		// LXVB16X: natural byte-order load on both ppc64le and ppc64 BE.
		// On ppc64le this replaces LXVD2X + VPERM(REV_BYTES).
		// On ppc64 BE, LXVB16X == LXVD2X (no REV_BYTES was needed there either).
		LXVB16X (R5)(R7), X0
		// validate input
		VSRB X0, FOUR, X1 // high nibble
		VAND X0, NIBBLE_MASK, X2
		VPERM LUT_HI, LUT_HI, X1, X3
		VPERM LUT_LO, LUT_LO, X2, X2
		VAND X3, X2, X2
		VCMPEQUBCC X2, ZERO, X3
		BGE CR6, done_p9std

		// translate
		VCMPEQUB X0, DECODE_END, X2
		VADDUBM X1, X2, X1

		VPERM LUT_ROLL, LUT_ROLL, X1, X1
		VADDUBM X0, X1, X0

		// PMADDUBSW
		VMULEUB X0, RESHUFFLE_CONST0, X1
		VMULOUB X0, RESHUFFLE_CONST0, X2
		VADDUHM X1, X2, X0
		// PMADDWD: vmsumuhm X0, X0, RESHUFFLE_CONST1, ZERO
		WORD $0x114A3BA6

		VPERM X0, X0, RESHUFFLE_MASK, X0
		STXVD2X X0, (R4)(R8)

		ADD $-16, R6
		ADD $16, R7
		ADD $12, R8
		CMP R6, $24
		BGE p9stdloop

done_p9std:
	MOVD R6, ret+48(FP)
	RET

// Power9+ URL decode: same as decodeStdP9Asm but for the URL alphabet.
//func decodeUrlP9Asm(dst, src []byte) int
TEXT ·decodeUrlP9Asm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R4
	MOVD src_base+24(FP), R5
	MOVD src_len+32(FP), R6

	// No REV_BYTES loading (same rationale as decodeStdP9Asm).
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
p9urlloop:
		LXVB16X (R5)(R7), X0
		// validate input
		VSRB X0, FOUR, X1 // high nibble
		VAND X0, NIBBLE_MASK, X2
		VPERM LUT_HI, LUT_HI, X1, X3
		VPERM LUT_LO, LUT_LO, X2, X2
		VAND X3, X2, X2
		VCMPEQUBCC X2, ZERO, X3
		BGE CR6, done_p9url

		// translate
		VCMPGTUB X0, DECODE_END, X2
		VSUBUBM X1, X2, X1

		VPERM LUT_ROLL, LUT_ROLL, X1, X1
		VADDUBM X0, X1, X0

		// PMADDUBSW
		VMULEUB X0, RESHUFFLE_CONST0, X1
		VMULOUB X0, RESHUFFLE_CONST0, X2
		VADDUHM X1, X2, X0
		// PMADDWD: vmsumuhm X0, X0, RESHUFFLE_CONST1, ZERO
		WORD $0x114A3BA6

		VPERM X0, X0, RESHUFFLE_MASK, X0
		STXVD2X X0, (R4)(R8)

		ADD $-16, R6
		ADD $16, R7
		ADD $12, R8
		CMP R6, $24
		BGE p9urlloop

done_p9url:
	MOVD R6, ret+48(FP)
	RET
