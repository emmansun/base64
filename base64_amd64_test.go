// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build amd64 && !purego

package base64

import (
	"bytes"
	"testing"
)

// TestAVX512StdEncodeAsm verifies the AVX512 VBMI encode path for standard base64.
func TestAVX512StdEncodeAsm(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI encode test: AVX512 VBMI not supported")
	}
	pairs := []testpair{
		// 64 bytes input (48 useful + 16 tail) → 1 AVX512 round → 64 output bytes
		// AVX512 processes src[0:48], encodeAsm returns 64; the 16-byte tail is left for encodeGeneric.
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl0000000000000000",
			"YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		// 112 bytes input (96 useful + 16 tail) → 2 AVX512 rounds → 128 output bytes
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl0000000000000000",
			"YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	// Use only AVX512, temporarily disable AVX2
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		// AVX512 encode requires CX ≥ 64; each round processes 48 input → 64 output bytes.
		// nRounds = (len(src)-16)/48 (integer); the 16-byte tail is left for encodeGeneric.
		asmBytes := ((len(src) - 16) / 48) * 64
		dst := make([]byte, StdEncoding.EncodedLen(len(src)))
		ret := encodeAsm(dst, src, &encodeStdLut)
		if ret != asmBytes {
			t.Errorf("len=%d: ret=%d want=%d", len(src), ret, asmBytes)
		}
		if !bytes.Equal(dst[:ret], expected[:ret]) {
			t.Errorf("len=%d: got %x, want %x", len(src), dst[:ret], expected[:ret])
		}
	}
}

// TestAVX512URLEncodeAsm verifies the AVX512 VBMI encode path for URL-safe base64.
func TestAVX512URLEncodeAsm(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI url-encode test: AVX512 VBMI not supported")
	}
	pairs := []testpair{
		// 64 bytes input (48 useful + 16 tail) → 1 AVX512 round → 64 output bytes
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~0000000000000000",
			"IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
		// 112 bytes input (96 useful + 16 tail) → 2 AVX512 rounds → 128 output bytes
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~0000000000000000",
			"IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		asmBytes := ((len(src) - 16) / 48) * 64
		dst := make([]byte, URLEncoding.EncodedLen(len(src)))
		ret := encodeAsm(dst, src, &encodeURLLut)
		if ret != asmBytes {
			t.Errorf("len=%d: ret=%d want=%d", len(src), ret, asmBytes)
		}
		if !bytes.Equal(dst[:ret], expected[:ret]) {
			t.Errorf("len=%d: got %x, want %x", len(src), dst[:ret], expected[:ret])
		}
	}
}

// TestAVX512StdDecodeAsm verifies the AVX512 VBMI decode path for standard base64.
func TestAVX512StdDecodeAsm(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI std-decode test: AVX512 VBMI not supported")
	}
	pairs := []testpair{
		// exactly 64 bytes input → 48 bytes output (one AVX512 round)
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl",
			"YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		// 96 bytes raw → 128 bytes base64 (two AVX512 rounds)
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl",
			"YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))
		ret := decodeStdAsm(dst, src)
		if ret == len(src) {
			t.Errorf("len=%d: ret=len(src) means no bytes decoded", len(src))
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("len=%d: got %x, want %x", len(src), dst, expected)
		}
	}
}

// TestAVX512StdDecodeAsmWithError verifies that an invalid byte causes early exit.
func TestAVX512StdDecodeAsmWithError(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI std-decode error test: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	dst := make([]byte, 64)
	// Invalid character '!' at position 0 — must bail immediately
	src := []byte("!WJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts")
	ret := decodeStdAsm(dst, src)
	if ret != len(src) {
		t.Errorf("expected ret=len(src)=%d on invalid input, got %d", len(src), ret)
	}
}

// TestAVX512URLDecodeAsm verifies the AVX512 VBMI decode path for URL-safe base64.
func TestAVX512URLDecodeAsm(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI url-decode test: AVX512 VBMI not supported")
	}
	pairs := []testpair{
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~",
			"IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl",
			"YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))
		ret := decodeUrlAsm(dst, src)
		if ret == len(src) {
			t.Errorf("len=%d: ret=len(src) means no bytes decoded", len(src))
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("len=%d: got %x, want %x", len(src), dst, expected)
		}
	}
}

// TestAVX512URLDecodeAsmWithError verifies that an invalid byte causes early exit.
func TestAVX512URLDecodeAsmWithError(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI url-decode error test: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	dst := make([]byte, 64)
	// '/' is invalid in URL-safe base64
	src := []byte("IT8kKiYoKSctPUB/IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-")
	ret := decodeUrlAsm(dst, src)
	if ret != len(src) {
		t.Errorf("expected ret=len(src)=%d on invalid input, got %d", len(src), ret)
	}
}

