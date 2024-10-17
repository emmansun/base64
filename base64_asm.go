// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (amd64 || ppc64 || ppc64le) && !purego

package base64

import "golang.org/x/sys/cpu"

var useAVX2 = cpu.X86.HasAVX2
var useAVX = cpu.X86.HasAVX

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int

//go:noescape
func decodeStdAsm(dst, src []byte) int

//go:noescape
func decodeUrlAsm(dst, src []byte) int

func encode(enc *Encoding, dst, src []byte) {
	if len(src) >= 16 && enc.lut != nil {
		encoded := encodeAsm(dst, src, enc.lut)
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
			remain = decodeStdAsm(dst, src)
		} else if enc.lut == &encodeURLLut {
			remain = decodeUrlAsm(dst, src)
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
