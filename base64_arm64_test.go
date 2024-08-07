//go:build arm64 && !purego

package base64

import (
	"bytes"
	"testing"
)

func TestStdEncodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeAsm(dst, src, &StdEncoding.encode)
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
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamt="},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamts"},
	}
	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := decodeAsm(dst, src, &dencodeStdLut)
		if ret == len(src) {
			t.Fatal("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Fatalf("got %x, expected %x", dst, expected)
		}
	}
}

func TestUrlEncodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	for _, p := range pairs {
		src := []byte(p.decoded)
		expected := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := encodeAsm(dst, src, &URLEncoding.encode)
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
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
		{"abcdefghijklabcdefghijklabcdefghijklabcdefghijkl", "YWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamtsYWJjZGVmZ2hpamt="},
		{"!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~!?$*&()'-=@~", "IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-IT8kKiYoKSctPUB-"},
	}
	for _, p := range pairs {
		expected := []byte(p.decoded)
		src := []byte(p.encoded)
		dst := make([]byte, len(expected))

		ret := decodeAsm(dst, src, &dencodeUrlLut)
		if ret == len(src) {
			t.Fatal("should return decode")
		}
		if !bytes.Equal(dst, expected) {
			t.Fatalf("got %x, expected %x", dst, expected)
		}
	}
}
