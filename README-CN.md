# base64
[English](README.md) | 简体中文

使用SIMD指令加速的Base64实现。

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64-qemu](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml)
[![Documentation](https://godoc.org/github.com/emmansun/base64?status.svg)](https://godoc.org/github.com/emmansun/base64)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)
[![Release](https://img.shields.io/github/release/emmansun/base64/all.svg)](https://github.com/emmansun/base64/releases)

## 致谢
本项目的大部分纯Go代码源自 [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64)，本包的使用和Go语言的base64完全相同。

AMD64架构(特别是SSE版本)和ARM64架构的SIMD实现算法源自 [aklomp/base64](https://github.com/aklomp/base64)。
