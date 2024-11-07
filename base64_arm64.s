// Reference
// https://github.com/aklomp/base64/blob/master/lib/arch/neon64/enc_loop.c
// https://github.com/aklomp/base64/blob/master/lib/arch/neon64/dec_loop.c
//go:build arm64 && !purego

#include "textflag.h"

DATA enc_const<>+0x00(SB)/8, $0x0405030401020001 // reshufle mask
DATA enc_const<>+0x08(SB)/8, $0x0a0b090a07080607
DATA enc_const<>+0x10(SB)/8, $0x0FC0FC000FC0FC00 // mulhi mask
DATA enc_const<>+0x18(SB)/8, $0x0FC0FC000FC0FC00
DATA enc_const<>+0x20(SB)/8, $0x003F03F0003F03F0 // mullo mask
DATA enc_const<>+0x28(SB)/8, $0x003F03F0003F03F0
DATA enc_const<>+0x30(SB)/8, $0x1f1e1b1a17161312 // high part of word
DATA enc_const<>+0x38(SB)/8, $0x0f0e0b0a07060302
GLOBL enc_const<>(SB), (NOPTR+RODATA), $64

DATA dec_const<>+0x00(SB)/8, $0x0140014001400140 // dec_reshuffle_const0
DATA dec_const<>+0x08(SB)/8, $0x0140014001400140
DATA dec_const<>+0x10(SB)/8, $0x0001100000011000 // dec_reshuffle_const1
DATA dec_const<>+0x18(SB)/8, $0x0001100000011000
DATA dec_const<>+0x20(SB)/8, $0x090A040506000102 // dec_reshuffle_mask
DATA dec_const<>+0x28(SB)/8, $0xFFFFFFFF0C0D0E08
GLOBL dec_const<>(SB), (NOPTR+RODATA), $48

//func encodeAsm(dst, src []byte, lut *[64]byte) int
TEXT ·encodeAsm(SB),NOSPLIT,$0
	MOVD dst_base+0(FP), R0
	MOVD src_base+24(FP), R1
	MOVD src_len+32(FP), R2
	MOVD lut+48(FP), R3

	// load the Base64 alphabet into registers
	VLD1 (R3), [V8.B16, V9.B16, V10.B16, V11.B16]
	MOVD $0x3F, R4
	VDUP R4, V7.B16
	EOR R5, R5, R5

loop48:
		CMP $48, R2
		BLT lessThan48

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
		B loop48

lessThan48:
	// fast return
	CMP $16, R2
	BLT done

	MOVD $enc_const<>(SB), R4
	VLD1 (R4), [V3.B16, V4.B16, V5.B16, V6.B16]
	MOVD $0x01000010, R4
	VDUP R4, V7.S4        // mullo constant
	VSHL $2, V7.S4, V12.S4 // mulhi constant

loop12:
		VLD1 (R1), [V0.B16]
		VTBL V3.B16, [V0.B16], V0.B16 // shuffle bytes
		VAND V4.B16, V0.B16, V1.B16   // AND mulhi mask

		WORD $0x2e61c182 // UMULL V1.H8, V12.H8, V2.H8
		WORD $0x6e61c181 // UMULL2 V1.H8, V12.H8, V1.H8
		VTBL V6.B16, [V1.B16, V2.B16], V1.B16

		VAND V0.B16, V5.B16, V0.B16
		WORD $0x4e609ce0 // VMUL V0.H8, V7.H8, V0.H8
		VORR V0.B16, V1.B16, V0.B16

		// The bits have now been shifted to the right locations;
		// translate their values 0..63 to the Base64 alphabet.
		// Use a 64-byte table lookup:
		VTBL V0.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V0.B16
		VST1.P [V0.B16], 16(R0)

		ADD $12, R1
		ADD $16, R5
		SUB $12, R2
		CMP $16, R2
		BGE loop12

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
	MOVD $0x40, R4
	VDUP R4, V7.B16

