//go:build arm64 && !purego
// +build arm64,!purego

package base64

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
