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
// LASX loop reshuffle mask for 24-byte input (32 bytes total, same layout as AVX2 reshuffle_mask32):
// Q1 lane: bytes [12..23] → 0x0809070805060405 / 0x0e0f0d0e0b0c0a0b
// Q0 lane: bytes [0..11]  → 0x0405030401020001 / 0x0a0b090a07080607
DATA base64_const<>+0x70(SB)/8, $0x0809070805060405
DATA base64_const<>+0x78(SB)/8, $0x0e0f0d0e0b0c0a0b
DATA base64_const<>+0x80(SB)/8, $0x0405030401020001
DATA base64_const<>+0x88(SB)/8, $0x0a0b090a07080607
GLOBL base64_const<>(SB), (NOPTR+RODATA), $144

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

	MOVBU ·useLASX(SB), R10
	BEQ  R10, R0, lsx_path
	MOVV $28, R10
	BGEU R7, R10, lasx
lsx_path:

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

// LASX path: processes 24 bytes per iteration (32 bytes output)
lasx:
	// Load constants into LSX registers then broadcast to LASX high lane
	// Register layout matches LSX: V1=SHIFT_RIGHT_MASK, V2=MULHI_MASK, V3=SHIFT_LEFT_MASK, V4=MULLO_MASK
	VMOVQ (0*16)(R9), V0           // V0 = reshuffle mask (head: 12-byte layout)
	XVMOVQ X0, X0.Q2              // broadcast Q0→high lane (xvreplve0.q)
	VMOVQ (2*16)(R9), V1           // V1 = SHIFT_RIGHT_MASK (0x0006000a...)
	XVMOVQ X1, X1.Q2
	VMOVQ (1*16)(R9), V2           // V2 = MULHI_MASK (0x0FC0FC00...)
	XVMOVQ X2, X2.Q2
	VMOVQ (4*16)(R9), V3           // V3 = SHIFT_LEFT_MASK (0x0008000...)
	XVMOVQ X3, X3.Q2
	VMOVQ (3*16)(R9), V4           // V4 = MULLO_MASK (0x003F03F0...)
	XVMOVQ X4, X4.Q2
	VMOVQ (5*16)(R9), V5           // V5 = RANGE1_END
	XVMOVQ X5, X5.Q2
	VMOVQ (6*16)(R9), V6           // V6 = RANGE0_END
	XVMOVQ X6, X6.Q2
	VMOVQ (R8), V7                 // V7 = LUT
	XVMOVQ X7, X7.Q2
	// Load loop reshuffle mask (32-byte layout, at offset 7*16)
	XVMOVQ (7*16)(R9), X13

	MOVV $28, R10
	MOVV R5, R11                   // save dst pointer

lasx_head:
	BLTU R7, R10, lasx_tail
	// Load first 28 bytes: two 16-byte loads, overlap at byte 12
	VMOVQ (R6), V8                 // bytes [0..15]
	VMOVQ 12(R6), V9               // bytes [12..27]
	WORD $0x77ec8128               // xvpermi.q X8, X9, 0x20: X8.Q0=keep, X8.Q1=X9.Q0 → X8={ [12..27] | [0..15] }
	WORD $0x0d602108               // XVSHUFB X0, X8, X8, X8  // reshuffle (head layout)
	XVANDV X2, X8, X9
	XVSRLH X1, X9, X9
	XVANDV X4, X8, X8
	XVSLLH X3, X8, X8
	XVORV X9, X8, X8
	WORD $0x744c1509               // XVSSUBBU X5, X8, X9
	WORD $0x740820ca               // XVSLTBU X8, X6, X10
	XVSUBB X10, X9, X9
	WORD $0x0d649ce9               // XVSHUFB X9, X7, X7, X9
	XVADDB X9, X8, X8
	XVMOVQ X8, (R5)                // store full 256-bit (32 bytes)

	ADDV $28, R6
	SUBV $28, R7
	ADDV $32, R5

