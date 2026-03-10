## Help wanted: performance testing on ARM64 / PPC64X / S390X / RISCV64 machines

Hi all,

I’m looking for help collecting real-world performance data for this repository on the following target architectures:

- ARM64
- PPC64X
- S390X
- RISCV64

This project already has SIMD implementations for multiple architectures, but I do not have broad enough access to representative hardware to evaluate performance across real target machines.

If you have access to a physical machine or a reliable VM on one of the architectures above, your benchmark results would be very helpful.

## What I need

I would like benchmark results for:

- encode throughput
- decode throughput
- decode throughput on CRLF-heavy base64 input

The main practical question is:

- how does this package compare to Go’s standard library `encoding/base64` on your machine?

## Benchmark command

Please run:

```bash
go test -run '^$' -bench '^BenchmarkCompare' -benchmem -count=5 ./...
```

This runs three benchmark groups:

- `BenchmarkCompareEncode`
- `BenchmarkCompareDecode`
- `BenchmarkCompareDecodeCRLF`

These benchmarks compare:

- this repository’s implementation
- Go standard library `encoding/base64`

The CRLF benchmark exists because newline-heavy input can behave differently from compact base64 text.

## Benchmark guide

There is also a short benchmark guide in the repository:

- `bench/README.md`

## What to include in your report

Please include as much of the following as possible:

- CPU model
- machine / board / VM information
- OS and kernel version
- Go version
- whether the machine is physical hardware or a VM
- notes about CPU governor / frequency scaling / turbo / SMT
- whether the benchmark was run on bare metal, inside a container, or inside a VM
- full benchmark output

Optional but useful:

```bash
go env
uname -a
lscpu
```

or equivalent platform-specific system information.

## Copy-paste report template

You can paste the following template directly into a comment:

See `bench/ISSUE_PERF_TESTING_COMMENT.md`.

## Optional extra data

Some architectures in this repository also have architecture-specific internal benchmarks. Those can be useful for maintainers, but they are optional.

For general cross-machine reporting, the `BenchmarkCompare*` results are the most useful because they directly show how this package behaves relative to the Go standard library on your hardware.

## Why this matters

These results will help answer questions like:

- which architectures currently benefit the most
- how performance scales with payload size
- whether decode behavior changes significantly for CRLF-heavy input
- where future optimization work is most worthwhile

Thanks in advance to anyone willing to help with testing.