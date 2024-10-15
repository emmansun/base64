// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (ppc64 || ppc64le) && !purego

package base64

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int

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
	return decodeGeneric(enc, dst, src)
}
