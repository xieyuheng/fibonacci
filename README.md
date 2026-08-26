# Fibonacci Benchmark

同一份源码的朴素递归 `fibonacci(40)` 跨语言基准测试；C 行是同一份 `fibonacci.c` 在不同优化级别（`-O0/-O1/-O2`）下的编译结果。

- 运行 `./bench.sh` 重新测量，结果只打印到终端，不再改写本 README。
- 下表为手工维护的静态数据（本机一次运行、单次墙钟计时，含进程启动开销；单次测量存在负载噪声，重跑后请手动更新本表）。

| 语言                | 用时（秒） | 相对用时 |
|---------------------|------------|----------|
| C -O2（迭代化）     | 0.120      | 0.20     |
| WAT / Node.js       | 0.319      | 0.52     |
| Java                | 0.323      | 0.53     |
| Go                  | 0.384      | 0.63     |
| C -O1（寄存器分配） | 0.428      | 0.70     |
| Chez Scheme         | 0.572      | 0.94     |
| C -O0（朴素递归）   | 0.608      | 1.00     |
| WAT / wasmtime      | 0.662      | 1.09     |
| LuaJIT              | 0.726      | 1.19     |
| Node.js             | 0.814      | 1.34     |
| Erlang              | 1.990      | 3.27     |
| Erlang（无 JIT）    | 2.928      | 4.82     |
| Ruby                | 6.306      | 10.37    |
| Lua                 | 7.955      | 13.09    |
| Python              | 8.178      | 13.45    |

## C 优化级别观察（gcc，同一份 `fibonacci.c`）

- **C -O0** — 变量全驻栈、寄存器仅做单语句内的临时搬运；忠实于源码的朴素递归，便于调试。
- **C -O1** — 生命周期感知的寄存器分配：`n` 住进 callee-saved 寄存器跨递归调用存活；调用次数不变，单次调用变轻。
- **C -O2** — 编译器着手改写算法：树形递归被改写成奇偶拆分的迭代循环，调用次数降一个数量级以上。

## gcc 汇编示例（Intel 语法）

`fibonacci` 函数在 `-O0` 与 `-O1` 下都是朴素递归（每个节点两次 `call fibonacci`），差别只在寄存器分配；`-O2` 已是迭代形态（全函数仅一处 `call`），不再展示。复现命令：`gcc -O0/-O1 -c fibonacci.c && objdump -d -Mintel fibonacci.o`。

### C -O0：变量全驻栈，寄存器仅做临时搬运

```
0000000000000000 <fibonacci>:
   0:	55                      push   rbp
   1:	48 89 e5                mov    rbp,rsp
   4:	53                      push   rbx
   5:	48 83 ec 18             sub    rsp,0x18
   9:	89 7d ec                mov    DWORD PTR [rbp-0x14],edi
   c:	83 7d ec 01             cmp    DWORD PTR [rbp-0x14],0x1
  10:	7f 05                   jg     17 <fibonacci+0x17>
  12:	8b 45 ec                mov    eax,DWORD PTR [rbp-0x14]
  15:	eb 1e                   jmp    35 <fibonacci+0x35>
  17:	8b 45 ec                mov    eax,DWORD PTR [rbp-0x14]
  1a:	83 e8 01                sub    eax,0x1
  1d:	89 c7                   mov    edi,eax
  1f:	e8 00 00 00 00          call   24 <fibonacci+0x24>
  24:	89 c3                   mov    ebx,eax
  26:	8b 45 ec                mov    eax,DWORD PTR [rbp-0x14]
  29:	83 e8 02                sub    eax,0x2
  2c:	89 c7                   mov    edi,eax
  2e:	e8 00 00 00 00          call   33 <fibonacci+0x33>
  33:	01 d8                   add    eax,ebx
  35:	48 8b 5d f8             mov    rbx,QWORD PTR [rbp-0x8]
  39:	c9                      leave
  3a:	c3                      ret
```

要点：`n` 全程住在栈上（`[rbp-0x14]`），每用一次都要 `mov eax,[rbp-0x14]` 取回；`ebx` 仅用来跨第二次 `call` 暂存 `fib(n-1)` 的结果（callee-saved，被调函数不会改它）；收尾 `leave` = `mov rsp,rbp; pop rbp`。

### C -O1：生命周期感知的寄存器分配

```
0000000000000000 <fibonacci>:
   0:	55                      push   rbp
   1:	53                      push   rbx
   2:	48 83 ec 08             sub    rsp,0x8
   6:	89 fb                   mov    ebx,edi
   8:	83 ff 01                cmp    edi,0x1
   b:	7f 09                   jg     16 <fibonacci+0x16>
   d:	89 d8                   mov    eax,ebx
   f:	48 83 c4 08             add    rsp,0x8
  13:	5b                      pop    rbx
  14:	5d                      pop    rbp
  15:	c3                      ret
  16:	8d 7f ff                lea    edi,[rdi-0x1]
  19:	e8 00 00 00 00          call   1e <fibonacci+0x1e>
  1e:	89 c5                   mov    ebp,eax
  20:	8d 7b fe                lea    edi,[rbx-0x2]
  23:	e8 00 00 00 00          call   28 <fibonacci+0x28>
  28:	8d 5c 05 00             lea    ebx,[rbp+rax*1+0x0]
  2c:	eb df                   jmp    d <fibonacci+0xd>
```

