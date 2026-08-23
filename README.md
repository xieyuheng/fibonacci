# Fibonacci Benchmark

Naive recursive `fibonacci(40)` benchmark.

Run with `./bench.sh`.

| Language       | Time (s) | Slowness |
|----------------|----------|----------|
| C -O2          | 0.134    | 1.00     |
| WAT / Node.js  | 0.315    | 2.34     |
| Java           | 0.332    | 2.47     |
| Go             | 0.382    | 2.85     |
| Chez Scheme    | 0.572    | 4.26     |
| WAT / wasmtime | 0.648    | 4.82     |
| LuaJIT         | 0.755    | 5.62     |
| Node.js        | 0.822    | 6.12     |
| Ruby           | 6.388    | 47.56    |
| Erlang         | 6.975    | 51.93    |
| Lua            | 7.780    | 57.92    |
| Python         | 8.375    | 62.35    |
