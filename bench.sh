#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Some JDK installs (e.g. /usr/lib/jvm/*/bin) are not on minimal PATHs.
if ! command -v javac >/dev/null 2>&1; then
  for d in /usr/lib/jvm/*/bin; do
    if [[ -x "$d/javac" ]]; then
      export PATH="$d:$PATH"
      break
    fi
  done
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

bench() {
  local name="$1"; shift
  local start end diff
  start=$(date +%s%N)
"$@" >/dev/null 2>&1 </dev/null
  end=$(date +%s%N)
  diff=$((end - start))
  echo "$name $diff"
}

RESULTS=()

build() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    return 0
  fi
  echo "SKIP_BUILD $name"
  return 1
}

# C -O2 (baseline)
if gcc -O2 -o "$WORK/fibonacci_c" fibonacci.c 2>/dev/null; then
  RESULTS+=("$(bench "C -O2" "$WORK/fibonacci_c")")
else
  echo "ERROR: gcc -O2 build failed"
  exit 1
fi

# C -O0 / C -O1 (same source, other optimization levels)
for opt in 0 1; do
  if gcc -O$opt -o "$WORK/fibonacci_c_O$opt" fibonacci.c 2>/dev/null; then
    RESULTS+=("$(bench "C -O$opt" "$WORK/fibonacci_c_O$opt")")
  else
    RESULTS+=("SKIP_BUILD C -O$opt")
  fi
done

# Go
if go build -o "$WORK/fibonacci_go" fibonacci.go 2>/dev/null; then
  RESULTS+=("$(bench "Go" "$WORK/fibonacci_go")")
else
  RESULTS+=("SKIP_BUILD Go")
fi

# Java
if command -v javac >/dev/null 2>&1 && javac -d "$WORK" fibonacci.java 2>/dev/null; then
  RESULTS+=("$(bench "Java" java -cp "$WORK" fibonacci)")
else
  RESULTS+=("SKIP_BUILD Java")
fi

# Erlang
if erlc -o "$WORK" fibonacci.erl 2>/dev/null; then
  RESULTS+=("$(bench "Erlang" erl -noshell -pa "$WORK" -eval 'fibonacci:main(), init:stop().')")
else
  RESULTS+=("SKIP_BUILD Erlang")
fi

# Erlang 无 JIT（解释器 flavor）——需要预先构建 beam.emu，见 README 相应章节。
# 用环境变量 ERL_EMU_BIN 指定 beam.emu 路径，或把它放进 PATH。
ERL_EMU_BIN="${ERL_EMU_BIN:-$(command -v beam.emu 2>/dev/null || true)}"
if [ -n "$ERL_EMU_BIN" ]; then
  ERL_ROOT=$(erl -noshell -eval 'io:format("~s", [code:root_dir()]), init:stop().' 2>/dev/null)
  ERL_BINDIR=$(ls -d "$ERL_ROOT"/erts-*/bin 2>/dev/null | head -1)
  if [ -n "$ERL_BINDIR" ]; then
    RESULTS+=("$(bench "Erlang (no JIT)" env BINDIR="$ERL_BINDIR" "$ERL_EMU_BIN" -- -root "$ERL_ROOT" -bindir "$ERL_BINDIR" -noshell -pa "$WORK" -eval 'fibonacci:main(), init:stop().')")
  else
    echo "SKIP Erlang (no JIT): 找不到 erl 的 erts bin 目录"
  fi
else
  echo "SKIP Erlang (no JIT): 未找到 beam.emu，可用环境变量 ERL_EMU_BIN 指定路径"
fi

# Node.js
RESULTS+=("$(bench "Node.js" node fibonacci.js)")

# Lua
RESULTS+=("$(bench "Lua" lua fibonacci.lua)")

# LuaJIT
if command -v luajit >/dev/null 2>&1; then
  RESULTS+=("$(bench "LuaJIT" luajit fibonacci.lua)")
else
  RESULTS+=("SKIP_BUILD LuaJIT")
fi

# Python
RESULTS+=("$(bench "Python" python3 fibonacci.py)")

# Ruby
RESULTS+=("$(bench "Ruby" ruby fibonacci.rb)")

# Chez Scheme
if command -v chez-scheme >/dev/null 2>&1; then
  RESULTS+=("$(bench "Chez Scheme" chez-scheme --script fibonacci.scm)")
else
  RESULTS+=("SKIP_BUILD Chez Scheme")
fi

