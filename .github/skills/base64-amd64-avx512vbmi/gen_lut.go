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

func emitBlock(name string, data []byte) {
	if len(data)%8 != 0 {
		panic(fmt.Sprintf("%s: data length %d is not a multiple of 8", name, len(data)))
	}
	fmt.Printf("// %s\n", name)
	for i := 0; i < len(data); i += 8 {
		fmt.Printf("DATA %s<>+0x%02X(SB)/8, $%s\n", name, i, le64(data[i:i+8]))
	}
	fmt.Printf("GLOBL %s<>(SB), (NOPTR+RODATA), $%d\n\n", name, len(data))
}

func makeEncodeLUT(last2 [2]byte) []byte {
	lut := []byte("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
	lut[62], lut[63] = last2[0], last2[1]
	return lut
}

func makeMultishiftShuffle() []byte {
	shuffle := make([]byte, 0, 64)
	for group := 0; group < 8; group++ {
		base := byte(group * 6)
		shuffle = append(shuffle,
			base+1, base+0, base+2, base+1,
			base+4, base+3, base+5, base+4,
		)
	}
	return shuffle
}

func makeMultishiftShift() []byte {
	pattern := []byte{10, 4, 22, 16, 42, 36, 54, 48}
	shift := make([]byte, 16)
	copy(shift[0:8], pattern)
	copy(shift[8:16], pattern)
	return shift
}

func makeDecodeLUT(plusOrMinus byte, slashOrUnderscore byte) ([]byte, []byte) {
	lo := make([]byte, 64)
	hi := make([]byte, 64)
	for i := range lo {
		lo[i] = 0xFF
		hi[i] = 0xFF
	}
	lo[plusOrMinus] = 62
	if slashOrUnderscore < 64 {
		lo[slashOrUnderscore] = 63
	} else {
		hi[slashOrUnderscore-64] = 63
	}
	for c := byte('0'); c <= '9'; c++ {
		lo[c] = 52 + c - '0'
	}
	for c := byte('A'); c <= 'Z'; c++ {
		hi[c-64] = c - 'A'
	}
	for c := byte('a'); c <= 'z'; c++ {
		hi[c-64] = 26 + c - 'a'
	}
	return lo, hi
}

func makeDecodeCompress() []byte {
	compress := make([]byte, 64)
	index := 0
	for lane := 0; lane < 4; lane++ {
		base := lane * 16
		for offset := 0; offset < 12; offset++ {
			compress[index] = byte(base + offset)
			index++
		}
	}
	return compress
}

func main() {
	emitBlock("enc512_std_lut", makeEncodeLUT([2]byte{'+', '/'}))
	emitBlock("enc512_url_lut", makeEncodeLUT([2]byte{'-', '_'}))
	emitBlock("enc512_ms_shuffle", makeMultishiftShuffle())
	emitBlock("enc512_ms_shift", makeMultishiftShift())

	stdLo, stdHi := makeDecodeLUT('+', '/')
	emitBlock("stddec512_lut_lo", stdLo)
	emitBlock("stddec512_lut_hi", stdHi)

	urlLo, urlHi := makeDecodeLUT('-', '_')
	emitBlock("urldec512_lut_lo", urlLo)
	emitBlock("urldec512_lut_hi", urlHi)

	emitBlock("dec512_compress", makeDecodeCompress())
}
