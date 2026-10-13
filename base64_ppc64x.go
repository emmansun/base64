// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (ppc64 || ppc64le) && !purego

package base64

import "golang.org/x/sys/cpu"

// usePOWER9 is true on Power9+ hardware (ISA 3.0+), enabling LXVB16X/STXVB16X
// which provide natural byte-order load/store without the VPERM/XXPERMDI overhead.
var usePOWER9 = cpu.PPC64.IsPOWER9

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int

//go:noescape
func encodeP9Asm(dst, src []byte, lut *[16]byte) int

//go:noescape
func decodeStdAsm(dst, src []byte) int

//go:noescape
func decodeUrlAsm(dst, src []byte) int

//go:noescape
func decodeStdP9Asm(dst, src []byte) int

//go:noescape
func decodeUrlP9Asm(dst, src []byte) int

func encodeSimd(enc *Encoding, dst, src []byte) int {
	if enc.variant == alphabetCustom {
		return 0
	}
	if usePOWER9 {
		return encodeP9Asm(dst, src, enc.lut)
	}
	return encodeAsm(dst, src, enc.lut)
}

func decodeSimd(enc *Encoding, dst, src []byte) int {
	switch enc.variant {
	case alphabetStd:
		if usePOWER9 {
			return decodeStdP9Asm(dst, src)
		}
		return decodeStdAsm(dst, src)
	case alphabetURL:
		if usePOWER9 {
			return decodeUrlP9Asm(dst, src)
		}
		return decodeUrlAsm(dst, src)
	}
	return len(src)
}
