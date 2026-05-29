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

func encode(enc *Encoding, dst, src []byte) {
	if len(src) >= 16 && enc.lut != nil {
		var encoded int
		if usePOWER9 {
			encoded = encodeP9Asm(dst, src, enc.lut)
		} else {
			encoded = encodeAsm(dst, src, enc.lut)
		}
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
			if usePOWER9 {
				remain = decodeStdP9Asm(dst, src)
			} else {
				remain = decodeStdAsm(dst, src)
			}
		} else if enc.lut == &encodeURLLut {
			if usePOWER9 {
				remain = decodeUrlP9Asm(dst, src)
			} else {
				remain = decodeUrlAsm(dst, src)
			}
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
