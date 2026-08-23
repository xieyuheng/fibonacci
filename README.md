# Fibonacci Benchmark

Naive recursive `fibonacci(40)` benchmark.

Run with `./bench.sh`.

| Language       | Time (s) | Slowness |
|----------------|----------|----------|
| C -O2          | 0.122    | 1.00     |
| WAT / Node.js  | 0.316    | 2.59     |
| Java           | 0.319    | 2.61     |
| Go             | 0.381    | 3.12     |
| Chez Scheme    | 0.566    | 4.64     |
| WAT / wasmtime | 0.661    | 5.42     |
| LuaJIT         | 0.731    | 5.99     |
| Node.js        | 0.811    | 6.65     |
| Erlang         | 1.977    | 16.19    |
| Ruby           | 6.437    | 52.73    |
| Lua            | 8.096    | 66.32    |
| Python         | 8.342    | 68.34    |
