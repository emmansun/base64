# Benchmark Guide

This directory contains notes for contributors who want to run performance tests on real target machines.

## Quick Start

Run the repository-vs-stdlib comparison benchmarks:

```bash
go test -run '^$' -bench '^BenchmarkCompare' -benchmem -count=5 ./...
```

This runs three benchmark groups:

- `BenchmarkCompareEncode`: this package vs `encoding/base64` for encoding
- `BenchmarkCompareDecode`: this package vs `encoding/base64` for decoding
- `BenchmarkCompareDecodeCRLF`: decode benchmark with CRLF inserted every 76 chars

## What To Report

Please include:

- CPU model
- OS and kernel version
- Go version
- Output of the benchmark command above
- Any notes about CPU frequency scaling, SMT, containers, or virtualization

## Issue Comment Template

Contributors can copy and paste the template below into a GitHub issue comment:

````markdown
## Benchmark Report

- Architecture:
- CPU:
- Machine / board / VM:
- OS:
- Kernel:
- Go version:
- Physical machine or VM:
- Governor / frequency notes:
- Containerized or bare metal:

### Commands

```bash
go test -run '^$' -bench '^BenchmarkCompare' -benchmem -count=5 ./...
```

Optional system info:

```bash
go env
uname -a
lscpu
```

### Benchmark Output

```text
paste benchmark output here
```

### Notes

- Anything unusual about the machine setup
- Whether results were stable across repeated runs
- Any suspected throttling / SMT / virtualization effects
- Any observations about CRLF-heavy decode workloads
````

## Optional Architecture-Specific Benchmarks

Some architectures also have internal-path benchmarks in the root package, for example:

- amd64: generic vs AVX2 vs AVX512 VBMI
- loong64: generic vs LSX vs LASX
- riscv64: generic vs RVV

Those are mainly useful when the runtime path can be toggled inside tests. For cross-machine comparisons, prefer `BenchmarkCompare*`.