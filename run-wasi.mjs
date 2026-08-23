// Minimal WASI preview1 driver for Node.js / V8.
// Runs a WASI "command" module (a wasm that exports `_start`).
//
// Usage:  node run-wasi.mjs module.wasm [args...]
import { readFile } from "node:fs/promises";
import { WASI } from "node:wasi";

const [, , wasmPath, ...args] = process.argv;

const wasi = new WASI({ version: "preview1", args: [wasmPath, ...args] });

const bytes = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes, {
  wasi_snapshot_preview1: wasi.wasiImport,
});

wasi.start(instance);