要点：`n` 不再驻栈，直接住在 callee-saved 的 `ebx`（跨递归调用存活）；`rbp` 被"借"来做普通寄存器暂存 `fib(n-1)` 的结果（注意没有 `mov rbp,rsp`——它不是帧指针）；基线分支与递归分支汇合到同一段收尾（`jmp d`，跨跳跃 / 尾合并）。

## Erlang JIT 开关观察（解释器 flavor）

OTP 24+ 的 BEAM JIT 默认开启，且**没有运行时开关把它关掉**：`-no_jit` 会被静默忽略，`+JM*` 系列也不存在。官方唯一的正交机制是 emulator flavor——`erl -emu_flavor emu|jit|smp`（见 `erl(1)`），但发行版通常只打包了 `smp`（= JIT）这一个 flavor。所以「关 JIT」需要自己构建解释器：

```sh
# 1. 下载与系统同版本源码（本机 erts-16.1.2 → otp_src_28.1.tar.gz）
# 2. 配置：prefix 设为系统 OTP 根，让 beam.emu 默认 rootdir 指向系统库
./configure --prefix=/usr/lib/erlang
# 3. 在 erts/ 下只编译解释器 flavor（几分钟）
make ERL_TOP=$PWD FLAVOR=emu -j22
# 产物：bin/x86_64-pc-linux-gnu/beam.emu
```

直跑（不经 erl/erlexec，emulator 的 C 层强制要求 `BINDIR` 环境变量，`-root`/`-bindir` 是 init 参数、须放在 `--` 之后）：

```sh
BINDIR=/usr/lib/erlang/erts-16.1.2/bin \
  beam.emu -- -root /usr/lib/erlang -bindir $BINDIR \
    -noshell -pa . -eval 'fibonacci:main(), init:stop().'
```

用 `erlang:system_info(emu_flavor)` 验证（`emu` ↔ `jit`）。bench.sh 已支持：把 `beam.emu` 放进 PATH，或 `ERL_EMU_BIN=/path/to/beam.emu ./bench.sh`，表格自动多出「Erlang（无 JIT）」行。

本机实测：JIT 1.99s ↔ 解释器 2.93s（1.47x）。有意思的是解释器的 IPC（4.17）反而比 JIT（3.37）高——解释器主循环是规则、可预测的分支序列；JIT 省掉的是**指令数**（147 亿 vs 371 亿），不是猜测开销。

## 度量：CPU 分支预测失败率

Linux 上用 `perf` 的硬件计数器（macOS 用 Instruments 的 Branch Mispredictions 计数器，ARM 对应 PMU 事件 `br_mis_pred`）：

```sh
# 总览：cycles / instructions / branches / branch-misses，后两者之比即失败率
perf stat -e cycles,instructions,branches,branch-misses -- python3 fibonacci.py

# 定位：失败集中在哪些函数（-c 5000 = 每 5000 次失败取一个样本）
perf record -e branch-misses -c 5000 -- python3 fibonacci.py && perf report

# JIT/解释器代码的符号化：BEAM 可开 +JPperf 生成 perf map
# 混合架构 CPU（本机 cpu_core/cpu_atom）会跨核迁移，对比时用 taskset 固定核心
```

本仓库实测（taskset 固定 P-core、单次运行）：

| 运行                  | 用时    | 指令数     | 分支数    | 预测失败率 | IPC  |
|-----------------------|---------|------------|-----------|------------|------|
| Erlang（JIT）         | 1.96 s  | 147 亿     | 44 亿     | 0.09%      | 3.37 |
| Erlang（解释器）      | 2.95 s  | 371 亿     | 63 亿     | 0.30%      | 4.17 |
| Python 3.14           | 8.42 s  | 1874 亿    | 271 亿    | 0.12%      | 4.74 |
| C 循环，分支随机（对照）| 10.56 s | 237 亿     | 72 亿     | 23.16%     | 0.45 |
| C 循环，分支有序（对照）| 1.26 s  | 254 亿     | 72 亿     | 0.02%      | 4.30 |

结论：

- **Python 与 Erlang 的速度差不是分支预测**。两者失败率几乎相同（0.12% vs 0.09%），Python 慢 4.3x 是因为每条 fib 调用要执行 12.7 倍指令（字节码分发、动态类型检查、引用计数、PyLong 大整数运算）。失败率 0.1% 量级时，即使每次失败代价 ~15–20 周期，也只占总时间 ~2%。
- 对照组的 C 循环指令数相同，唯一区别是 `if` 结果随机/有序：失败率 23% vs 0.02%，时间差 8.4x、IPC 从 4.30 塌到 0.45。**这才是分支预测决定性能的场景**——数据相关的分支（如对随机键做二分查找、哈希表冲突链），而不是解释器/编译代码的规则分支。
- 顺带修正一个直觉：解释器循环（Python、Erlang 解释器）恰恰是预测器最容易吃透的规则分支序列，IPC 反而更高。
