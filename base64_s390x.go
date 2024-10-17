// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build !purego

package base64

//go:noescape
func encodeAsm(dst, src []byte, lut *[16]byte) int
