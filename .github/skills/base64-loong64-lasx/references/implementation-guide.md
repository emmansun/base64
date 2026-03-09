# LoongArch64 LASX BASE64 实现详细指南

> LASX 下的实现和 LSX 基本原理一致，只是增大了吞吐量（128-bit → 256-bit）。

---

## ⚠️ Go 1.25 LASX 语法限制

Go 1.25 loong64 汇编器对 LASX 寄存器的操作支持**不完整**，以下是已确认的限制和解决方案。

### 常量广播（LSX → LASX 高 lane）

错误写法（报 `invalid LSX/LASX arrangement type: Q`）：

```asm
XVMOVQ X0, X0.Q1    // ❌ 不支持 Q[n] 索引语法
XVMOVQ X0, X0.Q[1]  // ❌ 同上
```

正确写法（`Q2` = xvreplve0.q，将 Q0 广播到整个 256-bit）：

```asm
XVMOVQ X0, X0.Q2    // ✓ Q0 内容复制到 Q1，X0 的低/高 128-bit 完全相同
```

### Q lane 插入（两个 LSX load → 一个 LASX 寄存器）

错误写法：

```asm
XVMOVQ X9, X8.Q[1]  // ❌ 不支持 Q 元素插入
```

正确写法（`xvpermi.q`，需手动 WORD 编码）：

```asm
WORD $0x77ec8128    // xvpermi.q X8, X9, 0x20：X8.Q0 不变，X8.Q1=X9.Q0
```

编码公式：`WORD = 0x77EC0000 | (imm8<<10) | (Xj<<5) | Xd`
- 对于 `xvpermi.q X8, X9, 0x20`：`0x77EC0000 | (0x20<<10) | (9<<5) | 8 = 0x77ec8128`

> **注意：** `xvinsve0.q` **不存在**于官方 LoongArch ISA。loongarch-opcodes/lasx.txt 中只有 `xvinsve0.w`（0x76ffc000）和 `xvinsve0.d`（0x76ffe000），无 `.q` 变体。

### Q lane 提取 / 写出

错误写法：

```asm
VMOVQ X8.Q[1], 12(R5)  // ❌ 不支持 Q 元素提取到内存
VMOVQ X8, (R5)          // ❌ XREG（X8）不能用于 VST，必须用 V 寄存器
```

Go 1.25 支持 **64-bit 元素**提取：

```asm
XVMOVQ X8.V[2], X9   // ✓ xvpickve.d：提取 X8 第 2 个 64-bit 元素 → X9（即 Q1 的低 8 字节）
XVMOVQ X8.V[3], X10  // ✓ xvpickve.d：提取 X8 第 3 个 64-bit 元素 → X10（即 Q1 的高 8 字节）
```

元素索引对应关系（X8 = 32 字节）：

| V[n] | X8 的字节范围 | 所在 lane |
|------|---------------|-----------|
| V[0] | bytes [0..7]  | Q0 低半 |
| V[1] | bytes [8..15] | Q0 高半 |
| V[2] | bytes [16..23] | Q1 低半 |
| V[3] | bytes [24..31] | Q1 高半 |

---

## Encode 实现

### 1. 加载常量

共享 `base64_const<>` 中的 16 字节常量，先以 LSX 指令加载，再广播到 LASX 高 lane：

```asm
VMOVQ  (0*16)(R9), V0
XVMOVQ X0, X0.Q2    // xvreplve0.q：Q0 → 整个 256-bit（低/高 lane 相同）
```

**循环专用 reshuffle mask**（32 字节，需在 `base64_const<>` 末尾追加）：

```asm
// 在 DATA 段追加（offset 0x70，总大小 $144 = 9×16 字节）：
// Q1 lane（对应输入 bytes[12..23]）：
DATA base64_const<>+0x70(SB)/8, $0x0809070805060405
DATA base64_const<>+0x78(SB)/8, $0x0e0f0d0e0b0c0a0b
// Q0 lane（对应输入 bytes[0..11]）：
DATA base64_const<>+0x80(SB)/8, $0x0405030401020001
DATA base64_const<>+0x88(SB)/8, $0x0a0b090a07080607
GLOBL base64_const<>(SB), (NOPTR+RODATA), $144  // 从 $112 扩展到 $144
```

加载 32 字节 mask（直接用 XVMOVQ）：

```asm
XVMOVQ (7*16)(R9), X13   // 直接加载 32 字节到 LASX 寄存器，Q0/Q1 均已填入
```

---

### 2. lasx_head：首 28 字节处理

#### 2.1 数据读取

```asm
VMOVQ      (R6), V8         // bytes [0..15]（X8.Q0）
VMOVQ  12(R6), V9           // bytes [12..27]（X9.Q0）
WORD $0x77ec8128            // xvpermi.q X8, X9, 0x20：X8 = { [12..27] | [0..15] }
```

此后 X8 的布局：
```
X8.Q1 (bytes 16..31): 原始输入 bytes [12..27]
X8.Q0 (bytes  0..15): 原始输入 bytes [ 0..15]
```

Head reshuffle mask（X0，16 字节广播）对应 LSX 的 `RESHUFFLE_MASK`。

