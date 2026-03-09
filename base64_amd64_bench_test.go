// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build amd64 && !purego

package base64

import (
	"fmt"
	"testing"
)

func benchmarkEncodeAMD64WithMode(b *testing.B, size int, avx512Enabled, avx2Enabled bool) {
	oldAVX512, oldAVX2 := useAVX512VBMI, useAVX2
	useAVX512VBMI, useAVX2 = avx512Enabled, avx2Enabled
	defer func() {
		useAVX512VBMI, useAVX2 = oldAVX512, oldAVX2
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

func BenchmarkEncodeAMD64Generic(b *testing.B) {
	sizes := []int{16, 48, 96, 128, 256, 512, 1024, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeAMD64WithMode(b, size, false, false)
		})
	}
}

func BenchmarkEncodeAMD64AVX2(b *testing.B) {
	if !useAVX2 {
		b.Skip("skip AVX2 encode benchmark: AVX2 not supported")
	}
	sizes := []int{16, 48, 96, 128, 256, 512, 1024, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeAMD64WithMode(b, size, false, true)
		})
	}
}

func BenchmarkEncodeAMD64AVX512(b *testing.B) {
	if !useAVX512VBMI {
		b.Skip("skip AVX512 VBMI encode benchmark: AVX512 VBMI not supported")
	}
	sizes := []int{16, 48, 96, 128, 256, 512, 1024, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeAMD64WithMode(b, size, true, false)
		})
	}
}

func benchmarkDecodeAMD64WithMode(b *testing.B, size int, avx512Enabled, avx2Enabled bool) {
	oldAVX512, oldAVX2 := useAVX512VBMI, useAVX2
	useAVX512VBMI, useAVX2 = avx512Enabled, avx2Enabled
	defer func() {
		useAVX512VBMI, useAVX2 = oldAVX512, oldAVX2
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

func BenchmarkDecodeAMD64Generic(b *testing.B) {
	sizes := []int{24, 48, 96, 128, 256, 512, 1024, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeAMD64WithMode(b, size, false, false)
		})
	}
}

func BenchmarkDecodeAMD64AVX2(b *testing.B) {
	if !useAVX2 {
		b.Skip("skip AVX2 decode benchmark: AVX2 not supported")
	}
	sizes := []int{24, 48, 96, 128, 256, 512, 1024, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeAMD64WithMode(b, size, false, true)
		})
	}
}

func BenchmarkDecodeAMD64AVX512(b *testing.B) {
	if !useAVX512VBMI {
		b.Skip("skip AVX512 VBMI decode benchmark: AVX512 VBMI not supported")
	}
	sizes := []int{24, 48, 96, 128, 256, 512, 1024, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeAMD64WithMode(b, size, true, false)
		})
	}
}
