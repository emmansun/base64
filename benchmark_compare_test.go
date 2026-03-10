// Copyright 2026 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

package base64

import (
	stdbase64 "encoding/base64"
	"fmt"
	"strings"
	"testing"
)

var compareBenchSizes = []int{16, 64, 256, 1024, 8192, 65536}

func makeBenchmarkInput(size int) []byte {
	buf := make([]byte, size)
	for i := range buf {
		buf[i] = byte((i*31 + 17) & 0xFF)
	}
	return buf
}

func insertCRLF76(src string) string {
	if len(src) <= 76 {
		return src
	}
	var b strings.Builder
	b.Grow(len(src) + len(src)/76*2)
	for len(src) > 76 {
		b.WriteString(src[:76])
		b.WriteString("\r\n")
		src = src[76:]
	}
	b.WriteString(src)
	return b.String()
}

func benchmarkCompareEncode(b *testing.B, size int, encode func(dst, src []byte)) {
	src := makeBenchmarkInput(size)
	dst := make([]byte, StdEncoding.EncodedLen(size))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		encode(dst, src)
	}
}

func benchmarkCompareDecode(b *testing.B, size int, withCRLF bool, decode func(dst, src []byte) (int, error)) {
	raw := makeBenchmarkInput(size)
	encoded := StdEncoding.EncodeToString(raw)
	if withCRLF {
		encoded = insertCRLF76(encoded)
	}
	src := []byte(encoded)
	dst := make([]byte, StdEncoding.DecodedLen(len(src)))

	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := decode(dst, src); err != nil {
			b.Fatalf("decode failed: %v", err)
		}
	}
}

func BenchmarkCompareEncode(b *testing.B) {
	for _, size := range compareBenchSizes {
		b.Run(fmt.Sprintf("repo/size-%d", size), func(b *testing.B) {
			benchmarkCompareEncode(b, size, StdEncoding.Encode)
		})
		b.Run(fmt.Sprintf("stdlib/size-%d", size), func(b *testing.B) {
			benchmarkCompareEncode(b, size, stdbase64.StdEncoding.Encode)
		})
	}
}

func BenchmarkCompareDecode(b *testing.B) {
	for _, size := range compareBenchSizes {
		b.Run(fmt.Sprintf("repo/size-%d", size), func(b *testing.B) {
			benchmarkCompareDecode(b, size, false, StdEncoding.Decode)
		})
		b.Run(fmt.Sprintf("stdlib/size-%d", size), func(b *testing.B) {
			benchmarkCompareDecode(b, size, false, stdbase64.StdEncoding.Decode)
		})
	}
}

func BenchmarkCompareDecodeCRLF(b *testing.B) {
	for _, size := range compareBenchSizes {
		b.Run(fmt.Sprintf("repo/size-%d", size), func(b *testing.B) {
			benchmarkCompareDecode(b, size, true, StdEncoding.Decode)
		})
		b.Run(fmt.Sprintf("stdlib/size-%d", size), func(b *testing.B) {
			benchmarkCompareDecode(b, size, true, stdbase64.StdEncoding.Decode)
		})
	}
}
