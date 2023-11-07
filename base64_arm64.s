// Reference
// https://github.com/aklomp/base64/blob/master/lib/arch/neon64/enc_loop.c
//go:build arm64 && !purego

#include "textflag.h"

//func encodeAsm(dst, src []byte, lut *[64]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R0
	MOVD src_base+24(FP), R1
	MOVD src_len+32(FP), R2
	MOVD lut+48(FP), R3

	VLD1 (R3), [V8.B16, V9.B16, V10.B16, V11.B16]
	MOVD $0x3F, R4
	VDUP R4, V7.B16
	EOR R5, R5, R5

loop:
	CMP $48, R2
	BLT done

	// Move the input bits to where they need to be in the outputs. Except
	// for the first output, the high two bits are not cleared.
	VLD3.P 48(R1), [V0.B16, V1.B16, V2.B16]
	VUSHR $2, V0.B16, V3.B16
	VUSHR $4, V1.B16, V4.B16
	VUSHR $6, V2.B16, V5.B16
	VSLI $4, V0.B16, V4.B16
	VSLI $2, V1.B16, V5.B16

	// Clear the high two bits in the second, third and fourth output.
	VAND V7.B16, V4.B16, V4.B16
	VAND V7.B16, V5.B16, V5.B16
	VAND V7.B16, V2.B16, V6.B16

	// The bits have now been shifted to the right locations;
	// translate their values 0..63 to the Base64 alphabet.
	// Use a 64-byte table lookup:
	VTBL V3.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V3.B16
	VTBL V4.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V4.B16
	VTBL V5.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V5.B16
	VTBL V6.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V6.B16

	// Interleave and store output:
	VST4.P [V3.B16, V4.B16, V5.B16, V6.B16], 64(R0)

	SUB $48, R2
	ADD $64, R5
	B loop

done:
	MOVD R5, ret+56(FP)
	RET

//func decodeAsm(dst, src []byte, lut *[128]byte) int
TEXT ·decodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R0
	MOVD src_base+24(FP), R1
	MOVD src_len+32(FP), R2
	MOVD lut+48(FP), R3

	VLD1.P 64(R3), [V8.B16, V9.B16, V10.B16, V11.B16]
	VLD1 (R3), [V12.B16, V13.B16, V14.B16, V15.B16]
	MOVD $63, R4
	VDUP R4, V7.B16

loop:
	CMP $64, R2
	BLT done

	VLD4.P 64(R1), [V0.B16, V1.B16, V2.B16, V3.B16]
	
	// Get indices for second LUT:
	WORD $0x6e272c10 // VUQSUB V7.B16, V0.B16, V16.B16
	WORD $0x6e272c31 // VUQSUB V7.B16, V1.B16, V17.B16
	WORD $0x6e272c52 // VUQSUB V7.B16, V2.B16, V18.B16
	WORD $0x6e272c73 // VUQSUB V7.B16, V3.B16, V19.B16

	// Get values from first LUT:
	VTBL V0.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V20.B16
	VTBL V1.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V21.B16
	VTBL V2.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V22.B16
	VTBL V3.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V23.B16

	// Get values from second LUT:
	WORD $0x4e107190 // VTBX V16.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V16.B16
	WORD $0x4e117191 // VTBX V17.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V17.B16
	WORD $0x4e127192 // VTBX V18.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V18.B16
	WORD $0x4e137193 // VTBX V19.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V19.B16

	// Get final values:
	VORR V16.B16, V20.B16, V0.B16
	VORR V17.B16, V21.B16, V1.B16
	VORR V18.B16, V22.B16, V2.B16
	VORR V19.B16, V23.B16, V3.B16

	// Check for invalid input, any value larger than 63:
	WORD $0x6e273410 // VCMHI V7.B16, V0.B16, V16.B16
	WORD $0x6e273431 // VCMHI V7.B16, V1.B16, V17.B16
	WORD $0x6e273452 // VCMHI V7.B16, V2.B16, V18.B16
	WORD $0x6e273473 // VCMHI V7.B16, V3.B16, V19.B16

	VORR V17.B16, V16.B16, V16.B16
	VORR V18.B16, V16.B16, V16.B16
	VORR V19.B16, V16.B16, V16.B16

	// Check that all bits are zero:
	WORD $0x6e30aa11 // VUMAXV V16.B16, V17
	VMOV V17.B[0], R5
	CBNZ R5, done

	// Compress four bytes into three:
	VSHL $2, V0.B16, V4.B16
	VUSHR $4, V1.B16, V16.B16
	VORR  V16.B16, V4.B16, V4.B16

	VSHL $4, V1.B16, V5.B16
	VUSHR $2, V2.B16, V16.B16
	VORR  V16.B16, V5.B16, V5.B16
	
	VSHL $6, V2.B16, V16.B16
	VORR  V16.B16, V3.B16, V6.B16

	// Interleave and store decoded result:
	VST3.P [V4.B16, V5.B16, V6.B16], 48(R0)

	SUB $64, R2
	B loop

done:
	MOVD R2, ret+56(FP)
	RET

// func moveCond(res, a, b *byte, cond int)
// If cond == 0 res=b, else res=a
TEXT ·moveCond(SB),NOSPLIT,$0
	MOVD	res+0(FP), R0
	MOVD	a+8(FP), R1
	MOVD	b+16(FP), R2
	MOVD	cond+24(FP), R3

	VEOR V0.B16, V0.B16, V0.B16
	VMOV R3, V1.S4
	VCMEQ V0.S4, V1.S4, V2.S4
/*
	VLD1 (R1), [V3.B16]
	VLD1 (R2), [V4.B16]

	VBSL V4.B16, V3.B16, V2.B16
*/
	VST1 [V2.B16], (R0)
	RET
