;; -*- lexical-binding: t -*-
;; Naive recursive fibonacci, same shape as the other implementations.
;; Byte-compile and run with:
;;   emacs --batch -f batch-byte-compile fibonacci.el
;;   emacs --batch --script fibonacci.elc

(defun fibonacci (n)
  (if (<= n 1)
      n
    (+ (fibonacci (- n 1)) (fibonacci (- n 2)))))

(dolist (n '(10 20 30 35 40))
  (princ (fibonacci n))
  (terpri))