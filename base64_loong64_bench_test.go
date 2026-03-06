// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build loong64 && !purego

package base64

import (
	"fmt"
	"testing"
)

func benchmarkEncodeLoong64WithMode(b *testing.B, size int, lsxEnabled, lasxEnabled bool) {
	oldLSX, oldLASX := useLSX, useLASX
	useLSX, useLASX = lsxEnabled, lasxEnabled
	defer func() {
		useLSX, useLASX = oldLSX, oldLASX
	}()

	src := make([]byte, size)
	dst := make([]byte, StdEncoding.EncodedLen(size))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		StdEncoding.Encode(dst, src)
	}
}

func BenchmarkEncodeLoong64Generic(b *testing.B) {
	sizes := []int{16, 28, 40, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeLoong64WithMode(b, size, false, false)
		})
	}
}

func BenchmarkEncodeLoong64LSX(b *testing.B) {
	if !supportLSX {
		b.Skip("skip LSX benchmark: LSX not supported")
	}
	sizes := []int{16, 28, 40, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeLoong64WithMode(b, size, true, false)
		})
	}
}

func BenchmarkEncodeLoong64LASX(b *testing.B) {
	if !supportLASX {
		b.Skip("skip LASX benchmark: LASX not supported")
	}
	sizes := []int{16, 28, 40, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeLoong64WithMode(b, size, false, true)
		})
	}
}

func benchmarkDecodeLoong64WithMode(b *testing.B, size int, lsxEnabled, lasxEnabled bool) {
	oldLSX, oldLASX := useLSX, useLASX
	useLSX, useLASX = lsxEnabled, lasxEnabled
	defer func() {
		useLSX, useLASX = oldLSX, oldLASX
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

func BenchmarkDecodeLoong64Generic(b *testing.B) {
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeLoong64WithMode(b, size, false, false)
		})
	}
}

func BenchmarkDecodeLoong64LSX(b *testing.B) {
	if !supportLSX {
		b.Skip("skip LSX benchmark: LSX not supported")
	}
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeLoong64WithMode(b, size, true, false)
		})
	}
}

func BenchmarkDecodeLoong64LASX(b *testing.B) {
	if !supportLASX {
		b.Skip("skip LASX benchmark: LASX not supported")
	}
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeLoong64WithMode(b, size, false, true)
		})
	}
}