# MIT Scheme (native-compiled .bci/.so via compile-file; loading the source
# directly would run the interpreter and be far slower)
if command -v mit-scheme >/dev/null 2>&1; then
  cp fibonacci.scm "$WORK/fibonacci.scm"
  if (cd "$WORK" && mit-scheme --batch-mode --eval '(compile-file "fibonacci.scm")' >/dev/null 2>&1 </dev/null); then
    RESULTS+=("$(bench "MIT Scheme" mit-scheme --batch-mode --load "$WORK/fibonacci")")
  else
    RESULTS+=("SKIP_BUILD MIT Scheme (compile-file failed)")
  fi
else
  RESULTS+=("SKIP_BUILD MIT Scheme")
fi

# SBCL
if command -v sbcl >/dev/null 2>&1; then
  RESULTS+=("$(bench "SBCL" sbcl --script fibonacci.lisp)")
else
  RESULTS+=("SKIP_BUILD SBCL")
fi

# Emacs Lisp (byte-compiled .elc, not the interpreter)
if command -v emacs >/dev/null 2>&1; then
  cp fibonacci.el "$WORK/fibonacci.el"
  if emacs --batch -f batch-byte-compile "$WORK/fibonacci.el" >/dev/null 2>&1; then
    RESULTS+=("$(bench "Emacs Lisp" emacs --batch --script "$WORK/fibonacci.elc")")
  else
    RESULTS+=("SKIP_BUILD Emacs Lisp")
  fi
else
  RESULTS+=("SKIP_BUILD Emacs Lisp")
fi

# WAT (hand-written WebAssembly in fibonacci.wat)
if command -v wat2wasm >/dev/null 2>&1 && wat2wasm -o "$WORK/fibonacci_wat.wasm" fibonacci.wat 2>/dev/null; then
  if command -v wasmtime >/dev/null 2>&1; then
    RESULTS+=("$(bench "WAT / wasmtime" wasmtime run --disable-cache "$WORK/fibonacci_wat.wasm")")
  else
    RESULTS+=("SKIP_BUILD WAT / wasmtime")
  fi
  if command -v node >/dev/null 2>&1; then
    RESULTS+=("$(bench "WAT / Node.js" node run-wasi.mjs "$WORK/fibonacci_wat.wasm")")
  else
    RESULTS+=("SKIP_BUILD WAT / Node.js")
  fi
else
  RESULTS+=("SKIP_BUILD WAT (no wat2wasm)")
fi

python3 - "${RESULTS[@]}" <<'EOF'
import sys

_, *results = sys.argv
data = []
for r in results:
    if r.startswith("SKIP_BUILD "):
        data.append((r[len("SKIP_BUILD "):], None, None))
    else:
        name, ns = r.rsplit(" ", 1)
        data.append((name, int(ns) / 1e9, int(ns)))

data.sort(key=lambda x: (x[2] if x[2] is not None else float("inf")))

c_time = next((t for n, t, _ in data if n == "C -O0"), None)

cc_labels = {
    "C -O0": "C -O0（朴素递归）",
    "C -O1": "C -O1（寄存器分配）",
    "C -O2": "C -O2（迭代化）",
    "Erlang (no JIT)": "Erlang（无 JIT）",
}

lines = []
lines.append("# Fibonacci Benchmark")
lines.append("")
lines.append("Same-source naive recursive `fibonacci(40)` across languages;")
lines.append("the C rows are one `fibonacci.c` compiled at different `-O` levels.")
lines.append("")
lines.append("Run with `./bench.sh`.")
lines.append("")
lines.append("| 语言 | 用时（秒） | 相对用时 |")
lines.append("|---|---|---|")
for name, t, ns in data:
    label = cc_labels.get(name, name)
    if t is None:
        lines.append(f"| {label} | skipped (no toolchain) | - |")
    else:
        rel = t / c_time
        lines.append(f"| {label} | {t:.3f} | {rel:.2f} |")

lines.append("")
lines.append("## C 优化级别观察（gcc，同一份 `fibonacci.c`）")
lines.append("")
lines.append("- **C -O0** — 变量全驻栈、寄存器仅做单语句内的临时搬运；忠实于源码的朴素递归，便于调试。")
lines.append("- **C -O1** — 生命周期感知的寄存器分配：`n` 住进 callee-saved 寄存器跨递归调用存活；调用次数不变，单次调用变轻。")
lines.append("- **C -O2** — 编译器着手改写算法：树形递归被改写成奇偶拆分的迭代循环，调用次数降一个数量级以上。")

print("\n".join(lines))
EOF