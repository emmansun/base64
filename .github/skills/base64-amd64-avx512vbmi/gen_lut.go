//go:build ignore

package main

import "fmt"

func le64(b []byte) string {
	var val uint64
	for i, byt := range b {
		val |= uint64(byt) << uint(i*8)
	}
	return fmt.Sprintf("0x%016X", val)
}

func main() {
	// enc512_std_lut
	stdLut := []byte("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
	fmt.Println("// enc512_std_lut")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA enc512_std_lut<>+0x%02X(SB)/8, $%s\n", i, le64(stdLut[i:i+8]))
	}
	fmt.Println()

	// enc512_url_lut
	urlLut := make([]byte, 64)
	copy(urlLut, stdLut)
	urlLut[62] = '-'
	urlLut[63] = '_'
	fmt.Println("// enc512_url_lut")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA enc512_url_lut<>+0x%02X(SB)/8, $%s\n", i, le64(urlLut[i:i+8]))
	}
	fmt.Println()

	// enc512_ms_shift: one 128-bit block for VPMULTISHIFTQB, intended to be
	// loaded with VBROADCASTI32X4 so the selector repeats across all qwords.
	// Each 64-bit lane extracts two triplets' sextets in order using:
	// [18, 12, 6, 0, 42, 36, 30, 24]
	msShiftPattern := []byte{18, 12, 6, 0, 42, 36, 30, 24}
	msShift := make([]byte, 16)
	copy(msShift[0:8], msShiftPattern)
	copy(msShift[8:16], msShiftPattern)
	fmt.Println("// enc512_ms_shift")
	for i := 0; i < 16; i += 8 {
		fmt.Printf("DATA enc512_ms_shift<>+0x%02X(SB)/8, $%s\n", i, le64(msShift[i:i+8]))
	}
	fmt.Println()

	// stddec512_lut_lo: [0..63] -> 0xFF illegal, 6-bit value for legal
	lutLo := make([]byte, 64)
	for i := range lutLo {
		lutLo[i] = 0xFF
	}
	lutLo['+'] = 62
	lutLo['/'] = 63
	for c := '0'; c <= '9'; c++ {
		lutLo[c] = byte(52 + c - '0')
	}
	fmt.Println("// stddec512_lut_lo")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA stddec512_lut_lo<>+0x%02X(SB)/8, $%s\n", i, le64(lutLo[i:i+8]))
	}
	fmt.Println()

	// stddec512_lut_hi: [64..127]
	lutHi := make([]byte, 64)
	for i := range lutHi {
		lutHi[i] = 0xFF
	}
	for c := 'A'; c <= 'Z'; c++ {
		lutHi[c-64] = byte(c - 'A')
	}
	for c := 'a'; c <= 'z'; c++ {
		lutHi[c-64] = byte(26 + c - 'a')
	}
	fmt.Println("// stddec512_lut_hi")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA stddec512_lut_hi<>+0x%02X(SB)/8, $%s\n", i, le64(lutHi[i:i+8]))
	}
	fmt.Println()

	// urldec512_lut_lo
	urlLutLo := make([]byte, 64)
	for i := range urlLutLo {
		urlLutLo[i] = 0xFF
	}
	urlLutLo['-'] = 62
	for c := '0'; c <= '9'; c++ {
		urlLutLo[c] = byte(52 + c - '0')
	}
	fmt.Println("// urldec512_lut_lo")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA urldec512_lut_lo<>+0x%02X(SB)/8, $%s\n", i, le64(urlLutLo[i:i+8]))
	}
	fmt.Println()

	// urldec512_lut_hi
	urlLutHi := make([]byte, 64)
	for i := range urlLutHi {
		urlLutHi[i] = 0xFF
	}
	for c := 'A'; c <= 'Z'; c++ {
		urlLutHi[c-64] = byte(c - 'A')
	}
	for c := 'a'; c <= 'z'; c++ {
		urlLutHi[c-64] = byte(26 + c - 'a')
	}
	urlLutHi['_'-64] = 63
	fmt.Println("// urldec512_lut_hi")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA urldec512_lut_hi<>+0x%02X(SB)/8, $%s\n", i, le64(urlLutHi[i:i+8]))
	}
	fmt.Println()

	// dec512_compress
	// After VPSHUFB with dec_reshuffle_mask, each 16-byte lane has 12 valid decoded
	// bytes at positions [0..11] (contiguous) and zeros at [12..15].
	// Gather 12 bytes from each of the 4 lanes into contiguous positions 0..47.
	compress := make([]byte, 64)
	idx := 0
	for lane := 0; lane < 4; lane++ {
		base := lane * 16
		for off := 0; off < 12; off++ {
			compress[idx] = byte(base + off)
			idx++
		}
	}
	// last 16 bytes: fill with 0
	fmt.Println("// dec512_compress")
	for i := 0; i < 64; i += 8 {
		fmt.Printf("DATA dec512_compress<>+0x%02X(SB)/8, $%s\n", i, le64(compress[i:i+8]))
	}
}
