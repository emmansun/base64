//go:build amd64 && !purego
// +build amd64,!purego

package base64

import (
	"bytes"
	"testing"
)

func TestStdEncodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"abcdefghijkl0000", "YWJjZGVmZ2hpamts"},
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

func TestURLEncodeSIMD(t *testing.T) {
	pairs := []testpair{
		{"!?$*&()'-=@~0000", "IT8kKiYoKSctPUB-"},
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
