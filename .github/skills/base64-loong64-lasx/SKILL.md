---
name: base64-loong64-lasx
description: "实现 LoongArch64 架构下 LASX（256-bit SIMD）加速的 BASE64 编解码 Go 汇编代码。Use when: 在 loong64 平台扩展 base64 实现、编写 LASX 汇编、处理 XVSHUFB/XVSSUBBU/XVSLTBU 等 Go 1.25 中缺失的 LASX 指令 WORD 编码、loong64 Go assembly SIMD optimization。"
argument-hint: "encode 或 decode，或留空处理完整实现"
---

# LoongArch64 LASX BASE64 实现技能

## 适用场景

- 在 `base64_loong64.go` / `base64_loong64.s` 基础上新增 LASX（256-bit）路径
- 将现有 LSX（128-bit）实现迁移/扩展为 LASX 实现
- 处理 Go 1.25 尚未收录的 LASX 指令，需手动生成 `WORD` 指令字
- 调试 LASX 汇编逻辑，本地交叉编译 + GitHub Actions QEMU 验证

## 环境约束

| 环境 | 用途 |
|------|------|
| 本地 | 仅做交叉编译（`GOARCH=loong64`），确认语法无误 |
| GitHub Actions QEMU | 运行时测试，提交后自动触发 |

**本地交叉编译验证命令：**

```powershell
$env:GOARCH="loong64"; $env:GOOS="linux"; go build ./...
```

## 实现流程

详细实现步骤参见 [implementation-guide.md](./references/implementation-guide.md)。

## ⚠️ Go 1.25 关键语法限制（必读）

以下语法在 Go 1.25 loong64 汇编器中**不受支持**，会报 `invalid LSX/LASX arrangement type: Q` 错误：

| 错误写法 | 正确替代 | 说明 |
|----------|----------|------|
| `XVMOVQ X0, X0.Q1` | `XVMOVQ X0, X0.Q2` | `Q2` = xvreplve0.q（将 Q0 广播到全 256-bit）|
| `XVMOVQ X0, X0.Q[1]` | `XVMOVQ X0, X0.Q2` | 同上，`Q[n]` 索引形式也不支持 |
| `XVMOVQ X9, X8.Q[1]` | `WORD $0x77ec0928` | xvpermi.q X8, X9, 0x02（将 X9.Q0 合并到 X8.Q1；`xvinsve0.q` 不存在于官方 ISA）|
| `VMOVQ X8.Q[1], 12(R5)` | 见"Decode 写出"节 | Q 元素提取不支持，需用 xvpickve.d 绕过 |

**可用的 LASX 寄存器元素操作：**
- `XVMOVQ X8.V[n], X9`：`xvpickve.d`，提取第 n 个 64-bit 元素到 X9（n = 0..3）
- `XVMOVQ X8.W[n], X9`：`xvpickve.w`，提取第 n 个 32-bit 元素（n = 0..7）
- `XVMOVQ X8, X8.Q2`：`xvreplve0.q`，将 Q0 广播到整个 256-bit 寄存器
- `XVMOVQ X8, (R5)`：`xvst`，存储完整 256-bit（32 字节）

### 第一步：常量加载

```asm
VMOVQ  (0*16)(R9), V0     // 先以 LSX V 寄存器加载 16 字节
XVMOVQ X0, X0.Q2          // xvreplve0.q：Q0 → 整个 256-bit（Q0 = Q1）
```

### 第二步：Encode 实现结构

```
加载常量 (LSX→LASX Q2 广播)
  ↓
lasx_head：首 28 字节处理（特殊 load 方式）
  ├─ 两次 VMOVQ load → WORD $0x77ec0928（xvpermi.q X8, X9, 0x02）合并为一个 LASX 寄存器
  ├─ XVSHUFB（需 WORD 编码）pack 数据
  └─ XVSSUBBU / XVSLTBU（需 WORD 编码）查表
  └─ XVMOVQ X8, (R5)  // 写满 32 字节
  ↓
lasx_loop：每次处理 24 字节输入 → 32 字节输出
  ├─ XVMOVQ -4(R6), X8（借用前 4 字节，凑成 32 字节）
  ├─ XVSHUFB（loop 专用 32-byte indices mask）
  └─ 同 lasx_head 逻辑
  └─ XVMOVQ X8, (R5)  // 写满 32 字节
```

