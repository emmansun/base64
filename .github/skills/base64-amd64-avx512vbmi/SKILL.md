---
name: base64-amd64-avx512vbmi
description: "实现 amd64 架构下 AVX512 VBMI 加速的 BASE64 编解码 Go 汇编代码。Use when: 在 amd64 平台扩展 base64 的 AVX512 实现、编写 EVEX-512 汇编、使用 VPERMB/VPERMI2B/VPMULTISHIFTQB 实现高效编解码、amd64 Go assembly AVX512 SIMD optimization。"
argument-hint: "encode 或 decode，或留空处理完整实现"
---

# AMD64 AVX512 VBMI BASE64 实现技能

## 适用场景

- 在现有 `base64_amd64.s` 中新增 AVX512 VBMI（512-bit）编解码路径
- 利用 VPERMB / VPERMI2B / VPMULTISHIFTQB 指令实现比 AVX2 更简洁高效的算法
- 调试 AVX512 汇编逻辑（本地无 AVX512，需远程验证）

## 设计决策

### 1. 仅实现 AVX512 VBMI 路径

不实现 AVX512F+BW-only（无 VBMI）路径。理由：
- VPERMB / VPERMI2B 是算法的关键突破，没有 VBMI 则算法退化为"更宽的 AVX2"，收益有限
- AVX2 已能高效处理 32 字节/轮，对于无 VBMI 的 CPU（Skylake-X、Zen 4）已足够
- 减少代码复杂度和维护负担

**CPU 检测条件：**
```go
cpu.X86.HasAVX512F && cpu.X86.HasAVX512BW && cpu.X86.HasAVX512VBMI
```

**扩展要求补充：**
- 512-bit `VPERMB` / `VPERMI2B` / `VPMULTISHIFTQB` 路径的关键特性位是 `AVX512VBMI`
- 保持现有工程门控：`AVX512F + AVX512BW + AVX512VBMI`。这样与当前 ZMM 字节/字操作、现有 fallback 逻辑和测试假设一致
- 如果未来实现 128-bit / 256-bit `VPMULTISHIFTQB` 变体，则额外需要 `AVX512VL`

**支持的 CPU 覆盖：**
| CPU 系列 | AVX512F | AVX512BW | AVX512VBMI | 命中路径 |
|---|---|---|---|---|
| Ice Lake / Tiger Lake / Alder Lake-P | ✅ | ✅ | ✅ | **AVX512** |
| Rocket Lake | ✅ | ✅ | ✅ | **AVX512** |
| Zen 5 | ✅ | ✅ | ✅ | **AVX512** |
| Zen 4 EPYC (Genoa / Bergamo) | ✅ | ✅ | ✅ | **AVX512** |
| Skylake-X / Cascade Lake | ✅ | ✅ | ❌ | AVX2 |
| Haswell ~ Coffee Lake | ❌ | ❌ | ❌ | AVX2 |
| Sandy/Ivy Bridge | ❌ | ❌ | ❌ | SSE3（或 AVX，见决策 2）|

**更正：** 先前把 `Zen 4` 写成“无 VBMI”是不准确的。至少 `simdenc` 在 AMD EPYC Zen 4 上的公开研究明确记录了 `AVX-512F, DQ, CD, BW, VL, IFMA, VBMI, VBMI2, VNNI, BITALG, VPOPCNTDQ, BF16`。因此对于服务器端 Zen 4（EPYC Genoa / Bergamo 一类），应视为支持 `AVX512VBMI`。

**补充说明：** 不同产品线/BIOS/虚拟化环境是否暴露 AVX512 可能不同，但对本 skill 而言，CPU 能力判断应以运行时 CPUID 结果为准，而不是把 `Zen 4` 笼统归为“无 VBMI”。

### 2. 移除 AVX（无 AVX2）路径，保留 SSE3 和 AVX2

**理由：**
- AVX-only（无 AVX2）的 CPU 仅存在于 Sandy Bridge / Ivy Bridge 时代（2011–2012），已极为罕见
- AVX 路径与 SSE3 算法相同，仅使用 VEX 编码（3 操作数非破坏性），性能差异极小
- 移除后减少约 100+ 行汇编代码，降低维护成本

**移除范围：**
- `base64_asm.go` 中删除 `var useAVX = cpu.X86.HasAVX`
- `base64_amd64.s` 中删除 `encodeAsm` 的 `avx`/`avx_loop`/`avx_done` 分支
- `base64_amd64.s` 中删除 `decodeStdAsm`/`decodeUrlAsm` 的 `avx`/`avx_loop`/`avx_done` 分支
- 删除 AVX_ENC / AVX_DECODE_VALIDATE / AVX_DECODE_RESHUFFLE 宏定义

**保留路径（移除 AVX 后）：**
```
encodeAsm / decodeStdAsm / decodeUrlAsm 内部 dispatch:
  useAVX512VBMI → avx512 路径（新增）
  useAVX2       → avx2 路径（保留）
  fallthrough   → SSE3 路径（保留）
```

### 3. 复用现有函数签名

**不新增 Go 函数**，直接在现有汇编函数内部增加 AVX512 分支：
```asm
TEXT ·encodeAsm(SB),NOSPLIT,$0
    // 先检查输入长度，避免输入不足时白白加载 ZMM 常量
    CMPQ CX, $64
    JB   enc_not_avx512
    CMPB ·useAVX512VBMI(SB), $1
    JE   avx512
enc_not_avx512:
    CMPB ·useAVX2(SB), $1
    JE   avx2
    // SSE3 fallback ...
```

