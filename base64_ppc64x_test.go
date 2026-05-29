// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (ppc64 || ppc64le) && !purego

package base64

import (
	"bytes"
	"testing"
)

func TestStdEncodeP9Asm(t *testing.T) {
	if !usePOWER9 {
		t.Skip("requires Power9")
	}
	pairs := []testpair{
		{"abcdefghijkl0000", "YWJjZGVmZ2hpamts"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed\x5a\xcc\x70\x90", "K/fMJwH+Q5e0nr7t"},
		{"abcdefghijklabcdefghijkl0000", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeP9Asm(dst, src, &encodeStdLut)
		if ret != len(expected) {
			t.Errorf("should return %v, got %v", len(expected), ret)
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func TestURLEncodeP9Asm(t *testing.T) {
	if !usePOWER9 {
		t.Skip("requires Power9")
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

		ret := encodeP9Asm(dst, src, &encodeURLLut)
		if ret != len(expected) {
			t.Errorf("should return %v", len(expected))
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %v", string(dst))
		}
	}
}

func TestStdDecodeP9Asm(t *testing.T) {
	if !usePOWER9 {
		t.Skip("requires Power9")
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

		ret := decodeStdP9Asm(dst, src)
		if ret == len(src) {
			t.Errorf("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func TestStdDecodeP9AsmWithError(t *testing.T) {
	if !usePOWER9 {
		t.Skip("requires Power9")
	}
	dst := make([]byte, 16)
	src := []byte("-YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts")
	ret := decodeStdP9Asm(dst, src)
	if ret != len(src) {
		t.Errorf("should return original length")
	}
}

func TestUrlDecodeP9Asm(t *testing.T) {
	if !usePOWER9 {
		t.Skip("requires Power9")
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

		ret := decodeUrlP9Asm(dst, src)
		if ret == len(src) {
			t.Errorf("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func TestUrlDecodeP9AsmWithError(t *testing.T) {
	if !usePOWER9 {
		t.Skip("requires Power9")
	}
	dst := make([]byte, 16)
	src := []byte("IT8kKiYoKSctPUB/IT8kKiYoKSctPUB/")
	ret := decodeUrlP9Asm(dst, src)
	if ret != len(src) {
		t.Errorf("should return original length")
	}
}