### 第三步：Decode 实现结构

分 `decodeStdAsm`（标准）/ `decodeUrlAsm`（URL）两个函数，常量不同，逻辑相同。
每次处理 **32 字节输入 → 24 字节输出**。

```
加载常量 (LSX→LASX Q2 广播)
  ↓
循环（每次 32 字节输入）
  ├─ XVMOVQ (R6), X8
  ├─ 校验：XVSRLB + XVANDB + XVSHUFB(LUT_HI/LO) + XVANDV
  ├─ 转换：XVSEQB/XVSLTBU + XVSHUFB(LUT_ROLL) + XVADDB
  ├─ 重排：XVMULWEVHBU + xvmaddwod.h.bu + XVMULWEVWHU + xvmaddwod.w.hu + XVSHUFB
  └─ 写出 24 字节（见"Decode 写出"节）
```

**Decode 写出（24 字节）：**

```asm
VMOVQ  V8, (R5)          // 写 Q0：bytes[0..11] 有效（bytes[12..15] = 0，由 reshuffle mask 保证）
WORD $0x77ec0d09         // xvpermi.q X9, X8, 0x03：X9.Q0 = X8.Q1
VMOVQ  V9, 12(R5)        // 写 bytes[12..23]（有效），bytes[24..27] = 0
```

> **说明：** decode reshuffle mask 在 bytes[12..15] 处填 `0xFF`，XVSHUFB 将该位置置 0；`xvpermi.q X9, X8, 0x01` 把 X8.Q1（含置 0 的尾部）复制到 X9.Q0，再用 `VMOVQ V9, 12(R5)` 即可，无需额外提取步骤。

### 第四步：生成缺失指令的 WORD 编码

**已验证完整 WORD 编码表：**

| 指令 | WORD 值 | 说明 |
|------|---------|------|
| `XVSHUFB X0, X8, X8, X8` | `0x0d602108` | encode head reshuffle |
| `XVSHUFB X13, X8, X8, X8` | `0x0d66a108` | encode loop reshuffle |
| `XVSHUFB X9, X7, X7, X9` | `0x0d649ce9` | encode LUT lookup |
| `XVSSUBBU X5, X8, X9` | `0x744c1509` | encode range sub |
| `XVSLTBU X8, X6, X10` | `0x740820ca` | encode range compare |
| `XVSHUFB X9, X1, X1, X11` | `0x0d64842b` | decode hi nibble lookup |
| `XVSHUFB X10, X2, X2, X10` | `0x0d65084a` | decode lo nibble lookup |
| `XVSHUFB X10, X4, X4, X10` | `0x0d65108a` | decode lut_roll lookup |
| `XVSHUFB X7, X8, X8, X8` | `0x0d63a108` | decode output reshuffle |
| `xvmaddwod.h.bu X8, X5, X9` | `0x74b620a9` | decode reshuffle step 1 |
| `xvmaddwod.w.hu X9, X6, X8` | `0x74b6a4c8` | decode reshuffle step 2 |
| `XVSLTBU X8, X3, X10`（URL）| `0x7408206a` | URL decode range compare |
| `xvpermi.q X8, X9, 0x02` | `0x77ec0928` | encode head: X8.Q0=keep, X8.Q1=X9.Q0 |
| `xvpermi.q X9, X8, 0x01` | `0x77ec0509` | decode store: X9.Q0 = X8.Q1 |

WORD 编码生成脚本（Python）：