loop64:
		CMP $64, R2
		BLT lessThan64

		VLD4.P 64(R1), [V20.B16, V21.B16, V22.B16, V23.B16]
	
		// Get values from first LUT
		VTBL V20.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V0.B16
		VTBL V21.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V1.B16
		VTBL V22.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V2.B16
		VTBL V23.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V3.B16

		// Get values from second LUT
		VSUB V7.B16, V20.B16, V20.B16
		WORD $0x4e147180 // VTBX V20.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V0.B16
		VSUB V7.B16, V21.B16, V21.B16
		WORD $0x4e157181 // VTBX V21.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V1.B16
		VSUB V7.B16, V22.B16, V22.B16
		WORD $0x4e167182 // VTBX V22.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V2.B16
		VSUB V7.B16, V23.B16, V23.B16
		WORD $0x4e177183 // VTBX V23.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V3.B16

		// Check for invalid input, any value larger than 63
		WORD $0x6e273c10 // VCMHS V7.B16, V0.B16, V16.B16
		WORD $0x6e273c31 // VCMHS V7.B16, V1.B16, V17.B16
		WORD $0x6e273c52 // VCMHS V7.B16, V2.B16, V18.B16
		WORD $0x6e273c73 // VCMHS V7.B16, V3.B16, V19.B16

		VORR V17.B16, V16.B16, V16.B16
		VORR V18.B16, V16.B16, V16.B16
		VORR V19.B16, V16.B16, V16.B16

		// Check that all bits are zero:
		WORD $0x6e30aa11 // VUMAXV V16.B16, V17
		VMOV V17.B[0], R5
		CBNZ R5, done

		// Compress four bytes into three
		VSHL $2, V0.B16, V4.B16
		VUSHR $4, V1.B16, V16.B16
		VORR  V16.B16, V4.B16, V4.B16

		VSHL $4, V1.B16, V5.B16
		VUSHR $2, V2.B16, V16.B16
		VORR  V16.B16, V5.B16, V5.B16
	
		VSHL $6, V2.B16, V16.B16
		VORR  V16.B16, V3.B16, V6.B16

		// Interleave and store decoded result
		VST3.P [V4.B16, V5.B16, V6.B16], 48(R0)

		SUB $64, R2
		B loop64

lessThan64:
	// fast return
	CMP $24, R2
	BLT done

	MOVD $dec_const<>(SB), R4
	VLD1 (R4), [V1.B16, V2.B16, V3.B16]

loop16:
		VLD1.P 16(R1), [V20.B16]

		// Get values from first LUT
		VTBL V20.B16, [V8.B16, V9.B16, V10.B16, V11.B16], V0.B16
		VSUB V7.B16, V20.B16, V20.B16
		// Get values from second LUT
		WORD $0x4e147180 // VTBX V20.B16, [V12.B16, V13.B16, V14.B16, V15.B16], V0.B16

		// Check for invalid input, any value larger than 63
		WORD $0x6e273c10 // VCMHS V7.B16, V0.B16, V16.B16
		// Check that all bits are zero:
		WORD $0x6e30aa11 // VUMAXV V16.B16, V17
		VMOV V17.B[0], R5
		CBNZ R5, done
	
		// Compress four bytes into three
		// swap and merge adjacent 6-bit fields
		WORD $0x2e20c024 // UMULL V0.B16, V1.B16, V4.H8
		WORD $0x6e20c020 // UMULL2 V0.B16, V1.B16, V0.H8
		VADDP V0.H8, V4.H8, V0.H8

		// swap and merge 12-bit words into a 24-bit word
		WORD $0x2e60c044 // UMULL V0.H8, V2.H8, V4.S4
		WORD $0x6e60c040 // UMULL2 V0.H8, V2.H8, V0.S4
		VADDP V0.S4, V4.S4, V0.S4

		// reshuffle bytes
		VTBL V3.B16, [V0.B16], V0.B16
		VST1 [V0.B16], (R0)

		ADD $12, R0
		SUB $16, R2
		CMP $24, R2
		BGE loop16

done:
	MOVD R2, ret+56(FP)
	RET
