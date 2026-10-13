// Copyright 2025 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build loong64 && !purego

package base64

import "golang.org/x/sys/cpu"

var (
	supportLSX  = cpu.Loong64.HasLSX
	supportLASX = cpu.Loong64.HasLASX
	useLSX      = supportLSX
	useLASX     = supportLASX
)

func useLoong64ASM() bool {
	return useLSX || useLASX
}

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int

//go:noescape
func decodeStdAsm(dst, src []byte) int

//go:noescape
func decodeUrlAsm(dst, src []byte) int

func encodeSimd(enc *Encoding, dst, src []byte) int {
	if !useLoong64ASM() || enc.variant == alphabetCustom {
		return 0
	}
	return encodeAsm(dst, src, enc.lut)
}

func decodeSimd(enc *Encoding, dst, src []byte) int {
	if !useLoong64ASM() {
		return len(src)
	}
	switch enc.variant {
	case alphabetStd:
		return decodeStdAsm(dst, src)
	case alphabetURL:
		return decodeUrlAsm(dst, src)
	}
	return len(src)
}
