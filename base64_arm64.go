//go:build arm64 && !purego
// +build arm64,!purego

package base64

//go:noescape
func encodeAsm(dst, src []byte, lut *[64]byte) int

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
