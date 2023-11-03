# base64
[English](README.md) | 简体中文

使用SIMD指令加速的Base64实现。

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64-qemu](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci_qemu.yml)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)

## 致谢
本项目的大部分纯Go代码源自 [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64)，本包的使用和Go语言的base64完全相同。

AMD64架构的SIMD实现 (特别是SSE版本)算法源自 [aklomp/base64](https://github.com/aklomp/base64)。
