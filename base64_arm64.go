//go:build arm64 && !purego
// +build arm64,!purego

package base64

var dencodeStdLut1 = [128]byte{
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
	255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 62, 255, 255, 255, 63,
	52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 255, 255, 255, 255, 255, 255,
	0, 255, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
	14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 255, 255, 255, 255,
	255, 255, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
	40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 255, 255, 255, 255,
}

//go:noescape
func encodeAsm(dst, src []byte, lut *[64]byte) int

//go:noescape
func decodeAsm(dst, src []byte, lut *[128]byte) int

func encode(enc *Encoding, dst, src []byte) {
	if len(src) >= 48 {
		encoded := encodeAsm(dst, src, &enc.encode)
		src = src[(encoded/4)*3:]
		dst = dst[encoded:]
	}
	encodeGeneric(enc, dst, src)
}

func decode(enc *Encoding, dst, src []byte) (int, error) {
	return decodeGeneric(enc, dst, src)
}
