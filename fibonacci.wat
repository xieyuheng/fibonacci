;; Hand-written WebAssembly (WAT) naive recursive fibonacci.
;; A WASI "command" module: `_start` prints fib(10), fib(20), fib(30),
;; fib(35), fib(40), one per line, matching the other implementations.
;;
;; Assemble with:  wat2wasm fibonacci.wat -o fibonacci.wasm
;; Run with:       wasmtime fibonacci.wasm
;;                 node tools/run-wasi.mjs fibonacci.wasm

(module
  ;; WASI preview1: fd_write(fd, iovs, iovs_len, nwritten) -> errno
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param $fd i32) (param $iovs i32) (param $iovs_len i32) (param $nwritten i32) (result i32)))

  (memory (export "memory") 1)

  ;; memory layout:
  ;;   iovs[0] at 0..7    {ptr, len} -> fibonacci digits
  ;;   iovs[1] at 8..15   {ptr, len} -> newline
  ;;   nwritten at 16..19
  ;;   digit buffer: digits written backwards, last digit ends at 40
  ;;   newline at 64
  (data (i32.const 64) "\n")

  ;; naive recursive fibonacci
  (func $fib (param $n i32) (result i32)
    (if (result i32) (i32.lt_u (local.get $n) (i32.const 2))
      (then (local.get $n))
      (else
        (i32.add
          (call $fib (i32.sub (local.get $n) (i32.const 1)))
          (call $fib (i32.sub (local.get $n) (i32.const 2)))))))

  ;; write n as decimal digits backwards, ending just before $end;
  ;; returns the number of digits written (start = $end - len)
  (func $i32_to_str (param $n i32) (param $end i32) (result i32)
    (local $pos i32)
    (local.set $pos (local.get $end))
    (block $done
      (loop $again
        (local.set $pos (i32.sub (local.get $pos) (i32.const 1)))
        (i32.store8 (local.get $pos)
          (i32.add (i32.const 48)
            (i32.rem_u (local.get $n) (i32.const 10))))
        (local.set $n (i32.div_u (local.get $n) (i32.const 10)))
        (br_if $done (i32.eqz (local.get $n)))
        (br $again)))
    (i32.sub (local.get $end) (local.get $pos)))

  ;; print "fib(n)\n" to stdout
  (func $print_fib (param $n i32)
    (local $len i32)
    (local $start i32)
    (local.set $len (call $i32_to_str (call $fib (local.get $n)) (i32.const 40)))
    (local.set $start (i32.sub (i32.const 40) (local.get $len)))
    ;; iovs[0] = { start, len }
    (i32.store (i32.const 0) (local.get $start))
    (i32.store (i32.const 4) (local.get $len))
    ;; iovs[1] = { 64, 1 }  ("\n")
    (i32.store (i32.const 8) (i32.const 64))
    (i32.store (i32.const 12) (i32.const 1))
    ;; fd_write(1 /*stdout*/, iovs, 2, &nwritten)
    (drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 2) (i32.const 16))))

  (func $main
    (call $print_fib (i32.const 10))
    (call $print_fib (i32.const 20))
    (call $print_fib (i32.const 30))
    (call $print_fib (i32.const 35))
    (call $print_fib (i32.const 40)))

  (export "_start" (func $main)))