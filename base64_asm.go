//go:build amd64 && !purego
// +build amd64,!purego

package base64

import "golang.org/x/sys/cpu"

var useAVX2 = cpu.X86.HasAVX2
var useAVX = cpu.X86.HasAVX

//go:noescape
func encodeSIMD(dst, src []byte, lut *[16]byte) int
