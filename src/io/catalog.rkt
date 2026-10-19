#lang racket

(require "../models/types.rkt"
         "json_reader.rkt")

(provide
 (contract-out
  [read-catalog-json (-> path-string? result?)]))

(define (read-catalog-json filepath)
  (parse-and-validate-catalog filepath))