// TestAVX512DispatchConsistencyEncode verifies AVX512 encode matches generic output.
func TestAVX512DispatchConsistencyEncode(t *testing.T) {
	oldAVX512, oldAVX2 := useAVX512VBMI, useAVX2
	defer func() {
		useAVX512VBMI, useAVX2 = oldAVX512, oldAVX2
	}()

	// sizes that exercise various code paths: < 64 (skips AVX512), ≥ 64, multi-round
	sizes := []int{12, 24, 48, 96, 192, 384}
	for _, size := range sizes {
		src := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz012345"), (size+31)/32)[:size]

		withGeneric := make([]byte, StdEncoding.EncodedLen(size))
		useAVX512VBMI, useAVX2 = false, false
		encode(StdEncoding, withGeneric, src)

		if !useAVX512VBMI && !oldAVX512 {
			// AVX512 not available — skip comparison but test doesn't fail
			continue
		}
		withAVX512 := make([]byte, StdEncoding.EncodedLen(size))
		useAVX512VBMI, useAVX2 = oldAVX512, false
		encode(StdEncoding, withAVX512, src)
		if !bytes.Equal(withGeneric, withAVX512) {
			t.Fatalf("size=%d: AVX512 encode mismatch vs generic", size)
		}
	}
}

// TestAVX512DispatchConsistencyDecode verifies AVX512 decode matches generic output.
func TestAVX512DispatchConsistencyDecode(t *testing.T) {
	oldAVX512, oldAVX2 := useAVX512VBMI, useAVX2
	defer func() {
		useAVX512VBMI, useAVX2 = oldAVX512, oldAVX2
	}()

	sizes := []int{12, 24, 48, 96, 192, 384}
	for _, size := range sizes {
		raw := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz012345"), (size+31)/32)[:size]
		enc := make([]byte, StdEncoding.EncodedLen(size))
		StdEncoding.Encode(enc, raw)

		dstGeneric := make([]byte, StdEncoding.DecodedLen(len(enc)))
		useAVX512VBMI, useAVX2 = false, false
		n1, err1 := decode(StdEncoding, dstGeneric, enc)

		if !useAVX512VBMI && !oldAVX512 {
			continue
		}
		dstAVX512 := make([]byte, StdEncoding.DecodedLen(len(enc)))
		useAVX512VBMI, useAVX2 = oldAVX512, false
		n2, err2 := decode(StdEncoding, dstAVX512, enc)
		if n1 != n2 || err1 != err2 {
			t.Fatalf("size=%d: result mismatch generic=(%d,%v) avx512=(%d,%v)", size, n1, err1, n2, err2)
		}
		if !bytes.Equal(dstGeneric[:n1], dstAVX512[:n2]) {
			t.Fatalf("size=%d: decoded bytes mismatch between generic and AVX512", size)
		}
	}
}

// TestAVX512BoundaryConsistency verifies AVX512 + fallback together match generic
// across a range of input lengths around the 64-byte threshold.
func TestAVX512BoundaryConsistency(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 boundary test: AVX512 VBMI not supported")
	}

	oldAVX512, oldAVX2 := useAVX512VBMI, useAVX2
	defer func() {
		useAVX512VBMI, useAVX2 = oldAVX512, oldAVX2
	}()

	base := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz0123456789ABCD"), 10)
	for size := 1; size <= 200; size++ {
		src := base[:size]

		// Generic path
		withGeneric := make([]byte, StdEncoding.EncodedLen(size))
		useAVX512VBMI, useAVX2 = false, false
		encode(StdEncoding, withGeneric, src)

		// AVX512 + fallback path
		withAVX512 := make([]byte, StdEncoding.EncodedLen(size))
		useAVX512VBMI, useAVX2 = true, true
		encode(StdEncoding, withAVX512, src)

		if !bytes.Equal(withGeneric, withAVX512) {
			t.Fatalf("encode size=%d: mismatch\n  generic: %s\n  avx512:  %s", size, withGeneric, withAVX512)
		}

		// Decode round-trip
		dstGeneric := make([]byte, size)
		useAVX512VBMI, useAVX2 = false, false
		n1, err1 := decode(StdEncoding, dstGeneric, withGeneric)

		dstAVX512 := make([]byte, size)
		useAVX512VBMI, useAVX2 = true, true
		n2, err2 := decode(StdEncoding, dstAVX512, withGeneric)

		if n1 != n2 || err1 != err2 {
			t.Fatalf("decode size=%d: result mismatch generic=(%d,%v) avx512=(%d,%v)", size, n1, err1, n2, err2)
		}
		if !bytes.Equal(dstGeneric[:n1], dstAVX512[:n2]) {
			t.Fatalf("decode size=%d: bytes mismatch", size)
		}
	}
}