好处：
- Go 层 `base64_asm.go` 的 `encode()` / `decode()` 完全不需要修改
- 与 loong64 的 LSX/LASX 分支模式一致
- 测试自动覆盖所有路径
- **输入长度预检**：当 `CX < 64` 时直接跳过 AVX512 检查，避免加载无用的 ZMM 常量（每个函数各有独立 label：`enc_not_avx512`、`stddec_not_avx512`、`urldec_not_avx512`）

### 4. Go 层变量设计

在 `base64_asm.go` 中新增：
```go
var useAVX512VBMI = cpu.X86.HasAVX512F && cpu.X86.HasAVX512BW && cpu.X86.HasAVX512VBMI
```

删除：
```go
var useAVX = cpu.X86.HasAVX  // 移除
```

## 环境约束

| 环境 | 用途 | AVX512 支持 |
|------|------|------------|
| 本地开发 | 交叉编译、语法检查 | ❌ 不支持 |
| GitHub Actions `ci.yml` | 原生 amd64 测试 | ⚠️ 待确认（需在 CI 中检测） |
| 远程 AVX512 机器 | 运行时验证 | ✅ 需要 Ice Lake 或更新 |

**关键区别：** 与 loong64 不同，amd64 CI 可能直接在原生 x86-64 上跑。需在测试中检测 AVX512 是否可用：
```go
func TestAVX512Encode(t *testing.T) {
    if !useAVX512VBMI {
        t.Skip("AVX512 VBMI not supported")
    }
    // ...
}
```

**如果 GitHub Actions 不支持 AVX512：**
- 方案 A（已实现）：添加 `t.Skip` + `ci.yml` 的 `avx512` job 报告 skip 状态
- 方案 B（已实现）：使用 Intel SDE（Software Development Emulator）— 见 `amd64_avx512_sde.yml`
- 方案 C：找到支持 AVX512 的 CI runner（如 AWS c6i/m6i Ice Lake 实例）

