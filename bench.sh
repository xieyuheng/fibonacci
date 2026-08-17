#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

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

python3 - "${RESULTS[@]}" <<'EOF'
import sys

_, *results = sys.argv
data = []
for r in results:
    name, ns = r.rsplit(" ", 1)
    if name == "SKIP_BUILD":
        data.append((ns, None, None))
    else:
        data.append((name, int(ns) / 1e9, int(ns)))

data.sort(key=lambda x: (x[2] if x[2] is not None else float("inf")))

c_time = next((t for n, t, _ in data if n == "C -O2"), None)

lines = []
lines.append("# Fibonacci Benchmark")
lines.append("")
lines.append("Naive recursive `fibonacci(40)` benchmark.")
lines.append("")
lines.append("Run with `./bench.sh`.")
lines.append("")
lines.append("| Language | Time (s) | Slowness |")
lines.append("|---|---|---|")
for name, t, ns in data:
    if t is None:
        lines.append(f"| {name} | skipped (no toolchain) | - |")
    else:
        slowness = t / c_time
        lines.append(f"| {name} | {t:.3f} | {slowness:.2f} |")

with open("README.md", "w") as f:
    f.write("\n".join(lines) + "\n")

print("\n".join(lines))
EOF