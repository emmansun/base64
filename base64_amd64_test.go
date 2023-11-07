//go:build amd64 && !purego

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
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeSIMD(dst, src, &encodeStdLut)
		if ret != len(expected) {
			t.Fatalf("should return %v", len(expected))
		}
		if !bytes.Equal(dst, expected) {
			t.Fatalf("got %v", string(dst))
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
			t.Fatal("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Fatalf("got %x, expected %x", dst, expected)
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
			t.Fatalf("should return %v", len(expected))
		}
		if !bytes.Equal(dst, expected) {
			t.Fatalf("got %v", string(dst))
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
			t.Fatal("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Fatalf("got %x, expected %x", dst, expected)
		}
	}
}
