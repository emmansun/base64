//go:build !amd64 || purego
// +build !amd64 purego

package base64

func encodeSIMD(dst, src []byte, lut *[16]byte) int {
	return 0
}
