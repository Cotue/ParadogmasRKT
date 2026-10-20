#lang racket

(require racket/contract
         racket/string)

(provide course-code/c
         career-code/c
         group-number/c
         credits/c)

;; Devuelve #t cuando value es un String que contiene
;; al menos un carácter distinto de espacio en blanco.
(define (non-blank-string? value)
  (and (string? value)
       (not (string=? (string-trim value) ""))))

;; Código de curso válido a nivel estructural.
;;
;; Este contrato únicamente garantiza que sea un
;; String no vacío. La validación de si el curso
;; existe pertenece a los módulos de entrada.
(define course-code/c
  (flat-named-contract
   'course-code/c
   non-blank-string?))

;; Código de carrera válido a nivel estructural.
;;
;; No restringe todavía a códigos concretos como
;; "IC" o "IE"; esa validación pertenece al reader
;; encargado del contrato externo del catálogo.
(define career-code/c
  (flat-named-contract
   'career-code/c
   non-blank-string?))

;; Los números de grupo deben ser enteros exactos
;; estrictamente mayores que cero.
(define group-number/c
  (flat-named-contract
   'group-number/c
   (lambda (value)
     (and (exact-integer? value)
          (positive? value)))))

;; Los créditos se representan mediante enteros
;; exactos no negativos.
(define credits/c
  (flat-named-contract
   'credits/c
   exact-nonnegative-integer?))