应用 `XVSHUFB X0, X8, X8, X8`（`WORD $0x0d602108`）后，Q0 和 Q1 各自独立 pack 12 字节有效数据。

#### 2.2 Pack 数据

```asm
WORD $0x0d602108    // XVSHUFB X0, X8, X8, X8  （head reshuffle）
XVANDV X1, X8, X9
XVSRLH X2, X9, X9
XVANDV X3, X8, X8
XVSLLH X4, X8, X8
XVORV  X9, X8, X8
```

#### 2.3 查表并写出

```asm
WORD $0x744c1509    // XVSSUBBU X5, X8, X9
WORD $0x740820ca    // XVSLTBU X8, X6, X10
XVSUBB X10, X9, X9
WORD $0x0d649ce9    // XVSHUFB X9, X7, X7, X9  （LUT 查表）
XVADDB X9, X8, X8
XVMOVQ X8, (R5)     // xvst：写满 32 字节（24 字节有效 base64 输出）

ADDV $28, R6
SUBV $28, R7
ADDV $32, R5
```

---

### 3. lasx_loop：循环处理（每次 24 字节输入 → 32 字节输出）

#### 3.1 数据读取

```asm
XVMOVQ -4(R6), X8   // 往前借 4 字节，读 bytes [-4..27]（32 字节）
```

#### 3.2 Pack 数据

使用 loop 专用 32 字节 reshuffle mask（X13）：

```asm
WORD $0x0d66a108    // XVSHUFB X13, X8, X8, X8  （loop reshuffle）
// ... 其余与 lasx_head 相同
ADDV $24, R6
SUBV $24, R7
ADDV $32, R5
```

Loop reshuffle mask 的 indices 含义：选取 `[-4..27]` 中的 bytes `[0..11]` 和 `[12..23]`，
剔除前 4 个"借来的"字节，格式与 `base64_amd64.s` 中的 `reshuffle_mask32` 相同。

> **警告：** `XVSHUFB` 的源1和源2顺序不可颠倒，否则产生错误结果。

#### 3.3 lasx_tail 回退

```asm
lasx_tail:
    MOVV $16, R10
    BGEU R7, R10, loop    // 回退到 LSX loop
    JMP done
```

---

## Decode 实现

分 `decodeStdAsm`（标准）/ `decodeUrlAsm`（URL）两个函数，常量不同，逻辑相同。

### 1. 加载常量

```asm
VMOVQ  (0*16)(R8), V1   // 标准 LUT_HI；URL 为 (4*16)(R8)
XVMOVQ X1, X1.Q2
// ... 其余 V2–V7 同理
MOVV $40, R10           // LASX 循环阈值（需 ≥40 字节输入）
```

### 2. 校验输入

```asm
XVMOVQ (R6), X8         // 加载 32 字节
XVSRLB $4, X8, X9       // high nibble
XVANDB $0xf, X8, X10    // low nibble
WORD $0x0d64842b        // XVSHUFB X9, X1, X1, X11  （hi nibble → LUT_HI 查表）
WORD $0x0d65084a        // XVSHUFB X10, X2, X2, X10 （lo nibble → LUT_LO 查表）
XVANDV X11, X10, X10
XVSETEQV X10, FCC0      // 全零 → 合法
BFPF stddec_lasx_done   // 非零 → 错误退出
```

### 3. 转换（Standard vs URL 的差异）

**Standard decode：**

```asm
XVSEQB X8, X3, X10      // 比较 0x2F 与输入（DECODE_END）
XVADDB X9, X10, X10     // add eq_2F with hi_nibbles
WORD $0x0d65108a        // XVSHUFB X10, X4, X4, X10  （lut_roll 查表）
XVADDB X10, X8, X8      // 加 delta
```

**URL decode：**

```asm
WORD $0x7408206a        // XVSLTBU X8, X3, X10  （比较 0x5E 与输入）
XVSUBB X10, X9, X10     // sub gt_5E with hi_nibbles
WORD $0x0d65108a        // XVSHUFB X10, X4, X4, X10  （lut_roll 查表；与 std 相同 WORD）
XVADDB X10, X8, X8
```

### 4. 重排输出字节

```asm
XVMULWEVHBU X8, X5, X9
WORD $0x74b620a9        // xvmaddwod.h.bu X8, X5, X9

XVMULWEVWHU X9, X6, X8
WORD $0x74b6a4c8        // xvmaddwod.w.hu X9, X6, X8

WORD $0x0d63a108        // XVSHUFB X7, X8, X8, X8  （output reshuffle）
```

重排后 X8 的布局：
- Q0 bytes [0..11]：第一组 12 字节有效输出，bytes [12..15] = 0
- Q1 bytes [0..11]（= X8 bytes [16..27]）：第二组 12 字节有效输出，bytes [12..15] = 0

### 5. 写出 24 字节

使用 `xvpermi.q` 提取高 128-bit lane，3 条指令完成写出：

