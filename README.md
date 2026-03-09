# base64
English | [简体中文](README-CN.md)

A drop-in replacement of Golang's base64 implementation with SIMD acceleration.

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

## Optimized architectures
- **AMD64** SSE/AVX2/AVX512 VBMI
- **ARM64** NEON
- **PPC64X**
- **S390X**
- **LOONG64** LSX/LASX
- **RISCV64** RVV

## Acknowledgements
This is an extension of [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64).

The amd64 (especially SSE version) / arm64 SIMD implementation are inspired by code from [aklomp/base64](https://github.com/aklomp/base64). 