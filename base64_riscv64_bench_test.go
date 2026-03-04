// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build riscv64 && !purego

package base64

import (
	"fmt"
	"testing"

	"golang.org/x/sys/cpu"
)

func benchmarkEncodeWithMode(b *testing.B, size int, useRVV bool) {
	old := supportRVV
	supportRVV = useRVV
	defer func() { supportRVV = old }()

	src := make([]byte, size)
	dst := make([]byte, StdEncoding.EncodedLen(size))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		StdEncoding.Encode(dst, src)
	}
}

func BenchmarkEncodeRISCV64Generic(b *testing.B) {
	sizes := []int{16, 28, 40, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeWithMode(b, size, false)
		})
	}
}

func BenchmarkEncodeRISCV64RVV(b *testing.B) {
	if !cpu.RISCV64.HasV {
		b.Skip("skip RVV benchmark: RVV not supported")
	}
	sizes := []int{16, 28, 40, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkEncodeWithMode(b, size, true)
		})
	}
}

func benchmarkDecodeWithMode(b *testing.B, size int, useRVV bool) {
	old := supportRVV
	supportRVV = useRVV
	defer func() { supportRVV = old }()

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

func BenchmarkDecodeRISCV64Generic(b *testing.B) {
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeWithMode(b, size, false)
		})
	}
}

func BenchmarkDecodeRISCV64RVV(b *testing.B) {
	if !cpu.RISCV64.HasV {
		b.Skip("skip RVV benchmark: RVV not supported")
	}
	sizes := []int{24, 40, 56, 128, 256, 512, 1024, 2048, 4096, 8192}
	for _, size := range sizes {
		b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
			benchmarkDecodeWithMode(b, size, true)
		})
	}
}
