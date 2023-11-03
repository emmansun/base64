//go:build arm64 && !purego
// +build arm64,!purego

package base64

//go:noescape
func encodeAsm(dst, src []byte, lut *[64]byte) int
