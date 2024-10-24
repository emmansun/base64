# base64
English | [简体中文](README-CN.md)

Base64 with SIMD acceleration

[![ci](https://github.com/emmansun/base64/actions/workflows/ci.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ci.yml)
[![arm64](https://github.com/emmansun/base64/actions/workflows/arm64_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/arm64_qemu.yml)
[![ppc64le](https://github.com/emmansun/base64/actions/workflows/ppc64le_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/ppc64le_qemu.yml)
[![s390x](https://github.com/emmansun/base64/actions/workflows/s390x_qemu.yml/badge.svg)](https://github.com/emmansun/base64/actions/workflows/s390x_qemu.yml)
[![codecov](https://codecov.io/gh/emmansun/base64/graph/badge.svg?token=LNNXNW4T5F)](https://codecov.io/gh/emmansun/base64)
[![Go Report Card](https://goreportcard.com/badge/github.com/emmansun/base64)](https://goreportcard.com/report/github.com/emmansun/base64)
[![Documentation](https://godoc.org/github.com/emmansun/base64?status.svg)](https://godoc.org/github.com/emmansun/base64)
![GitHub go.mod Go version (branch)](https://img.shields.io/github/go-mod/go-version/emmansun/base64)
[![Release](https://img.shields.io/github/release/emmansun/base64/all.svg)](https://github.com/emmansun/base64/releases)

## Optimized architectures
- **AMD64** SSE/AVX/AVX2
- **ARM64** NEON
- **PPC64X**
- **S390X**

## Benchmark
**SDK vs. Purego**:
```
goos: windows
goarch: amd64
pkg: github.com/emmansun/base64
cpu: Intel(R) Core(TM) i5-9500 CPU @ 3.00GHz
                    │   sdk.txt    │             purego.txt              │
                    │    sec/op    │   sec/op     vs base                │
EncodeToString-6      11.774µ ± 2%   9.267µ ± 1%  -21.29% (p=0.000 n=10)
DecodeString/2-6       31.80n ± 0%   28.63n ± 1%   -9.97% (p=0.000 n=10)
DecodeString/4-6       35.00n ± 1%   32.89n ± 2%   -6.02% (p=0.000 n=10)
DecodeString/8-6       41.85n ± 1%   39.97n ± 2%   -4.48% (p=0.000 n=10)
DecodeString/64-6      154.7n ± 1%   112.0n ± 2%  -27.61% (p=0.000 n=10)
DecodeString/8192-6   12.630µ ± 1%   9.836µ ± 1%  -22.12% (p=0.000 n=10)
geomean                319.9n        269.6n       -15.71%

                    │   sdk.txt    │              purego.txt               │
                    │     B/s      │      B/s       vs base                │
EncodeToString-6      663.6Mi ± 2%    843.1Mi ± 1%  +27.05% (p=0.000 n=10)
DecodeString/2-6      120.0Mi ± 0%    133.2Mi ± 1%  +11.06% (p=0.000 n=10)
DecodeString/4-6      218.0Mi ± 1%    232.0Mi ± 2%   +6.39% (p=0.000 n=10)
DecodeString/8-6      273.5Mi ± 1%    286.3Mi ± 2%   +4.69% (p=0.000 n=10)
DecodeString/64-6     542.8Mi ± 1%    749.7Mi ± 2%  +38.12% (p=0.000 n=10)
DecodeString/8192-6   824.8Mi ± 1%   1059.2Mi ± 1%  +28.41% (p=0.000 n=10)
geomean               358.6Mi         425.4Mi       +18.63%
```
**Purego vs. AVX**:
```
goos: windows
goarch: amd64
pkg: github.com/emmansun/base64
cpu: Intel(R) Core(TM) i5-9500 CPU @ 3.00GHz
                    │  purego.txt  │               avx.txt               │
                    │    sec/op    │   sec/op     vs base                │
EncodeToString-6       9.267µ ± 1%   3.201µ ± 2%  -65.46% (p=0.000 n=10)
DecodeString/2-6       28.63n ± 1%   27.95n ± 1%   -2.38% (p=0.000 n=10)
DecodeString/4-6       32.89n ± 2%   32.34n ± 1%   -1.67% (p=0.041 n=10)
DecodeString/8-6       39.97n ± 2%   39.12n ± 0%   -2.14% (p=0.000 n=10)
DecodeString/64-6     111.95n ± 2%   69.97n ± 2%  -37.50% (p=0.000 n=10)
DecodeString/8192-6    9.836µ ± 1%   3.227µ ± 2%  -67.20% (p=0.000 n=10)
Encode-6                             1.003µ ± 1%
Decode-6                             1.547µ ± 4%
geomean                269.6n        281.7n       -36.35%

                    │  purego.txt  │                avx.txt                 │
                    │     B/s      │      B/s       vs base                 │
EncodeToString-6      843.1Mi ± 1%   2441.1Mi ± 2%  +189.54% (p=0.000 n=10)
DecodeString/2-6      133.2Mi ± 1%    136.5Mi ± 1%    +2.44% (p=0.000 n=10)
DecodeString/4-6      232.0Mi ± 2%    235.9Mi ± 1%    +1.70% (p=0.045 n=10)
DecodeString/8-6      286.3Mi ± 2%    292.6Mi ± 0%    +2.20% (p=0.000 n=10)
DecodeString/64-6     749.7Mi ± 2%   1199.5Mi ± 2%   +60.00% (p=0.000 n=10)
DecodeString/8192-6   1.034Gi ± 1%    3.153Gi ± 2%  +204.83% (p=0.000 n=10)
Encode-6                              7.612Gi ± 1%
Decode-6                              6.578Gi ± 3%
geomean               425.4Mi         1.184Gi        +57.10%
```

**AVX vs. AVX2**:
```
goos: windows
goarch: amd64
pkg: github.com/emmansun/base64
cpu: Intel(R) Core(TM) i5-9500 CPU @ 3.00GHz
                    │   avx.txt    │              avx2.txt               │
                    │    sec/op    │   sec/op     vs base                │
Encode-6              1002.5n ± 1%   495.1n ± 1%  -50.62% (p=0.000 n=10)
Decode-6              1546.5n ± 4%   640.7n ± 1%  -58.57% (p=0.000 n=10)
EncodeToString-6       3.201µ ± 2%   2.683µ ± 5%  -16.18% (p=0.000 n=10)
DecodeString/2-6       27.95n ± 1%   27.82n ± 1%        ~ (p=0.289 n=10)
DecodeString/4-6       32.34n ± 1%   32.28n ± 1%        ~ (p=0.494 n=10)
DecodeString/8-6       39.12n ± 0%   39.45n ± 1%   +0.84% (p=0.034 n=10)
DecodeString/64-6      69.97n ± 2%   67.69n ± 1%   -3.24% (p=0.000 n=10)
DecodeString/8192-6    3.227µ ± 2%   2.187µ ± 3%  -32.23% (p=0.000 n=10)
geomean                281.7n        214.4n       -23.89%

                    │   avx.txt    │                avx2.txt                │
                    │     B/s      │      B/s       vs base                 │
Encode-6              7.612Gi ± 1%   15.412Gi ± 1%  +102.46% (p=0.000 n=10)
Decode-6              6.578Gi ± 3%   15.878Gi ± 1%  +141.37% (p=0.000 n=10)
EncodeToString-6      2.384Gi ± 2%    2.844Gi ± 5%   +19.31% (p=0.000 n=10)
DecodeString/2-6      136.5Mi ± 1%    137.1Mi ± 1%         ~ (p=0.315 n=10)
DecodeString/4-6      235.9Mi ± 1%    236.4Mi ± 1%         ~ (p=0.529 n=10)
DecodeString/8-6      292.6Mi ± 0%    290.1Mi ± 1%    -0.84% (p=0.035 n=10)
DecodeString/64-6     1.171Gi ± 2%    1.211Gi ± 1%    +3.35% (p=0.000 n=10)
DecodeString/8192-6   3.153Gi ± 2%    4.653Gi ± 3%   +47.58% (p=0.000 n=10)
geomean               1.184Gi         1.556Gi        +31.38%
```
## Acknowledgements
This is an extension of [golang base64](https://github.com/golang/go/tree/master/src/encoding/base64).

The amd64 (especially SSE version) / arm64 SIMD implementation are inspired by code from [aklomp/base64](https://github.com/aklomp/base64). 