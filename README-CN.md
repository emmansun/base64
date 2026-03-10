# base64
[English](README.md) | 简体中文

一个使用 SIMD 加速、并尽量保持与 Go 标准库 `encoding/base64` 一致接口和行为的 Base64 实现。

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

## 项目说明

这个包保留了标准库 `encoding/base64` 的主要公开 API，同时在支持的架构上通过 SIMD 实现更快的编码和解码路径。

- 兼容 `StdEncoding`、`URLEncoding`、`RawStdEncoding`、`RawURLEncoding`
- 支持 `NewEncoding`、`WithPadding`、`Strict`
- 支持流式编码/解码和 append 系列接口
- 在支持的平台上做运行时 CPU 特性检测，不满足条件时自动回退到纯 Go 实现

## 已支持的架构

| 架构 | SIMD 路径 |
|---|---|
| AMD64 | SSE、AVX2、AVX512 VBMI |
| ARM64 | NEON |
| PPC64X | VSX / VMX (AltiVec) |
| S390X | Vector Facility |
| LOONG64 | LSX、LASX |
| RISCV64 | RVV |

具体使用哪条路径由运行时根据 CPU 特性自动选择。

## 安装

```bash
go get github.com/emmansun/base64
```

## 使用方式

把导入路径从标准库换成这个包即可，大多数场景下不需要修改业务代码：

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

## 行为说明

- 编码和解码语义遵循 RFC 4648，并与 Go 标准库保持一致
- 严格模式可通过 `Encoding.Strict()` 启用
- 无填充模式可通过 `RawStdEncoding`、`RawURLEncoding` 或 `WithPadding(base64.NoPadding)` 使用
- 输入中包含 `\r` 或 `\n` 时，行为与标准库一致，但这类数据的解码吞吐通常没有明显优势

## 性能说明

性能会受到 CPU 型号、微架构、输入长度、编码类型以及输入数据形态的影响，因此这里不提供一个固定的 benchmark 表。

如果你关心真实收益，建议直接在目标机器上对自己的数据做基准测试。

## 项目状态

- 仓库中的 CI 覆盖了当前实现涉及的多种架构
- AMD64 的 AVX512 VBMI 路径也通过 Intel SDE 做了额外验证

## 致谢

本项目的大部分纯 Go 实现源自 [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64)。

AMD64 架构，尤其是 SSE 路径，以及 ARM64 架构的 SIMD 实现参考了 [aklomp/base64](https://github.com/aklomp/base64)。
