// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build riscv64 && !purego

#include "textflag.h"

// func encodeAsm(dst, src []byte, lut *[64]byte) int
TEXT ·encodeAsm(SB), NOSPLIT, $0
	// X5: dst pointer, X6: src pointer, X7: remaining src bytes
	// X8: 64-byte alphabet table, X9: encoded output bytes
	MOV	dst_base+0(FP), X5
	MOV	src_base+24(FP), X6
	MOV	src_len+32(FP), X7
	MOV	lut+48(FP), X8
	MOV	$0, X9
	// constant registers: stride=3, mask=63, output stride=4
	MOV	$3, X20
	MOV	$63, X21
	MOV	$4, X24

rvvLoop:
	// If fewer than 3 bytes remain, no full triplet can be encoded in asm.
	BLTU	X7, X20, done

	// triplets = remaining / 3, then request adaptive VL for e8,m1.
	DIVU	X20, X7, X11
	VSETVLI	X11, E8, M1, TA, MA, X10  // X10=actual VL (triplet lanes), not bytes.

	// Load strided triplet bytes: V1=a, V2=b, V3=c.
	VLSE8V	(X6), X20, V1
	ADD	$1, X6, X11
	VLSE8V	(X11), X20, V2
	ADD	$2, X6, X11
	VLSE8V	(X11), X20, V3

	// Build base64 indices (6-bit each).
	// Implementation detail: i1/i2 are formed first, then truncated with a shared
	// mask register X21=63 via VANDVX; i3 is truncated directly from c with VANDVX.
	// i0 comes from a>>2 and is already in [0,63], so no extra mask is needed.
	// Final semantics:
	// i0 = a>>2; i1 = ((a&3)<<4)|(b>>4); i2 = ((b&0xf)<<2)|(c>>6); i3 = c&0x3f.
	VSRLVI	$2, V1, V4

	VSLLVI	$4, V1, V5
	VSRLVI	$4, V2, V6
	VORVV	V6, V5, V5
	VANDVX	X21, V5, V5

	VSLLVI	$2, V2, V6
	VSRLVI	$6, V3, V7
	VORVV	V7, V6, V6
	VANDVX	X21, V6, V6

	VANDVX	X21, V3, V7

	// Vector LUT lookup from 64-byte alphabet and interleaved output stores.
	VLUXEI8V	(X8), V4, V12
	VLUXEI8V	(X8), V5, V13
	VLUXEI8V	(X8), V6, V14
	VLUXEI8V	(X8), V7, V15

	// Store interleaved output.
	VSSE8V	V12, X24, (X5)
	ADD	$1, X5, X11
	VSSE8V	V13, X24, (X11)
	ADD	$2, X5, X11
	VSSE8V	V14, X24, (X11)
	ADD	$3, X5, X11
	VSSE8V	V15, X24, (X11)

	// Advance pointers by processed triplets (3*VL input, 4*VL output).
	SLL	$1, X10, X11
	ADD	X10, X11, X11
	ADD	X11, X6
	SUB	X11, X7

	SLL	$2, X10, X11
	ADD	X11, X5
	ADD	X11, X9
	JMP	rvvLoop

done:
	// Return encoded bytes count.
	MOV	X9, ret+56(FP)
	RET
