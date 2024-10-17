// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (amd64 || ppc64 || ppc64le) && !purego

package base64

import (
	"bytes"
	"testing"
)

func TestStdEncodeSIMD(t *testing.T) {
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

		ret := encodeSIMD(dst, src, &encodeStdLut)
		if ret != len(expected) {
			t.Errorf("should return %v, got %v", len(expected), ret)
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}

	}
}

func TestStdDecodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"abcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed", "K/fMJwH+Q5e0nr7tK/fMJwH+Q5e0nr7t"},
		{"abcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := decodeStdSIMD(dst, src)
		if ret == len(src) {
			t.Errorf("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func TestURLEncodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"!?$*&()'-=@~0000", "IT8kKiYoKSctPUB-"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed\x5a\xcc\x70\x90", "K_fMJwH-Q5e0nr7t"},
		{"!?$*&()'-=@~!?$*&()'-=@~0000", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeSIMD(dst, src, &encodeURLLut)
		if ret != len(expected) {
			t.Errorf("should return %v", len(expected))
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %v", string(dst))
		}

	}
}

func TestUrlDecodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
		{"\x2b\xf7\xcc\x27\x01\xfe\x43\x97\xb4\x9e\xbe\xed", "K_fMJwH-Q5e0nr7tK_fMJwH-Q5e0nr7t"},
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := decodeUrlSIMD(dst, src)
		if ret == len(src) {
			t.Errorf("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Errorf("got %x, expected %x", dst, expected)
		}
	}
}

func BenchmarkEncode(b *testing.B) {
	data := make([]byte, 8192)
	dst := make([]byte, StdEncoding.EncodedLen(8192))
	b.SetBytes(int64(len(data)))
	for i := 0; i < b.N; i++ {
		StdEncoding.Encode(dst, data)
	}
}

func BenchmarkDecode(b *testing.B) {
	data := []byte(StdEncoding.EncodeToString(make([]byte, 8192)))
	dbuf := make([]byte, StdEncoding.DecodedLen(len(data)))
	b.SetBytes(int64(len(data)))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		StdEncoding.Decode(dbuf, data)
	}
}
