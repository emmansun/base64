// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (amd64 || ppc64 || ppc64le || s390x) && !purego

package base64

import (
	"bytes"
	"testing"
)

func TestStdEncodeAsm(t *testing.T) {
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
	dst := make([]byte, 16)
	src := []byte("-YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts")
	ret := decodeStdAsm(dst, src)
	if ret != len(src) {
		t.Errorf("should return original length")
	}
}

func TestURLEncodeAsm(t *testing.T) {
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
	dst := make([]byte, 16)
	src := []byte("IT8kKiYoKSctPUB/IT8kKiYoKSctPUB/")
	ret := decodeUrlAsm(dst, src)
	if ret != len(src) {
		t.Errorf("should return original length")
	}
}

func TestDecodeWithLengthLessThan24(t *testing.T) {
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
