// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build s390x && !purego

package base64

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int

//go:noescape
func decodeStdAsm(dst, src []byte) int

//go:noescape
func decodeUrlAsm(dst, src []byte) int

func encodeSimd(enc *Encoding, dst, src []byte) int {
	if enc.variant == alphabetCustom {
		return 0
	}
	return encodeAsm(dst, src, enc.lut)
}

func decodeSimd(enc *Encoding, dst, src []byte) int {
	switch enc.variant {
	case alphabetStd:
		return decodeStdAsm(dst, src)
	case alphabetURL:
		return decodeUrlAsm(dst, src)
	}
	return len(src)
}
