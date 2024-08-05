//go:build amd64 && !purego

package base64

import "golang.org/x/sys/cpu"

var useAVX2 = cpu.X86.HasAVX2
var useAVX = cpu.X86.HasAVX

//go:noescape
func encodeSIMD(dst, src []byte, lut *[16]byte) int

//go:noescape
func decodeStdSIMD(dst, src []byte) int

//go:noescape
func decodeUrlSIMD(dst, src []byte) int

func encode(enc *Encoding, dst, src []byte) {
	if len(src) >= 16 && enc.lut != nil {
		encoded := encodeSIMD(dst, src, enc.lut)
		if encoded > 0 {
			src = src[(encoded/4)*3:]
			dst = dst[encoded:]
		}
	}
	encodeGeneric(enc, dst, src)
}

func decode(enc *Encoding, dst, src []byte) (int, error) {
	srcLen := len(src)
	if srcLen >= 24 {
		remain := srcLen
		if enc.lut == &encodeStdLut {
			remain = decodeStdSIMD(dst, src)
		} else if enc.lut == &encodeURLLut {
			remain = decodeUrlSIMD(dst, src)
		}

		if remain < srcLen {
			// decoded by SIMD
			remain = srcLen - remain // remain is decoded length now
			src = src[remain:]
			dstStart := (remain / 4) * 3
			dst = dst[dstStart:]
			n, err := decodeGeneric(enc, dst, src)
			if cerr, ok := err.(CorruptInputError); ok {
				return n + dstStart, CorruptInputError(int(cerr) + remain)
			}
			return n + dstStart, err
		}
	}
	return decodeGeneric(enc, dst, src)
}