lasx_loop:
	BLTU R7, R10, lasx_tail
	// Load 28 bytes borrowing 4 bytes before current pointer
	XVMOVQ -4(R6), X8             // bytes [-4..27], 32 bytes total
	WORD $0x0d66a108               // XVSHUFB X13, X8, X8, X8  // reshuffle (loop layout)
	XVANDV X2, X8, X9
	XVSRLH X1, X9, X9
	XVANDV X4, X8, X8
	XVSLLH X3, X8, X8
	XVORV X9, X8, X8
	WORD $0x744c1509               // XVSSUBBU X5, X8, X9
	WORD $0x740820ca               // XVSLTBU X8, X6, X10
	XVSUBB X10, X9, X9
	WORD $0x0d649ce9               // XVSHUFB X9, X7, X7, X9
	XVADDB X9, X8, X8
	XVMOVQ X8, (R5)                // store full 256-bit (32 bytes)

	ADDV $24, R6
	SUBV $24, R7
	ADDV $32, R5
	JMP lasx_loop

lasx_tail:
	// Fall back to LSX for remaining bytes (< 28 bytes left)
	MOVV $16, R10
	BGEU R7, R10, loop
	JMP done

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

	MOVBU ·useLASX(SB), R10
	BNE R10, R0, stddec_lasx

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

// LASX path: processes 32 bytes input → 24 bytes output per iteration
stddec_lasx:
	// Load constants into LSX registers then broadcast to LASX high lane
	VMOVQ (0*16)(R8), V1           // LUT_HI
	XVMOVQ X1, X1.Q2
	VMOVQ (1*16)(R8), V2           // LUT_LO
	XVMOVQ X2, X2.Q2
	VMOVQ (2*16)(R8), V3           // DECODE_END
	XVMOVQ X3, X3.Q2
	VMOVQ (3*16)(R8), V4           // LUT_ROLL
	XVMOVQ X4, X4.Q2
	VMOVQ (8*16)(R8), V5           // RESHUFFLE_CONST0
	XVMOVQ X5, X5.Q2
	VMOVQ (9*16)(R8), V6           // RESHUFFLE_CONST1
	XVMOVQ X6, X6.Q2
	VMOVQ (10*16)(R8), V7          // RESHUFFLE_MASK
	XVMOVQ X7, X7.Q2
	MOVV $40, R10
stddec_lasx_loop:
	BLTU R7, R10, stddec_lasx_tail
		XVMOVQ (R6), X8                // load 32 bytes input
		// validate the input data
		XVSRLB $4, X8, X9              // high nibble
		XVANDB $0xf, X8, X10           // low nibble
		WORD $0x0d64842b               // XVSHUFB X9, X1, X1, X11  (hi nibble lookup)
		WORD $0x0d65084a               // XVSHUFB X10, X2, X2, X10 (lo nibble lookup)
		XVANDV X11, X10, X10
		XVSETEQV X10, FCC0
		BFPF stddec_lasx_done

		// translate
		XVSEQB X8, X3, X10            // compare DECODE_END(0x2F) with input bytes
		XVADDB X9, X10, X10           // add eq_2F with hi_nibbles
		WORD $0x0d65108a               // XVSHUFB X10, X4, X4, X10 (lut roll lookup)
		XVADDB X10, X8, X8            // add delta values to input

		// reshuffle output bytes
		XVMULWEVHBU X8, X5, X9
		WORD $0x74b620a9               // xvmaddwod.h.bu X8, X5, X9

		XVMULWEVWHU X9, X6, X8
		WORD $0x74b6a4c8               // xvmaddwod.w.hu X9, X6, X8

		WORD $0x0d63a108               // XVSHUFB X7, X8, X8, X8  (output reshuffle)
		VMOVQ V8, (R5)                 // store Q0: bytes [0..11] valid, [12..15]=0
		WORD $0x77ec0d09               // xvpermi.q X9, X8, 0x03: X9.Q0 = X8.Q1
		VMOVQ V9, 12(R5)              // store at +12: bytes [12..23] valid, [24..27]=0

		ADDV $24, R5
		SUBV $32, R7
		ADDV $32, R6
		JMP stddec_lasx_loop

