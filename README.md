# Fibonacci Benchmark

同一份源码的朴素递归 `fibonacci(40)` 跨语言基准测试；C 行是同一份 `fibonacci.c` 在不同优化级别（`-O0/-O1/-O2`）下的编译结果。

- 运行 `./bench.sh` 重新测量，结果只打印到终端，不再改写本 README。
- 下表为手工维护的静态数据（本机一次运行、单次墙钟计时，含进程启动开销；单次测量存在负载噪声，重跑后请手动更新本表）。

| 语言                | 用时（秒） | 相对用时 |
|---------------------|------------|----------|
| C -O2（迭代化）     | 0.133      | 0.21     |
| WAT / Node.js       | 0.322      | 0.51     |
| Java                | 0.331      | 0.53     |
| Go                  | 0.387      | 0.62     |
| C -O1（寄存器分配） | 0.446      | 0.71     |
| Chez Scheme         | 0.570      | 0.91     |
| C -O0（朴素递归）   | 0.625      | 1.00     |
| WAT / wasmtime      | 0.666      | 1.07     |
| LuaJIT              | 0.741      | 1.19     |
| Node.js             | 0.822      | 1.32     |
| Erlang              | 1.977      | 3.16     |
| Ruby                | 6.516      | 10.43    |
| Lua                 | 7.831      | 12.53    |
| Python              | 8.527      | 13.65    |

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
