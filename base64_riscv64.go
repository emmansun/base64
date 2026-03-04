// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build riscv64 && !purego

package base64

import "golang.org/x/sys/cpu"

var supportRVV = cpu.RISCV64.HasV

//go:noescape
func encodeAsm(dst, src []byte, lut *[64]byte) int

func encode(enc *Encoding, dst, src []byte) {
	if supportRVV && len(src) >= 16 && enc.lut != nil {
		encoded := encodeAsm(dst, src, &enc.encode)
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