stddec_lasx_tail:
	// Fall back to LSX path for remaining bytes
	MOVV $24, R10
	BGEU R7, R10, loop
stddec_lasx_done:
	MOVV R7, ret+48(FP)
	RET

//func decodeUrlAsmdst, src []byte) int
TEXT ·decodeUrlAsm(SB),NOSPLIT,$0
	MOVV dst_base+0(FP), R5
	MOVV src_base+24(FP), R6
	MOVV src_len+32(FP), R7

	MOVV $decode_const<>(SB), R8

	MOVBU ·useLASX(SB), R10
	BNE R10, R0, urldec_lasx

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

// LASX path: processes 32 bytes input → 24 bytes output per iteration
urldec_lasx:
	// Load constants into LSX registers then broadcast to LASX high lane
	VMOVQ (4*16)(R8), V1           // LUT_HI
	XVMOVQ X1, X1.Q2
	VMOVQ (5*16)(R8), V2           // LUT_LO
	XVMOVQ X2, X2.Q2
	VMOVQ (6*16)(R8), V3           // DECODE_END
	XVMOVQ X3, X3.Q2
	VMOVQ (7*16)(R8), V4           // LUT_ROLL
	XVMOVQ X4, X4.Q2
	VMOVQ (8*16)(R8), V5           // RESHUFFLE_CONST0
	XVMOVQ X5, X5.Q2
	VMOVQ (9*16)(R8), V6           // RESHUFFLE_CONST1
	XVMOVQ X6, X6.Q2
	VMOVQ (10*16)(R8), V7          // RESHUFFLE_MASK
	XVMOVQ X7, X7.Q2
	MOVV $40, R10
urldec_lasx_loop:
	BLTU R7, R10, urldec_lasx_tail
		XVMOVQ (R6), X8                // load 32 bytes input
		// validate the input data
		XVSRLB $4, X8, X9              // high nibble
		XVANDB $0xf, X8, X10           // low nibble
		WORD $0x0d64842b               // XVSHUFB X9, X1, X1, X11  (hi nibble lookup)
		WORD $0x0d65084a               // XVSHUFB X10, X2, X2, X10 (lo nibble lookup)
		XVANDV X11, X10, X10
		XVSETEQV X10, FCC0
		BFPF urldec_lasx_done

		// translate
		WORD $0x7408206a               // XVSLTBU X8, X3, X10 (compare 0x5E with input)
		XVSUBB X10, X9, X10            // sub gt_5E with hi_nibbles
		WORD $0x0d65108a               // XVSHUFB X10, X4, X4, X10 (lut roll lookup)
		XVADDB X10, X8, X8            // add delta values to input

		// reshuffle output bytes
		XVMULWEVHBU X8, X5, X9
		WORD $0x74b620a9               // xvmaddwod.h.bu X8, X5, X9

		XVMULWEVWHU X9, X6, X8
		WORD $0x74b6a4c8               // xvmaddwod.w.hu X9, X6, X8

		WORD $0x0d63a108               // XVSHUFB X7, X8, X8, X8  (output reshuffle)
		VMOVQ V8, (R5)                 // store Q0: bytes [0..11] valid, [12..15]=0
		WORD $0x77ec0d09               // xvpermi.q X9, X8, 0x03: X9.Q0 = X8.Q1
		VMOVQ V9, 12(R5)              // store at +12: bytes [12..23] valid, [24..27]=0

		ADDV $24, R5
		SUBV $32, R7
		ADDV $32, R6
		JMP urldec_lasx_loop

urldec_lasx_tail:
	// Fall back to LSX path for remaining bytes
	MOVV $24, R10
	BGEU R7, R10, loop
urldec_lasx_done:
	MOVV R7, ret+48(FP)
	RET
