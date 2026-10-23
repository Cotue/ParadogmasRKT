#lang racket

(provide
 (struct-out result-ok)
 (struct-out result-err)
 result?)

(struct result-ok (val) #:transparent)

(struct result-err (msg) #:transparent)

(define (result? value)
  (or (result-ok? value)
      (result-err? value)))