**Intel SDE 用法（`amd64_avx512_sde.yml`）：**
```bash
# 0. Ubuntu 上需先禁用 yama ptrace 限制（SDE 基于 Pin，需要 ptrace attach）
sudo sysctl -w kernel.yama.ptrace_scope=0

# 1. 从 Intel 下载页动态提取真实 CDN URL 并安装（无需硬编码版本号）
URL="$(curl -sL 'https://www.intel.com/content/www/us/en/download/684897/intel-software-development-emulator.html' | \
  grep -oP '(?<=data-href=")(https://[^"]+)/sde-external-([0-9.\-]+)-lin\.tar\.xz' | head -n1)"
mkdir -p /opt/intel/sde
curl -sL "${URL}" | tar --strip-components 1 -JxC /opt/intel/sde

# 2. 编译测试二进制
go test -c -o base64.test .

# 3. 通过 SDE 运行（-icl 模拟 Ice Lake，含 AVX512 VBMI）
/opt/intel/sde/sde64 -icl -- ./base64.test -test.run 'AVX512' -test.v
/opt/intel/sde/sde64 -icl -- ./base64.test -test.bench 'AVX512' -test.benchtime 1x -test.run '^$' -test.v
```
**关键**: `downloadmirror.intel.com` 的直接 URL 无效（需要 JS 跳转）。正确方式是解析下载页 HTML 中的 `data-href` 属性获取真实 CDN URL，参考 [simd-everywhere/simde](https://github.com/simd-everywhere/simde/blob/master/test/download-sde.sh) 的做法。SDE 通过拦截 CPUID 让 `cpu.X86.HasAVX512VBMI` 在 init 时返回 `true`，AVX512 指令执行由软件模拟。

**本地编译验证命令（与平台一致，无需交叉编译）：**
```powershell
go build ./...
```

## 算法设计

### 参考实现

- [simdenc (dans-stuff/simdenc)](https://github.com/dans-stuff/simdenc) — Go + AVX512 VBMI 参考
- [Wojciech Muła 的 base64 算法分析](http://0x80.pl/notesen/2016-01-12-sse-base64-encoding.html)

### Go 1.25 AVX512 指令支持

✅ **完全原生支持**，无需 WORD 编码。所有指令均在 `avx_optabs.go` 中有 EVEX-512 编码：

| Intel 助记符 | Go 助记符 | 用途 |
|---|---|---|
| VPERMB | VPERMB | Encode: 64 字节 LUT 单指令查表 |
| VPERMI2B | VPERMI2B | Decode: 128 字节合并校验+翻译 |
| VPMULTISHIFTQB | 见当前 Go 汇编器支持情况 | Encode: 在 64-bit lane 内一次提取 8 个 sextet |
| VPMADDUBSW | VPMADDUBSW | Decode: 6-bit 字段合并 |
| VPMADDWD | VPMADDWD | Decode: 12-bit → 24-bit 压缩 |
| VPSHUFB | VPSHUFB | Decode: 字节重排 |
| VPSUBB | VPSUBB | Encode/Decode: 字节减法 |
| VPADDB | VPADDB | Encode/Decode: 字节加法 |
| VPAND / VPORD | VPANDD / VPORD | 位运算 |
| VMOVDQU32 | VMOVDQU32 | 512-bit 加载/存储 |
| VPSRLW | VPSRLW | 位移 |
| VPMOVB2M | VPMOVB2M | 提取字节符号位到 mask 寄存器 |
| VPCMPB | VPCMPB | 字节比较，结果写到 mask 寄存器 |
| VPXORD | VPXORD | 512-bit XOR（归零）|
| KTESTQ | KTESTQ | 测试 64-bit mask 是否有置位 |
| VEXTRACTI32X4 | VEXTRACTI32X4 | 从 ZMM 提取 16 字节到 XMM |
| VBROADCASTI32X4 | VBROADCASTI32X4 | 将 XMM（16 字节）广播到 ZMM 的 4 个 lane |

⚠️ **重要**：常见 AVX512 指令在 Go 汇编中通常**不加** `AV` 前缀，助记符与 AVX2 相同（但使用 ZMM 寄存器时汇编器自动选择 EVEX 编码）。`VPMULTISHIFTQB` 属于较新的 VBMI 指令，落地前应先用本地 Go 版本验证汇编器接受的准确助记符拼写。

### Encode 算法（VPERMB 路径）

**核心思想：** 复用已有的 SSE/AVX2 mulhi/mullo 技术提取 6-bit 索引，再用 64 字节 LUT + VPERMB 一条指令完成索引 → ASCII 映射。

**LUT 选择（setup，循环外）：**

`encodeAsm` 接收一个 `lut *[16]byte` 参数（SI），是 SSE/AVX2 路径用的 16 字节 lut。
AVX512 路径通过读取该 lut 的 byte[12] 来判断 std/url：
- Standard lut 的 byte[12] = `0xED`
- URL-safe lut 的 byte[12] = `0xEF`（只有最后一个 nibble 不同）

```asm
avx512:
    MOVQ SI, R9       // save lut pointer for AVX2 tail fallback
    MOVBLZX 12(SI), R8
    CMPB R8, $0xED
    JNE avx512_url_enc
    VMOVDQU32 enc512_std_lut<>(SB), Z4
    JMP avx512_enc_start
avx512_url_enc:
    VMOVDQU32 enc512_url_lut<>(SB), Z4
avx512_enc_start:
  VMOVDQU32 enc512_ms_shuffle<>(SB), Z5
  VBROADCASTI32X4 enc512_ms_shift<>(SB), Z6
    XORQ SI, SI     // SI 复用为输出字节偏移
```

这样复用了现有的 `lut` 指针参数，无需为 AVX512 新增函数参数。

```
输入: 48 bytes raw → 输出: 64 bytes base64（每轮从 64 字节中读前 48 字节）

Step 1: VMOVDQU32 (BX), Z0        // 加载 64 字节（前 48 有效）
Step 2: VPERMB Z0, Z5, Z0         // 用 enc512_ms_shuffle 按 qword 打包两个 triplet
Step 3: VPMULTISHIFTQB Z6, Z0, Z0 // 每个 qword 提取 8 个 sextet
Step 4: VPERMB Z4, Z0, Z0         // 查 64 字节 LUT，得到 64 个 ASCII 字符
Step 5: VMOVDQU32 Z0, (AX)(SI*1)  // 存储 64 字节
```

**encode LUT 常量（Standard，64 字节）：**
```
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
```

**encode LUT 常量（URL-safe，64 字节）：**
最后两字节改为 `-`（0x2D）和 `_`（0x5F）

### Encode 变体对照

当前 skill 覆盖三类 encode 实现选择，它们属于同一问题域，不需要拆分成多个 skill：

| 方案 | 热循环 | 特点 | 何时使用 |
|---|---|---|---|
| 当前默认方案 | `VPERMB -> VPANDD/VPMULHUW/VPANDD/VPMULLW/VPORD -> VPERMB` | 直接复用 SSE/AVX2 的 mulhi/mullo 提取法，最容易与现有 ASM 和 fallback 对齐 | 默认首选，适合先求稳定集成 |
| Muła 风格变体 | `VPERMB -> VPAND/VPSRLVW/VPSLLVW/VPTERNLOGD -> VPERMB` | 更“AVX512-native”，但现有研究材料没有明确证明它稳定优于 mulhi/mullo | 仅在要做 A/B benchmark 时尝试 |
| VPMULTISHIFTQB 变体 | `VPERMB -> VPMULTISHIFTQB -> VPERMB` | 把 sextet 提取从 5 条指令缩成 1 条，是 encode 最值得验证的高性能方向 | 当目标是追求 AVX512 encode 峰值时优先考虑 |

**经验结论（来自 simdenc/aklomp 方向的公开研究）：**
- `mulhi/mullo` 是一个合理的 AVX512 基线，不是“过时方案”
- 单纯把提取逻辑从乘法改成移位/三元逻辑，目前没有足够证据证明一定更快
- 真正有明确大幅收益的是 `VPMULTISHIFTQB`

### Encode 算法（VPMULTISHIFTQB 可选路径）

**适用前提：**
- 目标 CPU 具备 `AVX512VBMI`
- 允许为 encode 再维护一套专用常量和一小段专用汇编
- 可以接受该路径只优化 encode，不影响 decode 设计

**核心思想：**
先用 `VPERMB` 把 48 字节输入按 64-bit qword 重新打包，使每个 qword 包含两个连续 triplet：
```
[s2 s1 s0 s5 s4 s3 x x]
```
随后用单条 `VPMULTISHIFTQB` 从每个 qword 中抽取 8 个 6-bit sextet，最后再用 `VPERMB` 直接查 64 字节 ASCII LUT。

```
输入: 48 bytes raw → 输出: 64 bytes base64

Step 1: VMOVDQU32 (BX), Z0
Step 2: VPERMB Z0, Zshuffle, Z0       // 按 qword 打包两个 triplet
Step 3: VPMULTISHIFTQB Zshift, Z0, Z0 // 每个 qword 提取 8 个 sextet
Step 4: VPERMB Zlut, Z0, Z0           // 直接 sextet → ASCII
Step 5: VMOVDQU32 Z0, (AX)(SI*1)
```

**已知固定常量：**
- `enc512_ms_shift`：一个 16 字节块，内容对应两个 qword 的 selector `[10, 4, 22, 16, 42, 36, 54, 48]`，运行时用 `VBROADCASTI32X4` 广播
- direct ASCII LUT 可以直接复用 `enc512_std_lut` / `enc512_url_lut`，不需要新的 offset LUT

**实现注意：**
- `enc512_ms_shuffle` 取决于你选择的 qword 字节打包布局；只要布局与 `enc512_ms_shift` 匹配即可
- 这条路径通常不再需要 `mulhi_mask` / `mullo_mask` / `mulhi_const` / `mullo_const`
- 若当前仓库已经有稳定的 `VPERMB` + mulhi/mullo 版本，建议把 multishift 作为平行实验分支，而不是直接替换

### 在 `base64_amd64.s` 中落地 multishift encode 的实施清单

下面这组步骤是面向当前仓库结构的，不是泛化伪代码。目标是把 multishift 路径接到现有 `encodeAsm` 框架中，同时不破坏尾部回退。

1. **保留现有入口与长度门控不变**
  - 继续使用 `TEXT ·encodeAsm(SB)` 现有签名
  - 继续保留 `CMPQ CX, $64` 的 AVX512 入口门槛，因为主循环仍然做 64 字节安全读取、48 字节实际消耗

2. **保留现有 std/url LUT 选择逻辑**
  - 仍然使用传入的 16 字节 `lut` 判断标准表还是 URL-safe 表
  - `enc512_std_lut` / `enc512_url_lut` 可直接复用为 multishift 路径的 direct ASCII LUT
  - `MOVQ SI, R9` 这一步仍然需要保留，因为 AVX2 fallback 还要用到原始 `lut` 指针加载 `Y13`

3. **新增 multishift 专用常量，而不是复用 mulhi/mullo 常量**
  - 新增 `enc512_ms_shift`：一个 16 字节块，供 `VBROADCASTI32X4` 广播后形成每 qword 的 `[18,12,6,0,42,36,30,24]`
  - 新增 `enc512_ms_shuffle`：把输入重排成 `[s1,s0,s2,s1 | s4,s3,s5,s4]` 这种经过公开实现验证的 multishift 布局
  - `enc512_ms_shuffle` 为 64 字节，`enc512_ms_shift` 为 16 字节并在循环外广播到 ZMM

4. **新增独立的 multishift setup label**
  - 不要把 multishift 常量硬塞进当前 `avx512_enc_start`
  - 建议新增类似：
```asm
avx512_ms_start:
   VMOVDQU32 enc512_std_lut<>(SB), Z4   // or url LUT
   VMOVDQU32 enc512_ms_shuffle<>(SB), Z5
  VBROADCASTI32X4 enc512_ms_shift<>(SB), Z6
   XORQ SI, SI
```
  - 这样寄存器含义清晰，也不会和现有 mulhi/mullo 版本混淆

5. **新增独立的 multishift 主循环**
  - 推荐结构：
```asm
avx512_ms_loop:
   CMPQ CX, $64
   JB avx512_ms_done
   VMOVDQU32 (BX), Z0
   VPERMB Z0, Z5, Z0
   VPMULTISHIFTQB Z6, Z0, Z0
   VPERMB Z4, Z0, Z0
   VMOVDQU32 Z0, (AX)(SI*1)
   ADDQ $64, SI
   SUBQ $48, CX
   LEAQ 48(BX), BX
   JMP avx512_ms_loop
```
  - `BX/CX/SI` 的推进方式必须与现有 AVX512 encode 保持一致，这样尾部 fallback 的接口语义才完全兼容

6. **不要复用当前的“部分重载” fallback 优化**
  - 这是 multishift 接入时最容易踩的点
  - 当前仓库的 `avx512_done` 之所以只补加载 `Y6/Y11/Y12/Y13`，是因为 Z7-Z10 里已经放好了与 AVX2 共用的 mulhi/mullo 常量，低 256 位可以直接当 Y7-Y10 用
  - multishift 路径中 Z7-Z10 不再承载这些常量，因此**不能**直接 `JMP avx2_head`

7. **为 multishift 路径提供独立的 fallback setup**
  - 建议新增专用 label，例如：
```asm
avx512_ms_done:
   CMPQ CX, $16
   JB avx512_ms_ret
   VBROADCASTI128 reshuffle_mask<>(SB), Y6
   VBROADCASTI128 mulhi_mask<>(SB), Y7
   VBROADCASTI128 mulhi_const<>(SB), Y8
   VBROADCASTI128 mullo_mask<>(SB), Y9
   VBROADCASTI128 mullo_const<>(SB), Y10
   VBROADCASTI128 range_0_end<>(SB), Y11
   VBROADCASTI128 range_1_end<>(SB), Y12
   VBROADCASTI128 (R9), Y13
   JMP avx2_head
avx512_ms_ret:
   MOVQ SI, ret+56(FP)
   VZEROUPPER
   RET
```
  - 这比尝试“共享一部分 setup”更稳，因为 multishift 路径与 AVX2 不再共享中间常量寄存器状态

8. **确认 fallback 的剩余字节区间仍然成立**
  - 由于 multishift 主循环仍然是 `64-byte safe load / 48-byte consume`，退出时 `CX` 的范围与当前实现相同，仍然落在 `[16, 63]`
  - 这意味着 encode 仍然适合直接回退到 AVX2，而不是退回 Go 层走 generic
  - 也就是说：**multishift 改的是主循环，不改尾部策略**

9. **如果要最小化改动，优先采用“并行分支”而不是“替换现有 avx512”**
  - 保留当前 `avx512`（mulhi/mullo）分支作为稳定路径
  - 新增 `avx512_ms` 或实验分支，仅在 benchmark / 特定 gate 下命中
  - A/B 结果确认后，再决定是否把默认 encode AVX512 路径切换到 multishift

### multishift 对剩余字节 fallback 的具体影响

**不受影响的部分：**
- `BX` 仍指向“尚未编码的下一段输入起点”
- `SI` 仍是“已输出字节偏移”
- `CX` 仍是“剩余输入字节数”
- AVX2 fallback 仍然从当前位置继续编码，不需要回退或重算位置

**会受影响的部分：**
- 当前 mulhi/mullo 版 AVX512 encode 可以借用 Z7-Z10 的低 256 位给 AVX2 fallback 使用；multishift 版不行
- 因此 multishift 版 fallback 必须**完整重载** AVX2 encode 所需常量，不能套用当前那段“只补 4 个寄存器”的优化

**对 SSE / generic 尾部的影响：**
- 没有额外影响
- AVX2 fallback 执行完后，剩余不足 16 字节的情况与当前实现一致，仍由现有外层逻辑处理
- 不需要因为 multishift 改变 SSE3 或 scalar 的阈值

### Decode 算法（VPERMI2B 路径）

**核心思想：** VPERMI2B 可以做 128 字节 LUT 查表（输入值的 bit6 选择源寄存器），一条指令同时完成校验和翻译。

```
输入: 64 bytes base64 → 输出: 48 bytes raw

Step 1: VMOVDQU32 (BX), Z0        // 加载 64 字节 base64 输入
Step 2: VPERMI2B Z5, Z4, Z0       // 校验+翻译：Z4=LUT[0..63], Z5=LUT[64..127]
                                   // 非法字符 → 0xFF，合法字符 → 6-bit 值
Step 3: 检测非法字符
  VPXORD Z2, Z2, Z2               // Z2 = 0
  VPCMPB $1, Z2, Z0, K1           // K1[i]=1 if Z0[i] < 0 (bit7 置位 = 非法)
  KTESTQ K1, K1
  JNZ avx512_done                  // 有非法字符则退出，交给 generic 处理
Step 4: 6-bit → 24-bit 压缩（复用 AVX2 常量，via VBROADCASTI32X4）
  VPMADDUBSW Z6, Z0, Z0           // Z6 = dec_reshuffle_const0（广播）
  VPMADDWD Z7, Z0, Z0             // Z7 = dec_reshuffle_const1（广播）
  VPSHUFB Z8, Z0, Z0              // Z8 = dec_reshuffle_mask（广播）
  // 每 16 字节 lane 内：valid bytes at [0..11]（连续），[12..15] 填 0
Step 5: VPERMB Z0, Z3, Z0                     // 64→48 字节压缩（Z3=dec512_compress，循环前加载一次）
Step 6: 存储 48 字节
  VMOVDQU Y0, (AX)                // 低 32 字节（YMM 直接存储）
  VEXTRACTI32X4 $2, Z0, X1       // 提取 lane 2（字节 32..47）
  VMOVDQU X1, 32(AX)             // 存储高 16 字节
```

**Reshuffle 常量复用（VBROADCASTI32X4）：**
```asm
VBROADCASTI32X4 dec_reshuffle_const0<>(SB), Z6  // 与 AVX2 Y6 共用低256位
VBROADCASTI32X4 dec_reshuffle_const1<>(SB), Z7  // 与 AVX2 Y7 共用低256位
VBROADCASTI32X4 dec_reshuffle_mask<>(SB), Z8    // 与 AVX2 Y8 共用低256位
```

**Decode LUT 结构（Standard，各 64 字节）：**

`stddec512_lut_lo`（索引 0..63）：
- 0x00..0x2A → 0xFF（非法）
- 0x2B（+） → 62
- 0x2C..0x2E → 0xFF
- 0x2F（/） → 63
- 0x30..0x39（0-9）→ 52..61
- 0x3A..0x3F → 0xFF

`stddec512_lut_hi`（索引 64..127，即 ASCII 0x40..0x7F）：
- 0x40 → 0xFF
- 0x41..0x5A（A-Z）→ 0..25
- 0x5B..0x60 → 0xFF
- 0x61..0x7A（a-z）→ 26..51
- 0x7B..0x7F → 0xFF

**Decode LUT 结构（URL-safe）：**
- `urldec512_lut_lo`: 0x2B（+）→ 0xFF，0x2D（-）→ 62，0x2F（/）→ 0xFF；其余同 std
- `urldec512_lut_hi`: 0x5F（_）→ 63；其余同 std

**dec512_compress 常量（64 字节）：**

前 48 字节按 lane 连续选出有效字节，后 16 字节填 0（VPERMB 用 Z3 作索引寄存器，循环前 `VMOVDQU32 dec512_compress<>(SB), Z3` 加载一次）：
```
字节 0..47: lane0=[0..11], lane1=[16..27], lane2=[32..43], lane3=[48..59]
字节 48..63: 0x00（不使用）
```

> **重要**：`dec_reshuffle_mask` 中 0xFF 条目在每 lane 的第 12..15 字节处，所以每 lane 有效字节在 [0..11]（连续 12 个），不是 [0,1,2,4,5,6,8,9,10,12,13,14]。compress 表按此连续排列。

## LUT 生成脚本

技能目录下的 `gen_lut.go` 是一次性辅助脚本（`//go:build ignore`），用于生成 AVX512 相关 64 字节 LUT / 索引 / selector 常量的 Go 汇编 `DATA` 指令，直接粘贴进 `base64_amd64.s` 即可。

**运行方式：**
```bash
go run gen_lut.go
```

**生成的常量（按输出顺序）：**

| 常量名 | 大小 | 用途 |
|--------|------|------|
| `enc512_std_lut` | 64 字节 | encode Standard LUT（`A-Za-z0-9+/`） |
| `enc512_url_lut` | 64 字节 | encode URL-safe LUT（`A-Za-z0-9-_`） |
| `enc512_ms_shuffle` | 64 字节 | 可选 VPMULTISHIFTQB encode 路径的重排索引（每 qword 为 `[s1,s0,s2,s1 | s4,s3,s5,s4]`） |
| `enc512_ms_shift` | 16 字节 | 可选 VPMULTISHIFTQB encode 路径的 qword selector，运行时用 `VBROADCASTI32X4` 广播 |
| `stddec512_lut_lo` | 64 字节 | decode Standard LUT 低段（ASCII 0..63） |
| `stddec512_lut_hi` | 64 字节 | decode Standard LUT 高段（ASCII 64..127） |
| `urldec512_lut_lo` | 64 字节 | decode URL-safe LUT 低段 |
| `urldec512_lut_hi` | 64 字节 | decode URL-safe LUT 高段 |
| `dec512_compress` | 64 字节 | VPERMB 压缩索引（64→48 字节，每 lane 取连续 [0..11]，共 4 lane） |

**关键实现逻辑：**
- `le64`：将 8 字节切片按小端序打包为 `uint64`，输出 `0x...` 十六进制字面量（匹配 Go 汇编 `DATA` 语法）
- `enc512_ms_shift`：生成一个 16 字节块，内容为两个 qword 的 `[10, 4, 22, 16, 42, 36, 54, 48]`，供 `VBROADCASTI32X4` 扩成整条 ZMM selector
- decode LUT：非法字符填 `0xFF`（bit7 置位），后续 `VPCMPB $1, Z2, Z0, K1` 检测 `Z0[i] < 0`
- `dec512_compress`：每 lane 取连续 12 字节 `[lane*16 .. lane*16+11]`，前 48 字节有效，后 16 字节保持 0；在循环前加载到 Z3 寄存器，使用 `VPERMB Z0, Z3, Z0`（非内存形式）

**当前脚本的边界：**
- 已生成 `VPMULTISHIFTQB` 路径可直接复用的 direct LUT（即 `enc512_std_lut` / `enc512_url_lut`）和 shift selector（`enc512_ms_shift`）
- `enc512_ms_shuffle` 与所选 qword 打包布局强耦合，建议在最终确定 multishift 实现时再按具体布局生成，不在通用脚本里预设错误版本

## 处理阈值

| 路径 | Encode 阈值 | Decode 阈值 | 单轮处理 |
|------|------------|------------|---------|
| AVX512 VBMI | ≥64 字节输入（安全加载 64 字节）| ≥64 字节输入 | 48→64 / 64→48 |
| AVX2 | ≥28 字节输入 | ≥40 字节输入 | 24→32 / 32→24 |
| SSE3 | ≥16 字节输入 | ≥24 字节输入 | 12→16 / 16→12 |

**注意（Encode）：** 每轮实际消耗 48 字节输入，但要求 `CX ≥ 64` 是为了 `VMOVDQU32 (BX), Z0` 的安全读取；`enc512_ms_shuffle` 只会消费前 48 字节。

**AVX512 尾部处理：** 当剩余数据不足 64 字节（CX < 64）时退出 AVX512 循环，`avx512_done` 判断 CX 是否满足 AVX2 条件（encode ≥16, decode ≥24），若满足则直接跳到 AVX2 内部 label（`avx2_head`/`avx2_loop`），否则返回给 Go 层处理剩余字节。

**关键性质：** 当 CX_initial ≥ 64（入口条件），CX_final（所有 AVX512 轮次后）= CX_initial − N×48，其中 N = ⌊(CX_initial − 16) / 48⌋。可以证明 CX_final ∈ [16, 63]，因此对于 encode 路径，`avx512_ret`（CX < 16）**实际上永远不会被执行**：AVX512 循环后一定会进入 AVX2 fallback。

## 实现步骤（已全部完成 ✅）

### Phase 1: 准备工作 ✅
1. 在 `base64_asm.go` 中新增 `useAVX512VBMI` 变量，删除 `useAVX`
2. 验证编译通过

### Phase 2: 移除 AVX 路径 ✅
3. 从 `base64_amd64.s` 中删除 AVX 宏和所有 AVX 分支代码
4. 从 `base64_asm.go` 中删除 `useAVX` 变量
5. 验证 SSE3 和 AVX2 路径仍然正确（本地 `go test`）

### Phase 3: 实现 AVX512 Encode ✅
6. 定义 encode LUT 常量（std + url，各 64 字节）
7. 定义 `enc512_ms_shuffle` / `enc512_ms_shift` 常量
8. 实现 `avx512` encode 分支：`VPERMB pack -> VPMULTISHIFTQB -> VPERMB -> 存储`
9. 为 multishift 路径完善 AVX2 fallback 重载逻辑
  - `enc512_ms_shift` 使用 `VBROADCASTI32X4`，减少只读常量占用
  - `MOVQ SI, R9` 在 `XORQ SI, SI` 前备份 lut 指针

### Phase 3b: 可选的 VPMULTISHIFTQB Encode 实验
10. 定义 `enc512_ms_shift` 常量（16 字节，用 `VBROADCASTI32X4` 广播成每 qword 的 `[18,12,6,0,42,36,30,24]`）
11. 根据最终 qword 打包布局定义 `enc512_ms_shuffle` 常量
12. 实现独立 `avx512_ms` encode 分支：`VPERMB -> VPMULTISHIFTQB -> VPERMB`
13. 为 multishift 分支新增独立 `avx512_ms_done`，完整重载 `Y6-Y13` 后再跳 `avx2_head`
14. 使用独立 benchmark 与现有 mulhi/mullo 版本做 A/B，对比不同微架构（至少 Zen 4 / Zen 5 或 Intel Ice Lake 一类）

### Phase 4: 实现 AVX512 Decode ✅
15. 定义 stddec512_lut_lo/hi 和 urldec512_lut_lo/hi（各 64 字节）
16. 定义 dec512_compress（64 字节压缩表）
17. 复用 dec_reshuffle_const0/1/mask 16 字节常量（VBROADCASTI32X4 广播到 Z6-Z8）
    - reshuffle 寄存器用 Z6-Z8（而非其他编号）以与 AVX2 Y6-Y8 对齐
18. 实现 VPERMI2B 校验+翻译 + VPCMPB/KTESTQ 错误检测
19. 实现 512-bit 宽度 reshuffle + VPERMB 压缩
20. 存储方式：`VMOVDQU Y0` (32字节) + `VEXTRACTI32X4 $2` + `VMOVDQU X1` (16字节)

### Phase 5: 优化与测试 ✅
21. 添加输入长度预检（`CMPQ CX, $64`）避免短输入时加载无用 ZMM 常量
22. `avx512_done` 完善：回退到 AVX2 内部 label，而非直接返回给 Go 层（减少函数调用开销）
23. 对 multishift 分支单独检查 fallback：确认 `BX/CX/SI` 推进与原 AVX512 路径完全一致
24. 寄存器编号优化（Z7-Z10 encode, Z6-Z8 decode）以与 AVX2 对齐，消除 fallback 时的重复加载
25. 本地编译验证（`go build ./...`）
26. 运行测试（`go test -count=1 ./...` → `ok github.com/emmansun/base64`）

## 寄存器分配规划

### Encode（AVX512 主循环）

当前 encode 实现使用 multishift 路径。由于 Z7-Z10 不再保留 AVX2 所需 mulhi/mullo 常量，
`avx512_done` 会在回退到 `avx2_head` 前完整重载 Y6-Y13。

| 寄存器 | 用途 |
|--------|------|
| Z0 | 数据工作寄存器（输入/pack/索引/输出） |
| Z4 | encode LUT（64 字节，VPERMB 源）：std 或 url |
| Z5 | enc512_ms_shuffle（VPERMB 打包表） |
| Z6 | enc512_ms_shift（VBROADCASTI32X4 后的 selector） |
| SI | AVX512主循环: 输出字节偏移（XORQ 清零）；setup: lut 指针（由 R9 备份） |
| BX | 输入指针 |
| CX | 剩余输入字节数 |
| AX | 输出基址 |
| R8 | LUT 选择临时（读取 lut[12] 判断 std/url） |
| R9 | 备份 lut 指针（`MOVQ SI, R9` 在 XORQ SI 前），供 `avx512_done` 加载 Y13 用 |

### Decode（AVX512 主循环）

寄存器编号故意选 Z6-Z8 以与 AVX2 路径的 Y6-Y8 对齐，`avx512_done` 回退到
`avx2_loop` 时无需重新加载 reshuffle 常量。

| 寄存器 | 用途 |
|--------|------|
| Z0 | 数据工作寄存器（输入/翻译/reshuffle/压缩） |
| Z2 | 零寄存器（VPXORD Z2, Z2, Z2，VPCMPB 用） |
| Z3 | dec512_compress（VPERMB 压缩索引，循环前加载一次） |
| Z4 | decode LUT low（索引 0..63，VPERMI2B src1） |
| Z5 | decode LUT high（索引 64..127，VPERMI2B src2） |
| Z6 | dec_reshuffle_const0（与 AVX2 Y6 共用低256位） |
| Z7 | dec_reshuffle_const1（与 AVX2 Y7 共用低256位） |
| Z8 | dec_reshuffle_mask（与 AVX2 Y8 共用低256位） |
| K1 | error mask（VPCMPB 结果） |
| X0/Y0 | Z0 的低 128/256 位别名，用于存储 |
| X1 | VEXTRACTI32X4 $2 提取的 lane 2 |

## AVX512 → AVX2 内部 Fallback 机制

### 设计目标

AVX512 循环退出时（CX < 64），剩余字节由 ASM 内部的 AVX2 代码处理，而不是返回给 Go 层再调用 `encodeGeneric` / `decodeGeneric`。这避免了一次函数调用开销，并使 SIMD 效率最大化。

### Encode fallback (`avx512_done`)

```asm
avx512_done:
    // Fall back to AVX2 for the remaining tail (CX in [16..63]).
  // The multishift path does not preserve AVX2 mulhi/mullo constants in Y7-Y10,
  // so reload the full AVX2 encode state before jumping into avx2_head.
    CMPQ CX, $16
    JB avx512_ret
    VBROADCASTI128 reshuffle_mask<>(SB), Y6
    VBROADCASTI128 range_0_end<>(SB), Y11
    VBROADCASTI128 range_1_end<>(SB), Y12
    VBROADCASTI128 (R9), Y13    // lut pointer saved in R9 before XORQ SI
    JMP avx2_head               // Y7-Y10 already valid from Z7-Z10
avx512_ret:
    MOVQ SI, ret+56(FP)
    VZEROUPPER
    RET
```

- `Y6`/`Y11`/`Y12`/`Y13` 是 `avx2_head` 中用到的剩余寄存器（Y7-Y10 已由 Z7-Z10 低256位提供）
- R9 在 `avx512` 入口 `MOVQ SI, R9` 保存 lut 指针，避免 `XORQ SI, SI`（清零输出偏移）后丢失
- **无 `VZEROUPPER`**：因为紧接着执行 AVX2 VEX 指令，不需要清除 ZMM 上半部分

### Decode fallback (`avx512_done`)

```asm
avx512_done:
    // Fall back to AVX2 for the remaining tail (CX in [24..63]).
    // Y6-Y8 (dec_reshuffle_const0/1, dec_reshuffle_mask) are already valid as
    // the lower 256 bits of Z6-Z8; no VZEROUPPER needed.
    CMPQ CX, $24
    JB avx512_ret
    VBROADCASTI128 nibble_mask<>(SB), Y9
    VBROADCASTI128 stddec_lut_hi<>(SB), Y10
    VBROADCASTI128 stddec_lut_lo<>(SB), Y11
    VBROADCASTI128 stddec_lut_roll<>(SB), Y12
    JMP avx2_loop               // Y6-Y8 already valid from Z6-Z8
avx512_ret:
    MOVQ CX, ret+48(FP)
    VZEROUPPER
    RET
```

- `Y9`/`Y10`/`Y11`/`Y12` 是 `avx2_loop` 需要的其余寄存器（Y6-Y8 已由 Z6-Z8 低256位提供）
- URL decode 另需 `VBROADCASTI128 url_const_5e<>(SB), Y13`

### 寄存器复用的关键原理

`VBROADCASTI32X4 xmm_mem<>(SB), Z7` 将 16 字节常量广播到 ZMM 的全4个 128-bit lane。执行后，`Z7` 的低256位 = `Y7` = 2 lane 重复的相同常量，完全等同于 `VBROADCASTI128 xmm_mem<>(SB), Y7` 的结果。因此，切换到 VEX-编码的 AVX2 指令后，`Y7`～`Y10`（encode）或 `Y6`～`Y8`（decode）无需重新加载。

### 关键不变式

当 CX_initial ≥ 64 时（进入 AVX512 循环的前提），所有轮次执行完后有：
$$\text{CX\_final} = \text{CX\_initial} - N \times 48 \in [16, 63]$$
其中 N = ⌊(CX_initial − 16) / 48⌋。因为 CX_final ≥ 16，`avx512_ret` 路径在 encode 中**永远不会被执行**（dead code in practice）。Decode 中 CX_final ∈ [0, 63]（每轮消耗64字节），若能整除则 CX_final=0 < 24 → `avx512_ret` 会执行（意味着所有数据已处理完毕）。

## 注意事项

### VZEROUPPER
- AVX512 指令使用 ZMM 寄存器，直接返回前**必须**调用 `VZEROUPPER` 清除 ZMM 上半部分
- **AVX512 fallback 到 AVX2 时不需要 `VZEROUPPER`**：紧接着执行的 AVX2 VEX 指令不受 ZMM 上半部分值影响
- `avx512_ret`（直接 RET 路径）需要 `VZEROUPPER`；`avx512_done → avx2_head/loop` 路径不需要

### 64 字节对齐
- ZMM 加载/存储（VMOVDQU32/VMOVDQU64）不要求 64 字节对齐
- 但对齐可以提升性能，考虑在数据量足够大时做对齐处理

### VINSERTI32X4 别名
- Go 汇编中 `X0` 是 `Z0` 的低 128 位别名，`Y0` 是低 256 位别名
- 存储 48 字节时：`VMOVDQU Y0, (AX)` 存低 32 字节，`VEXTRACTI32X4 $2, Z0, X1` + `VMOVDQU X1, 32(AX)` 存高 16 字节
- 比 3×VEXTRACTI32X4 少一次 extract 指令

### VPERMB 与 VPERMI2B 的操作数语义

**VPERMB（Go 语法）：**
```asm
VPERMB Z_src, Z_idx, Z_dst    // dst[i] = src[idx[i] & 63]
```
注意 Go 汇编的操作数顺序与 Intel 手册相反。

**VPERMI2B（Go 语法）：**
```asm
VPERMI2B Z_src2, Z_src1, Z_idx_dst
// idx_dst[i] = (idx_dst[i] & 64) ? src2[idx_dst[i]&63] : src1[idx_dst[i]&63]
```
VPERMI2B 就地修改 idx 寄存器（Z_idx_dst 既是索引输入也是结果输出）。

### VBROADCASTI32X4 复用 16 字节常量
```asm
VBROADCASTI32X4 mulhi_mask<>(SB), Z6
// 将 16 字节 XMM 常量广播到 ZMM 的 4 个 128-bit lane，等效于 4 次拼接
// 避免定义专用 64 字节常量，节省 rodata 空间
```

### 输入长度预检模式
```asm
// 正确模式：先检查长度，再检查 CPU 能力
CMPQ CX, $64
JB   xxx_not_avx512
CMPB ·useAVX512VBMI(SB), $1
JE   avx512
xxx_not_avx512:
CMPB ·useAVX2(SB), $1
JE   avx2
```
每个函数用独立 label（`enc_not_avx512`、`stddec_not_avx512`、`urldec_not_avx512`）避免重名。

### Decode 压缩存储

选用 VPERMB + 2 次存储方案：
- `VMOVDQU Y0, (AX)` — 存低 32 字节（YMM 直接写，无需 extract）
- `VEXTRACTI32X4 $2, Z0, X1; VMOVDQU X1, 32(AX)` — 提取并存高 16 字节
- 共 1 次 VPERMB + 2 次 store + 1 次 extract，比 3×(extract+store) 少 1 次 extract
