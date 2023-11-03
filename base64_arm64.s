// Reference
// https://github.com/aklomp/base64/blob/master/lib/arch/neon64/enc_loop.c
//go:build arm64 && !purego
// +build arm64,!purego

//func encodeAsm(dst, src []byte, lut *[64]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R0
	MOVD src_base+24(FP), R1
	MOVD src_len+32(FP), R2
	MOVD lut+48(FP), R3

	VLD1 (R3), [V8.B16, V9.B16, V10.B16, V11.B16]
	MOVB $0x3F, R4
	VDUP R3, V7.B16
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