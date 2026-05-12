// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build arm64 && !purego

package base64

import (
	"fmt"
	"testing"
)

func benchmarkDecodeARM64WithMode(b *testing.B, size int, stdNibble bool) {
	old := useStdNibbleDecode
	useStdNibbleDecode = stdNibble
	defer func() {
		useStdNibbleDecode = old
	}()

	raw := make([]byte, size)
	encoded := make([]byte, StdEncoding.EncodedLen(size))
	StdEncoding.Encode(encoded, raw)
	dst := make([]byte, StdEncoding.DecodedLen(len(encoded)))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := StdEncoding.Decode(dst, encoded); err != nil {
			b.Fatalf("decode failed: %v", err)
		}
	}
}

func benchmarkDecodeURLARM64WithMode(b *testing.B, size int, urlNibble bool) {
	old := useURLNibbleDecode
	useURLNibbleDecode = urlNibble
	defer func() {
		useURLNibbleDecode = old
	}()

	raw := make([]byte, size)
	encoded := make([]byte, URLEncoding.EncodedLen(size))
	URLEncoding.Encode(encoded, raw)
	dst := make([]byte, URLEncoding.DecodedLen(len(encoded)))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := URLEncoding.Decode(dst, encoded); err != nil {
			b.Fatalf("decode failed: %v", err)
		}
	}
}

func BenchmarkDecodeARM64Table(b *testing.B) {
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeARM64WithMode(b, size, false)
		})
	}
}

func BenchmarkDecodeARM64Nibble(b *testing.B) {
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeARM64WithMode(b, size, true)
		})
	}
}

func BenchmarkDecodeURLARM64Table(b *testing.B) {
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeURLARM64WithMode(b, size, false)
		})
	}
}

func BenchmarkDecodeURLARM64Nibble(b *testing.B) {
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeURLARM64WithMode(b, size, true)
		})
	}
}
