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