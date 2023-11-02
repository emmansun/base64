# base64
Base64 with SIMD acceleration

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)

## Acknowledgements
The basic architecture, design and some codes are from [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64).

The amd64 SIMD implementation (especially SSE version) is inspired by code from [aklomp/base64](https://github.com/aklomp/base64). 