;; sbcl --script fibonacci.lisp
;; Naive recursive fibonacci, same shape as the other implementations.
;; The fixnum declarations let SBCL compile the arithmetic to machine
;; integers, matching the statically-typed implementations (C int, Java
;; int, Go int64) instead of falling back to generic arithmetic.

(declaim (optimize (speed 3) (safety 0) (debug 0)))

(defun fibonacci (n)
  (declare (type fixnum n))
  (if (<= n 1)
      n
      (the fixnum (+ (fibonacci (the fixnum (- n 1)))
                     (fibonacci (the fixnum (- n 2)))))))

(dolist (n '(10 20 30 35 40))
  (format t "~d~%" (fibonacci n)))
