#lang racket

(require racket/contract
         racket/contract/parametric
         racket/stream)

(provide
 stream-of/c
 (contract-out
  [stream-select
   (parametric->/c [A]
     (-> (-> A boolean?)
         (stream-of/c A)
         (stream-of/c A)))]))


(define (stream-of/c elem/c)
  (define elem-ctc (coerce-contract 'stream-of/c elem/c))
  (define elem-proj (contract-late-neg-projection elem-ctc))
  (make-contract
   #:name (build-compound-type-name 'stream-of/c elem-ctc)
   #:first-order stream?
   #:late-neg-projection
   (lambda (blame)
     (define check-elem (elem-proj (blame-add-context blame "un elemento del stream")))
     (lambda (val missing-party)
       (unless (stream? val)
         (raise-blame-error blame #:missing-party missing-party val
                            '(expected: "stream?" given: "~e") val))
       (let wrap ([s val])
         (stream-lazy
          (if (stream-empty? s)
              empty-stream
              (stream-cons (check-elem (stream-first s) missing-party)
                           (wrap (stream-rest s))))))))))

(define (stream-select predicate strm)
  (cond
    [(stream-empty? strm) empty-stream]
    [(predicate (stream-first strm))
     (stream-cons (stream-first strm)
                  (stream-select predicate (stream-rest strm)))]
    [else
     (stream-select predicate (stream-rest strm))]))