```python
def OP_RRRR(op, ra, rk, rj, rd):   # 4-寄存器（XVSHUFB）
    return op | ((ra&0x1F)<<15) | ((rk&0x1F)<<10) | ((rj&0x1F)<<5) | (rd&0x1F)

def OP_RRR(op, rk, rj, rd):         # 3-寄存器
    return op | ((rk&0x1F)<<10) | ((rj&0x1F)<<5) | (rd&0x1F)

XVSHUFB_OP        = 0x0d6   << 20
XVSSUBBU_OP       = 0xe898  << 15
XVSLTBU_OP        = 0xe810  << 15
XVMADDWOD_H_BU_OP = 0x0e96c << 15
XVMADDWOD_W_HU_OP = 0x0e96d << 15
```

`xvpermi.q` 编码公式：`WORD = 0x77EC0000 | (imm8<<10) | (Xj<<5) | Xd`

`xvpermi.q Xd, Xj, imm8` 语义（⚠️ 注意：Q0/Q1 选择器位布局与直觉相反，已通过 QEMU 实测验证）：
- **Q0** 选择器：`imm8[1:0]`：0=Xj.Q0, 1=Xj.Q1, 2=Xd.Q0(旧), 3=Xd.Q1(旧)
- **Q1** 选择器：`imm8[5:4]`：0=Xj.Q0, 1=Xj.Q1, 2=Xd.Q0(旧), 3=Xd.Q1(旧)
- 示例：imm8=0x02（Q0 sel=2→Xd.Q0保持, Q1 sel=0→Xj.Q0）；imm8=0x01（Q0 sel=1→Xj.Q1）

> **经 QEMU 实测验证（2026-03）：** 选择器 0/1 从 Xj 取值，2/3 从 Xd（旧值）取值。旧版文档（0/1=Xd, 2/3=Xj）是错误的。

### 第五步：提交并验证

```bash
git add base64_loong64.s
git commit -m "loong64: add LASX encode/decode path"
git push
```

推送后观察 GitHub Actions 中 QEMU loong64 任务的结果。

## 关键注意事项

- `XVSHUFB` 的源1和源2**顺序不可颠倒**，否则产生错误结果
- 循环体中 `XVSHUFB` 使用的 indices 与首次处理的 28 字节**不同**，需参考 AVX2 实现取值
- LASX 寄存器命名：LSX 用 `V0`–`V31`，LASX 用 `X0`–`X31`；V8 和 X8 是同一物理寄存器，`VMOVQ V8` 访问其低 128-bit
- `XVMOVQ X8, (R5)` 写 32 字节；`VMOVQ V8, (R5)` 写 16 字节（Q0 低 lane）
- `VMOVQ X8, (R5)` **不支持**（XREG 不能用于 VST），必须写 `VMOVQ V8, (R5)`
- Decode 写出策略：用 `xvpickve.d`（`XVMOVQ X8.V[n], Xd`）逐段提取，末尾会多写若干零字节，需保证 dst buffer 有足够余量
- Encode dispatch 阈值：≥28 字节走 LASX；Decode dispatch 阈值：≥40 字节走 LASX
- 调度变量：`·useLASX(SB)` （对应 AMD64 的 `·useAVX2(SB)`）
- `XVPERMIQ` / `XVPERMI.Q` 在 Go 1.25 中**没有具名指令**，但可用 `WORD $0x77ec____` 手动编码 `xvpermi.q`（见 WORD 编码表）

## 参考资料

- [详细实现指南](./references/implementation-guide.md)
- [Go 1.25 loong64 指令集定义](https://github.com/golang/go/blob/release-branch.go1.25/src/cmd/internal/obj/loong64/)
- [instOp.go（操作码来源）](https://github.com/golang/go/blob/master/src/cmd/internal/obj/loong64/instOp.go)
- [asm.go（指令字生成逻辑）](https://github.com/golang/go/blob/master/src/cmd/internal/obj/loong64/asm.go)
- 现有 LSX 实现：`base64_loong64.s`
- AVX2 实现（indices 参考）：`base64_amd64.s`
