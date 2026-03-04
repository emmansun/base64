// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build riscv64 && !purego

package base64

import (
	"bytes"
	"testing"

	"golang.org/x/sys/cpu"
)

func TestStdEncodeAsm(t *testing.T) {
	if !cpu.RISCV64.HasV {
		t.Skip("skip riscv64 asm test: RVV not supported")
	}
	inputs := [][]byte{
		[]byte("abcdefghijkl"),
		[]byte("\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed"),
		[]byte("abcdefghijklabcdefghijkl"),
		[]byte("abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl"),
	}
	for _, src := range inputs {
		dst := make([]byte, StdEncoding.EncodedLen(len(src)))
		ret := encodeAsm(dst, src, &StdEncoding.encode)

		expectedRet := (len(src) / 3) * 4
		if ret != expectedRet {
			t.Fatalf("ret=%d, expected=%d", ret, expectedRet)
		}

		expected := make([]byte, StdEncoding.EncodedLen((len(src)/3)*3))
		encodeGeneric(StdEncoding, expected, src[:(len(src)/3)*3])
		if !bytes.Equal(dst[:ret], expected[:ret]) {
			t.Fatalf("got %x, expected %x", dst[:ret], expected[:ret])
		}
	}
}

func TestEncodeAsmReturnPrefix(t *testing.T) {
	if !cpu.RISCV64.HasV {
		t.Skip("skip riscv64 asm test: RVV not supported")
	}

	for _, n := range []int{1, 2, 3, 4, 5, 11, 12, 13, 15, 16, 47, 48, 49, 64, 65, 96, 127} {
		src := bytes.Repeat([]byte{0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67}, (n+6)/7)[:n]
		dst := make([]byte, StdEncoding.EncodedLen(len(src)))
		ret := encodeAsm(dst, src, &StdEncoding.encode)

		expectedRet := (len(src) / 3) * 4
		if ret != expectedRet {
			t.Fatalf("n=%d ret=%d expectedRet=%d", n, ret, expectedRet)
		}

		expected := make([]byte, StdEncoding.EncodedLen((len(src)/3)*3))
		encodeGeneric(StdEncoding, expected, src[:(len(src)/3)*3])
		if !bytes.Equal(dst[:ret], expected[:ret]) {
			t.Fatalf("n=%d asm prefix mismatch", n)
		}
	}
}

func TestEncodeRVVDispatchConsistency(t *testing.T) {
	old := supportRVV
	defer func() { supportRVV = old }()

	src := []byte("abcdefghijklabcdefghijklabcdefghijklabcdefghijkl")
	encodedLen := StdEncoding.EncodedLen(len(src))

	withFallback := make([]byte, encodedLen)
	supportRVV = false
	encode(StdEncoding, withFallback, src)

	if !cpu.RISCV64.HasV {
		t.Skip("skip RVV dispatch path test: RVV not supported")
	}

	withRVVFlag := make([]byte, encodedLen)
	supportRVV = true
	encode(StdEncoding, withRVVFlag, src)

	if !bytes.Equal(withRVVFlag, withFallback) {
		t.Fatalf("mismatch between RVV dispatch and fallback path")
	}
}
