// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build amd64 && !purego

package base64

import "golang.org/x/sys/cpu"

var useAVX2 = cpu.X86.HasAVX2
var useAVX512VBMI = cpu.X86.HasAVX512F && cpu.X86.HasAVX512BW && cpu.X86.HasAVX512VBMI

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int

// decodeAsm decodes the standard (url == false) or URL-safe (url == true)
// alphabet prefix of src and returns the number of undecoded trailing bytes.
//
//go:noescape
func decodeAsm(dst, src []byte, url bool) int

func encodeSimd(enc *Encoding, dst, src []byte) int {
	if enc.variant == alphabetCustom {
		return 0
	}
	return encodeAsm(dst, src, enc.lut)
}

func decodeSimd(enc *Encoding, dst, src []byte) int {
	switch enc.variant {
	case alphabetStd:
		return decodeAsm(dst, src, false)
	case alphabetURL:
		return decodeAsm(dst, src, true)
	}
	return len(src)
}
