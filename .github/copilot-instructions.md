# Project Guidelines

## Code Style

- Keep the public API behavior aligned with Go's `encoding/base64`; this repository is a drop-in replacement, so behavior changes need strong justification.
- Match existing Go formatting and naming in the touched architecture file instead of normalizing across the repo.
- Keep changes narrow and architecture-local when possible; prefer updating the specific `base64_<arch>.*` pair and shared generic code only when behavior must change for all targets.

## Architecture

- `base64.go` contains the stdlib-compatible API surface and the generic encode/decode implementation.
- Architecture-specific dispatch lives in `base64_dispatch.go`, which drives the `encodeSimd`/`decodeSimd` hooks implemented in the per-architecture files (`base64_amd64.go`, `base64_arm64.go`, `base64_loong64.go`, `base64_ppc64x.go`, `base64_riscv64.go`, `base64_s390x.go`); assembly implementations live in the matching `.s` files.
- Optimized paths are selected at runtime from CPU feature flags and fall back to the generic implementation for unsupported CPUs or short inputs.
- Tests are split the same way as the implementation: generic behavior in `base64_test.go`, architecture-specific correctness in `base64_*_test.go`, and internal path benchmarks in `base64_*_bench_test.go`.

## Build and Test

- Use Go 1.25.x, matching `go.mod` and CI.
- Default verification: `go test ./...`
- Always run the generic fallback suite after changing optimized paths: `go test -tags purego ./...`
- Compare against the standard library with: `go test -run '^$' -bench '^BenchmarkCompare' -benchmem -count=5 ./...`
- For amd64 AVX512 work, also run the AVX512-focused tests or benchmarks when hardware or Intel SDE is available: `go test -v -run 'AVX512' ./...` and `go test -v -bench 'AVX512' -benchtime=1x -run '^$' ./...`

## Conventions

- Preserve architecture-specific threshold behavior such as minimum SIMD lengths and partial-prefix returns from assembly helpers.
- When changing SIMD logic, verify both direct assembly entry points and the higher-level dispatch path, because tests in this repo cover both.
- Keep benchmark changes separate from correctness changes unless the benchmark is required to validate a new dispatch mode or code path.
- If you change AVX512 multishift constants or operand ordering, treat the existing amd64 reference tests as mandatory and verify on real AVX512 hardware or Intel SDE before considering the change correct.
- Use `bench/README.md` as the source of truth for cross-machine benchmark reporting rather than inventing a new reporting format.