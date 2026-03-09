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
// encodeAsm internally falls back to AVX2 for tail bytes, so the return value
// includes both AVX512 rounds and AVX2 tail bytes processed.
func TestAVX512StdEncodeAsm(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI encode test: AVX512 VBMI not supported")
	}
	// Use only AVX512 (Go-level); AVX2 fallback inside encodeAsm is unconditional.
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	base := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz012345"), 10)
	for _, size := range []int{64, 96, 112, 128, 160} {
		src := base[:size]
		ref := StdEncoding.EncodeToString(src)
		dst := make([]byte, len(ref))
		ret := encodeAsm(dst, src, &encodeStdLut)
		// At least one AVX512 round must have run (64 output bytes).
		if ret < 64 {
			t.Errorf("size=%d: ret=%d < 64, AVX512 not entered", size, ret)
			continue
		}
		// The first ret output bytes must match the standard encoding prefix.
		if !bytes.Equal(dst[:ret], []byte(ref)[:ret]) {
			t.Errorf("size=%d ret=%d: output mismatch\n  got:  %s\n  want: %s",
				size, ret, dst[:ret], []byte(ref)[:ret])
		}
	}
}

// TestAVX512URLEncodeAsm verifies the AVX512 VBMI encode path for URL-safe base64.
// encodeAsm internally falls back to AVX2 for tail bytes.
func TestAVX512URLEncodeAsm(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip AVX512 VBMI url-encode test: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	base := bytes.Repeat([]byte("!?$*&()'-=@~ABCD"), 10)
	for _, size := range []int{64, 96, 112, 128, 160} {
		src := base[:size]
		ref := URLEncoding.EncodeToString(src)
		dst := make([]byte, len(ref))
		ret := encodeAsm(dst, src, &encodeURLLut)
		if ret < 64 {
			t.Errorf("size=%d: ret=%d < 64, AVX512 not entered", size, ret)
			continue
		}
		if !bytes.Equal(dst[:ret], []byte(ref)[:ret]) {
			t.Errorf("size=%d ret=%d: output mismatch\n  got:  %s\n  want: %s",
				size, ret, dst[:ret], []byte(ref)[:ret])
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

// avx512EncRoundsOutput computes the number of output bytes produced by the
// AVX512 loop alone (no AVX2 tail), given an input of n bytes.
// Since CX_final ∈ [16,63] whenever CX_initial ≥ 64, the AVX2 tail always
// runs after the AVX512 loop; this function is used to prove that.
func avx512EncRoundsOutput(n int) int {
	cx, si := n, 0
	for cx >= 64 {
		si += 64
		cx -= 48
	}
	return si
}

// TestAVX512EncodeAVX2Tail verifies that encodeAsm's internal AVX2 fallback
// processes tail bytes after the AVX512 loop rather than returning early.
// After any AVX512 run, CX_final ∈ [16,63], so the AVX2 tail always runs.
func TestAVX512EncodeAVX2Tail(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	base := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz012345"), 10)
	for _, size := range []int{64, 76, 88, 100, 112, 124, 136, 160} {
		src := base[:size]
		ref := StdEncoding.EncodeToString(src)

		dst := make([]byte, len(ref))
		ret := encodeAsm(dst, src, &encodeStdLut)

		// ret must exceed what the AVX512 loop alone would have produced,
		// confirming the AVX2 internal fallback processed additional tail bytes.
		avx512Only := avx512EncRoundsOutput(size)
		if ret <= avx512Only {
			t.Errorf("size=%d: ret=%d not > avx512Only=%d; AVX2 tail fallback did not run",
				size, ret, avx512Only)
		}
		// Output must match the standard encoding prefix up to ret bytes.
		if !bytes.Equal(dst[:ret], []byte(ref)[:ret]) {
			t.Errorf("size=%d ret=%d: output mismatch\n  got:  %s\n  want: %s",
				size, ret, dst[:ret], []byte(ref)[:ret])
		}
	}
}

// TestAVX512URLEncodeAVX2Tail is the URL-safe variant of TestAVX512EncodeAVX2Tail.
func TestAVX512URLEncodeAVX2Tail(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	base := bytes.Repeat([]byte("!?$*&()'-=@~ABCDEFGHIJKLMNOPQRST"), 10)
	for _, size := range []int{64, 88, 112, 136, 160} {
		src := base[:size]
		ref := URLEncoding.EncodeToString(src)

		dst := make([]byte, len(ref))
		ret := encodeAsm(dst, src, &encodeURLLut)

		avx512Only := avx512EncRoundsOutput(size)
		if ret <= avx512Only {
			t.Errorf("size=%d: ret=%d not > avx512Only=%d; AVX2 tail fallback did not run",
				size, ret, avx512Only)
		}
		if !bytes.Equal(dst[:ret], []byte(ref)[:ret]) {
			t.Errorf("size=%d ret=%d: output mismatch\n  got:  %s\n  want: %s",
				size, ret, dst[:ret], []byte(ref)[:ret])
		}
	}
}

// TestAVX512StdDecodeAVX2Tail verifies that decodeStdAsm's internal AVX2 fallback
// processes tail bytes after the AVX512 loop.  Input sizes chosen so that
// (inputLen - 64*N) ∈ [24,63], hitting the avx2_loop / avx2_tail path.
func TestAVX512StdDecodeAVX2Tail(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	base := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz012345"), 10)
	// Encoded input sizes: 64+24=88, 64+32=96, 64+48=112, 128+32=160
	for _, rawSize := range []int{66, 72, 84, 120} {
		raw := base[:rawSize]
		enc := []byte(StdEncoding.EncodeToString(raw))
		// Trim padding so encLen is divisible by 4 with no '=' (clean blocks only)
		encLen := (rawSize / 3) * 4 // only complete 3-byte groups → 4-char blocks
		enc = enc[:encLen]

		dst := make([]byte, rawSize)
		remain := decodeStdAsm(dst, enc)

		// AVX2 tail must have consumed some bytes: remain < encLen.
		if remain >= encLen {
			t.Errorf("encLen=%d: remain=%d >= encLen; nothing decoded by ASM", encLen, remain)
			continue
		}
		// The decoded portion (enc[:encLen-remain]) must match raw.
		decoded := encLen - remain
		inputConsumed := (decoded / 4) * 3
		if !bytes.Equal(dst[:inputConsumed], raw[:inputConsumed]) {
			t.Errorf("encLen=%d: decoded bytes mismatch at %d bytes", encLen, inputConsumed)
		}
	}
}

// TestAVX512URLDecodeAVX2Tail is the URL-safe variant of TestAVX512StdDecodeAVX2Tail.
func TestAVX512URLDecodeAVX2Tail(t *testing.T) {
	if !useAVX512VBMI {
		t.Skip("skip: AVX512 VBMI not supported")
	}
	oldAVX2 := useAVX2
	useAVX2 = false
	defer func() { useAVX2 = oldAVX2 }()

	base := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxyz012345"), 10)
	for _, rawSize := range []int{66, 72, 84, 120} {
		raw := base[:rawSize]
		enc := []byte(URLEncoding.EncodeToString(raw))
		encLen := (rawSize / 3) * 4
		enc = enc[:encLen]

		dst := make([]byte, rawSize)
		remain := decodeUrlAsm(dst, enc)

		if remain >= encLen {
			t.Errorf("encLen=%d: remain=%d >= encLen; nothing decoded by ASM", encLen, remain)
			continue
		}
		decoded := encLen - remain
		inputConsumed := (decoded / 4) * 3
		if !bytes.Equal(dst[:inputConsumed], raw[:inputConsumed]) {
			t.Errorf("encLen=%d: decoded bytes mismatch at %d bytes", encLen, inputConsumed)
		}
	}
}
