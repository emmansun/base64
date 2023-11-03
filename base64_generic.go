//go:build !amd64 && !arm64 || purego
// +build !amd64,!arm64 purego

package base64

func encode(enc *Encoding, dst, src []byte) {
	encodeGeneric(enc, dst, src)
}

func decode(enc *Encoding, dst, src []byte) (int, error) {
	return decodeGeneric(enc, dst, src)
}
