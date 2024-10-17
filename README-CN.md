# base64
[English](README.md) | 简体中文

使用SIMD指令加速的Base64实现。

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64](https://github.com/emmansun/base64/actions/workflows/arm64_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/arm64_qemu.yml)
[![ppc64le](https://github.com/emmansun/base64/actions/workflows/ppc64le_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ppc64le_qemu.yml)
[![s390x](https://github.com/emmansun/base64/actions/workflows/s390x_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/s390x_qemu.yml)
[![Documentation](https://godoc.org/github.com/emmansun/base64?status.svg)](https://godoc.org/github.com/emmansun/base64)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)
[![Release](https://img.shields.io/github/release/emmansun/base64/all.svg)](https://github.com/emmansun/base64/releases)


## 优化的架构
- **AMD64** SSE/AVX/AVX2
- **ARM64** NEON
- **PPC64X**
- **S390X**

## 性能
关于性能，AMD64下的性能可以参考[English](README.md) 说明，ARM64下的性能请自行测试。另外需要说明的是，解码的时候，如果文本含有回车换行，当前实现没有优势。

本库已经在生产环境运行多时。

## 致谢
本项目的大部分纯Go代码源自 [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64)，本包的使用和Go语言的base64完全相同。

AMD64架构(特别是SSE版本)和ARM64架构的SIMD实现算法源自 [aklomp/base64](https://github.com/aklomp/base64)。
