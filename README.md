# base64
English | [简体中文](README-CN.md)

Base64 with SIMD acceleration

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64-qemu](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml)
[![Documentation](https://godoc.org/github.com/emmansun/base64?status.svg)](https://godoc.org/github.com/emmansun/base64)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)
[![Release](https://img.shields.io/github/release/emmansun/base64/all.svg)](https://github.com/emmansun/base64/releases)

## Acknowledgements
This is an extension of [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64).

The amd64 (especially SSE version) / arm64 SIMD implementation are inspired by code from [aklomp/base64](https://github.com/aklomp/base64). 