```asm
VMOVQ  V8, (R5)          // 写 Q0 lane：bytes[0..11] 有效，[12..15] = 0（reshuffle mask 保证）
WORD $0x77ec0d09         // xvpermi.q X9, X8, 0x03：X9.Q0 = X8.Q1
VMOVQ  V9, 12(R5)        // 写 bytes[12..23]（有效），bytes[24..27] = 0

ADDV $24, R5
SUBV $32, R7
ADDV $32, R6
```

> **原理：** decode reshuffle mask（`decode_const<>+0xA0/0xA8`）在每个 Q lane 内 bytes[12..15] 处填 `0xFF`，XVSHUFB 将该位置置 0。`xvpermi.q X9, X8, 0x01`（imm8=0x01，即 Xd.Q0=Xj.Q1）将 X8.Q1 整个复制到 X9.Q0，再用 `VMOVQ V9, 12(R5)` 即可写出 bytes[12..23]。无需额外 `xvpickve.d` 提取步骤。

### 6. lasx_tail 回退

```asm
stddec_lasx_tail:
    MOVV $24, R10
    BGEU R7, R10, loop    // 回退到 LSX loop
stddec_lasx_done:
    MOVV R7, ret+48(FP)
    RET
```

---

## 完整 WORD 编码表

| 指令 | WORD 值 | 说明 |
|------|---------|------|
| `XVSHUFB X0, X8, X8, X8` | `0x0d602108` | encode head reshuffle |
| `XVSHUFB X13, X8, X8, X8` | `0x0d66a108` | encode loop reshuffle |
| `XVSHUFB X9, X7, X7, X9` | `0x0d649ce9` | encode LUT lookup |
| `XVSSUBBU X5, X8, X9` | `0x744c1509` | encode range subtract |
| `XVSLTBU X8, X6, X10` | `0x740820ca` | encode range compare |
| `XVSHUFB X9, X1, X1, X11` | `0x0d64842b` | decode hi nibble lookup |
| `XVSHUFB X10, X2, X2, X10` | `0x0d65084a` | decode lo nibble lookup |
| `XVSHUFB X10, X4, X4, X10` | `0x0d65108a` | decode lut_roll lookup |
| `XVSHUFB X7, X8, X8, X8` | `0x0d63a108` | decode output reshuffle |
| `xvmaddwod.h.bu X8, X5, X9` | `0x74b620a9` | decode reshuffle step 1 |
| `xvmaddwod.w.hu X9, X6, X8` | `0x74b6a4c8` | decode reshuffle step 2 |
| `XVSLTBU X8, X3, X10`（URL）| `0x7408206a` | URL decode range compare |
| `xvpermi.q X8, X9, 0x20` | `0x77ec8128` | encode head: X8.Q0=keep, X8.Q1=X9.Q0 |
| `xvpermi.q X9, X8, 0x03` | `0x77ec0d09` | decode store: X9.Q0 = X8.Q1 |

### WORD 编码生成脚本

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

# XVSHUFB X0, X8, X8, X8  →  ra=0, rk=8, rj=8, rd=8
print(hex(OP_RRRR(XVSHUFB_OP, 0, 8, 8, 8)))  # 0xd602108

# XVSSUBBU X5, X8, X9  →  rk=5, rj=8, rd=9
print(hex(OP_RRR(XVSSUBBU_OP, 5, 8, 9)))      # 0x744c1509
```

### xvpermi.q 编码公式

`xvpermi.q Xd, Xj, imm8`：
- Q0 选择器：`imm8[1:0]`：**0=Xd.Q0, 1=Xd.Q1, 2=Xj.Q0, 3=Xj.Q1**
- Q1 选择器：`imm8[5:4]`：**0=Xd.Q0, 1=Xd.Q1, 2=Xj.Q0, 3=Xj.Q1**
- opcode：`0x77EC0000`，格式：`XdXjUk8`
- **Caveat（LA264/LA464）：** `imm8[2]=1` 时 dst.Q0 强制为 0；`imm8[7]=1` 时 dst.Q1 强制为 0。避免设置这两个位。

```python
base = 0x77EC0000
# xvpermi.q X8, X9, 0x20  →  Xd=8, Xj=9, imm8=0x20
# Q0 bits[1:0]=0b00=0 → Xd.Q0=X8.Q0(keep); Q1 bits[5:4]=0b10=2 → Xj.Q0=X9.Q0
word = base | (0x20 << 10) | (9 << 5) | 8  # = 0x77ec8128
# xvpermi.q X9, X8, 0x03  →  Xd=9, Xj=8, imm8=0x03
# Q0 bits[1:0]=0b11=3 → Xj.Q1=X8.Q1; Q1 bits[5:4]=0b00=0 → Xd.Q0=X9.Q0(keep)
word = base | (0x03 << 10) | (8 << 5) | 9  # = 0x77ec0d09
```

---

## 参考链接

- [Go 1.25 loong64 指令集](https://github.com/golang/go/blob/release-branch.go1.25/src/cmd/internal/obj/loong64/)
- [instOp.go](https://github.com/golang/go/blob/master/src/cmd/internal/obj/loong64/instOp.go)
- [asm.go](https://github.com/golang/go/blob/master/src/cmd/internal/obj/loong64/asm.go)
