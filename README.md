# base64
English | [简体中文](README-CN.md)

Base64 with SIMD acceleration

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64-qemu](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)

## Acknowledgements
This is an extension of [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64).

The amd64 (especially SSE version) / arm64 SIMD implementation are inspired by code from [aklomp/base64](https://github.com/aklomp/base64). 