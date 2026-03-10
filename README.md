# base64
English | [简体中文](README-CN.md)

A SIMD-accelerated drop-in replacement for Go's `encoding/base64`.

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64](https://github.com/emmansun/base64/actions/workflows/arm64_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/arm64_qemu.yml)
[![ppc64le](https://github.com/emmansun/base64/actions/workflows/ppc64le_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ppc64le_qemu.yml)
[![s390x](https://github.com/emmansun/base64/actions/workflows/s390x_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/s390x_qemu.yml)
[![loong64](https://github.com/emmansun/base64/actions/workflows/loong64_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/loong64_qemu.yml)
[![riscv64](https://github.com/emmansun/base64/actions/workflows/riscv64_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/riscv64_qemu.yml)
[![codecov](https://codecov.io/gh/emmansun/base64/graph/badge.svg?token=LNNXNW4T5F)](https://codecov.io/gh/emmansun/base64)
[![Go Report Card](https://goreportcard.com/badge/github.com/emmansun/base64)](https://goreportcard.com/report/github.com/emmansun/base64)
[![Documentation](https://godoc.org/github.com/emmansun/base64?status.svg)](https://godoc.org/github.com/emmansun/base64)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)
[![Release](https://img.shields.io/github/release/emmansun/base64/all.svg)](https://github.com/emmansun/base64/releases)

## Overview

This package keeps the same public API and behavior as Go's standard `encoding/base64`, while using architecture-specific SIMD implementations where available.

- Compatible with `StdEncoding`, `URLEncoding`, `RawStdEncoding`, `RawURLEncoding`, `NewEncoding`, `WithPadding`, `Strict`, stream encoder/decoder, and append helpers.
- Uses runtime CPU feature detection on supported platforms.
- Falls back to the generic Go implementation when SIMD is unavailable or the input is too small for the optimized path.

## Supported Architectures

| Architecture | SIMD path |
|---|---|
| AMD64 | SSE, AVX2, AVX512 VBMI |
| ARM64 | NEON |
| PPC64X | VSX / VMX (AltiVec) |
| S390X | Vector Facility |
| LOONG64 | LSX, LASX |
| RISCV64 | RVV |

The concrete path is selected automatically at runtime based on CPU features.

## Installation

```bash
go get github.com/emmansun/base64
```

## Usage

Import this package instead of `encoding/base64`:

```go
package main

import (
	"fmt"

	"github.com/emmansun/base64"
)

func main() {
	src := []byte("hello, world")

	enc := base64.StdEncoding.EncodeToString(src)
	dec, err := base64.StdEncoding.DecodeString(enc)
	if err != nil {
		panic(err)
	}

	fmt.Println(enc)
	fmt.Println(string(dec))
}
```

Because the exported API follows the standard library, existing code usually only needs an import path change.

## Behavior Notes

- Encoding and decoding semantics follow RFC 4648, matching Go's standard library behavior.
- Strict decoding is supported through `Encoding.Strict()`.
- Raw encodings without padding are supported through `RawStdEncoding`, `RawURLEncoding`, or `WithPadding(base64.NoPadding)`.
- Inputs containing `\r` or `\n` are handled the same way as the standard library, but decode throughput may not improve for newline-heavy data.

## Performance

Performance depends on CPU model, microarchitecture, input size, encoding variant, and input shape. This repository does not publish a single benchmark table because numbers are hardware-dependent.

If performance matters for your workload, run benchmarks on your target machines.

## Project Status

- The package is tested in CI across the architectures covered by this repository.
- AMD64 AVX512 VBMI coverage is also validated with Intel SDE in CI.

## Acknowledgements

Most of the generic Go implementation is derived from [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64).

The amd64 implementation, especially the SSE path, and the arm64 SIMD implementation were inspired by [aklomp/base64](https://github.com/aklomp/base64).