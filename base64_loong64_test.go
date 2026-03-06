// Copyright 2025 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build loong64 && !purego

package base64

import (
	"bytes"
	"testing"
)

func TestStdEncodeAsm(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	pairs := []testpair{
		{"abcdefghijkl0000", "YWJjZGVmZ2hpamts"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed\x5a\xcc\x70\x90", "K/fMJwH+Q5e0nr7t"},
		{"abcdefghijklabcdefghijkl0000", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeAsm(dst, src, &encodeStdLut)
		if ret != len(expected) {
			t.Errorf("should return %v, got %v", len(expected), ret)
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}

	}
}

func TestStdDecodeAsm(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	pairs := []testpair{
		{"abcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed", "K/fMJwH+Q5e0nr7tK/fMJwH+Q5e0nr7t"},
		{"abcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := decodeStdAsm(dst, src)
		if ret == len(src) {
			t.Errorf("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func TestStdDecodeAsmWithError(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	dst := make([]byte, 16)
	src := []byte("-YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts")
	ret := decodeStdAsm(dst, src)
	if ret != len(src) {
		t.Errorf("should return original length")
	}
}

func TestURLEncodeAsm(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	pairs := []testpair{
		{"!?$*&()'-=@~0000", "IT8kKiYoKSctPUB-"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed\x5a\xcc\x70\x90", "K_fMJwH-Q5e0nr7t"},
		{"!?$*&()'-=@~!?$*&()'-=@~0000", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeAsm(dst, src, &encodeURLLut)
		if ret != len(expected) {
			t.Errorf("should return %v", len(expected))
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %v", string(dst))
		}

	}
}

func TestUrlDecodeAsm(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	pairs := []testpair{
		{"!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed", "K_fMJwH-Q5e0nr7tK_fMJwH-Q5e0nr7t"},
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := decodeUrlAsm(dst, src)
		if ret == len(src) {
			t.Errorf("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func TestUrlDecodeAsmWithError(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	dst := make([]byte, 16)
	src := []byte("IT8kKiYoKSctPUB/IT8kKiYoKSctPUB/")
	ret := decodeUrlAsm(dst, src)
	if ret != len(src) {
		t.Errorf("should return original length")
	}
}

func TestDecodeWithLengthLessThan24(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm test: LSX not supported")
	}
	dst1 := make([]byte, 24)
	dst2 := make([]byte, 24)
	src := []byte("abcdefghijklabcdefghijklabcdefghijklabcdefghijkl")
	for i := 12; i < 18; i++ {
		input := src[:i]
		encodeGeneric(StdEncoding, dst1, input)
		decode(StdEncoding, dst2, dst1[:StdEncoding.EncodedLen(len(input))])
		if !bytes.Equal(dst2[:len(input)], input) {
			t.Errorf("StdEncoding %v got %x, expected %x", i, dst2[:len(input)], input)
		}
		// test with padding
		encodeGeneric(RawStdEncoding, dst1, input)
		decode(RawStdEncoding, dst2, dst1[:RawStdEncoding.EncodedLen(len(input))])
		if !bytes.Equal(dst2[:len(input)], input) {
			t.Errorf("RawStdEncoding %v got %x, expected %x", i, dst2[:len(input)], input)
		}
	}
}

func TestEncodeLoong64DispatchConsistency(t *testing.T) {
	oldLSX, oldLASX := useLSX, useLASX
	defer func() {
		useLSX, useLASX = oldLSX, oldLASX
	}()

	src := []byte("abcdefghijklabcdefghijklabcdefghijklabcdefghijkl")
	encodedLen := StdEncoding.EncodedLen(len(src))

	withGeneric := make([]byte, encodedLen)
	useLSX, useLASX = false, false
	encode(StdEncoding, withGeneric, src)

	if !supportLSX {
		t.Skip("skip loong64 dispatch path test: LSX not supported")
	}

	withLSX := make([]byte, encodedLen)
	useLSX, useLASX = true, false
	encode(StdEncoding, withLSX, src)
	if !bytes.Equal(withGeneric, withLSX) {
		t.Fatalf("mismatch between generic and LSX path")
	}

	if supportLASX {
		withLASX := make([]byte, encodedLen)
		useLSX, useLASX = true, true
		encode(StdEncoding, withLASX, src)
		if !bytes.Equal(withGeneric, withLASX) {
			t.Fatalf("mismatch between generic and LASX path")
		}

		withLASXOnly := make([]byte, encodedLen)
		useLSX, useLASX = false, true
		encode(StdEncoding, withLASXOnly, src)
		if !bytes.Equal(withGeneric, withLASXOnly) {
			t.Fatalf("mismatch between generic and LASX-only toggle path")
		}
	}
}

func TestDecodeLoong64DispatchConsistency(t *testing.T) {
	oldLSX, oldLASX := useLSX, useLASX
	defer func() {
		useLSX, useLASX = oldLSX, oldLASX
	}()

	raw := []byte("abcdefghijklabcdefghijkl")
	enc := make([]byte, StdEncoding.EncodedLen(len(raw)))
	StdEncoding.Encode(enc, raw)

	dstGeneric := make([]byte, StdEncoding.DecodedLen(len(enc)))
	useLSX, useLASX = false, false
	n1, err1 := decode(StdEncoding, dstGeneric, enc)

	if !supportLSX {
		t.Skip("skip loong64 dispatch path test: LSX not supported")
	}

	dstLSX := make([]byte, StdEncoding.DecodedLen(len(enc)))
	useLSX, useLASX = true, false
	n2, err2 := decode(StdEncoding, dstLSX, enc)
	if n1 != n2 || err1 != err2 {
		t.Fatalf("decode result mismatch: generic=(%d,%v) lsx=(%d,%v)", n1, err1, n2, err2)
	}
	if !bytes.Equal(dstGeneric[:n1], dstLSX[:n2]) {
		t.Fatalf("decode bytes mismatch between generic and LSX paths")
	}

	if supportLASX {
		dstLASX := make([]byte, StdEncoding.DecodedLen(len(enc)))
		useLSX, useLASX = true, true
		n3, err3 := decode(StdEncoding, dstLASX, enc)
		if n1 != n3 || err1 != err3 {
			t.Fatalf("decode result mismatch: generic=(%d,%v) lasx=(%d,%v)", n1, err1, n3, err3)
		}
		if !bytes.Equal(dstGeneric[:n1], dstLASX[:n3]) {
			t.Fatalf("decode bytes mismatch between generic and LASX paths")
		}

		dstLASXOnly := make([]byte, StdEncoding.DecodedLen(len(enc)))
		useLSX, useLASX = false, true
		n4, err4 := decode(StdEncoding, dstLASXOnly, enc)
		if n1 != n4 || err1 != err4 {
			t.Fatalf("decode result mismatch: generic=(%d,%v) lasx-only=(%d,%v)", n1, err1, n4, err4)
		}
		if !bytes.Equal(dstGeneric[:n1], dstLASXOnly[:n4]) {
			t.Fatalf("decode bytes mismatch between generic and LASX-only paths")
		}
	}

	bad := []byte("YWJj?GVmZ2hpamts")
	dstGeneric = make([]byte, StdEncoding.DecodedLen(len(bad)))
	useLSX, useLASX = false, false
	n1, err1 = decode(StdEncoding, dstGeneric, bad)

	dstLSX = make([]byte, StdEncoding.DecodedLen(len(bad)))
	useLSX, useLASX = true, false
	n2, err2 = decode(StdEncoding, dstLSX, bad)
	if n1 != n2 || err1 == nil || err2 == nil {
		t.Fatalf("expected matching decode errors, generic=(%d,%v) lsx=(%d,%v)", n1, err1, n2, err2)
	}
	if !bytes.Equal(dstGeneric[:n1], dstLSX[:n2]) {
		t.Fatalf("decoded prefix mismatch on invalid input")
	}

	if supportLASX {
		dstLASX := make([]byte, StdEncoding.DecodedLen(len(bad)))
		useLSX, useLASX = true, true
		n3, err3 := decode(StdEncoding, dstLASX, bad)
		if n1 != n3 || err3 == nil {
			t.Fatalf("expected matching decode errors, generic=(%d,%v) lasx=(%d,%v)", n1, err1, n3, err3)
		}
		if !bytes.Equal(dstGeneric[:n1], dstLASX[:n3]) {
			t.Fatalf("decoded prefix mismatch on invalid input with LASX")
		}

		dstLASXOnly := make([]byte, StdEncoding.DecodedLen(len(bad)))
		useLSX, useLASX = false, true
		n4, err4 := decode(StdEncoding, dstLASXOnly, bad)
		if n1 != n4 || err4 == nil {
			t.Fatalf("expected matching decode errors, generic=(%d,%v) lasx-only=(%d,%v)", n1, err1, n4, err4)
		}
		if !bytes.Equal(dstGeneric[:n1], dstLASXOnly[:n4]) {
			t.Fatalf("decoded prefix mismatch on invalid input with LASX-only")
		}
	}
}

func TestLoong64AsmBoundaryConsistency(t *testing.T) {
	if !supportLSX {
		t.Skip("skip loong64 asm boundary test: LSX not supported")
	}

	oldLSX, oldLASX := useLSX, useLASX
	defer func() {
		useLSX, useLASX = oldLSX, oldLASX
	}()

	encodeSizes := []int{16, 27, 28, 51, 52, 53, 76, 100}
	for _, n := range encodeSizes {
		src := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxy"), (n+24)/25)[:n]
		dstLSX := make([]byte, StdEncoding.EncodedLen(n))
		useLSX, useLASX = true, false
		retLSX := encodeAsm(dstLSX, src, &encodeStdLut)

		retLASX := retLSX
		dstLASX := append([]byte(nil), dstLSX...)
		if supportLASX {
			dstLASX = make([]byte, StdEncoding.EncodedLen(n))
			useLSX, useLASX = false, true
			retLASX = encodeAsm(dstLASX, src, &encodeStdLut)
		}

		if retLSX != retLASX {
			t.Fatalf("encode size=%d return mismatch lsx=%d lasx=%d", n, retLSX, retLASX)
		}
		if !bytes.Equal(dstLSX[:retLSX], dstLASX[:retLASX]) {
			t.Fatalf("encode size=%d prefix mismatch between lsx and lasx", n)
		}
	}

	decodeSizes := []int{24, 39, 40, 63, 64, 65, 96, 128}
	for _, n := range decodeSizes {
		rawLen := (n / 4) * 3
		raw := bytes.Repeat([]byte("abcdefghijklmnopqrstuvwxy"), (rawLen+24)/25)[:rawLen]
		src := make([]byte, StdEncoding.EncodedLen(len(raw)))
		StdEncoding.Encode(src, raw)
		src = src[:n]

		dstLSX := make([]byte, StdEncoding.DecodedLen(len(src)))
		useLSX, useLASX = true, false
		remainLSX := decodeStdAsm(dstLSX, src)

		remainLASX := remainLSX
		dstLASX := append([]byte(nil), dstLSX...)
		if supportLASX {
			dstLASX = make([]byte, StdEncoding.DecodedLen(len(src)))
			useLSX, useLASX = false, true
			remainLASX = decodeStdAsm(dstLASX, src)
		}

		if remainLSX != remainLASX {
			t.Fatalf("decode std size=%d remain mismatch lsx=%d lasx=%d", n, remainLSX, remainLASX)
		}
		decoded := ((len(src) - remainLSX) / 4) * 3
		if !bytes.Equal(dstLSX[:decoded], dstLASX[:decoded]) {
			t.Fatalf("decode std size=%d prefix mismatch between lsx and lasx", n)
		}

		srcURL := []byte(RawURLEncoding.EncodeToString(raw))
		if len(srcURL) < n {
			srcURL = append(srcURL, bytes.Repeat([]byte("A"), n-len(srcURL))...)
		}
		srcURL = srcURL[:n]
		dstLSXURL := make([]byte, RawURLEncoding.DecodedLen(len(srcURL)))
		useLSX, useLASX = true, false
		remainLSXURL := decodeUrlAsm(dstLSXURL, srcURL)

		remainLASXURL := remainLSXURL
		dstLASXURL := append([]byte(nil), dstLSXURL...)
		if supportLASX {
			dstLASXURL = make([]byte, RawURLEncoding.DecodedLen(len(srcURL)))
			useLSX, useLASX = false, true
			remainLASXURL = decodeUrlAsm(dstLASXURL, srcURL)
		}

		if remainLSXURL != remainLASXURL {
			t.Fatalf("decode url size=%d remain mismatch lsx=%d lasx=%d", n, remainLSXURL, remainLASXURL)
		}
		decodedURL := ((len(srcURL) - remainLSXURL) / 4) * 3
		if !bytes.Equal(dstLSXURL[:decodedURL], dstLASXURL[:decodedURL]) {
			t.Fatalf("decode url size=%d prefix mismatch between lsx and lasx", n)
		}
	}
}
