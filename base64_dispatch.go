// Copyright 2024 Sun Yimin. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause-style
// license that can be found in the LICENSE file.

//go:build (amd64 || arm64 || ppc64 || ppc64le || s390x || loong64 || riscv64) && !purego

package base64

// The SIMD-capable architectures provide two hooks, implemented in their
// per-architecture files:
//
//	encodeSimd encodes the leading part of src into dst using enc's alphabet,
//	returning the number of encoded bytes (0 if no fast path is available).
//
//	decodeSimd decodes the leading part of src into dst for the standard or
//	URL-safe alphabet, returning the number of undecoded trailing source
//	bytes (len(src) if no fast path is available).
//
// Both hooks must leave the tail of the input untouched; the generic code
// below processes the remainder and keeps error offsets consistent.

// encode drives the per-architecture SIMD encoder.
func encode(enc *Encoding, dst, src []byte) {
	if len(src) >= 16 {
		if encoded := encodeSimd(enc, dst, src); encoded > 0 {
			src = src[(encoded/4)*3:]
			dst = dst[encoded:]
		}
	}
	encodeGeneric(enc, dst, src)
}

// decode drives the per-architecture SIMD decoder.
func decode(enc *Encoding, dst, src []byte) (int, error) {
	srcLen := len(src)
	if srcLen >= 24 {
		remain := decodeSimd(enc, dst, src)
		if remain < srcLen {
			// decoded by SIMD
			remain = srcLen - remain // remain is decoded length now
			src = src[remain:]
			dstStart := (remain / 4) * 3
			dst = dst[dstStart:]
			n, err := decodeGeneric(enc, dst, src)
			if cerr, ok := err.(CorruptInputError); ok {
				return n + dstStart, CorruptInputError(int(cerr) + remain)
			}
			return n + dstStart, err
		}
	}
	return decodeGeneric(enc, dst, src)
}
