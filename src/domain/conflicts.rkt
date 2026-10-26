#lang racket

(require racket/contract
         "../models/catalog.rkt"
         "../models/combination.rkt")

(provide
 (contract-out
  [selection-compatible?
   (-> selection?
       (listof selection?)
       boolean?)]))


;; Determina si una identidad de grupo corresponde
;; exactamente a una selección.
;;
;; Un grupo se identifica por:
;;   código de curso + número de grupo
(define (group-key-matches-selection? key sel)
  (and
   (string=?
    (group-key-course-code key)
    (selection-course-code sel))

   (=
    (group-key-group-number key)
    (selection-group-number sel))))


;; Determina si una lista de conflictos contiene
;; la identidad de una selección específica.
(define (conflicts-with-selection? conflicts sel)
  (cond
    [(null? conflicts)
     #f]

    [(group-key-matches-selection?
      (car conflicts)
      sel)
     #t]

    [else
     (conflicts-with-selection?
      (cdr conflicts)
      sel)]))


;; Determina si dos selecciones tienen un choque
;; explícito producido por C.
;;
;; Se revisan ambos sentidos como medida defensiva.
(define (selections-conflict? first-selection second-selection)
  (or
   (conflicts-with-selection?
    (selection-conflicts first-selection)
    second-selection)

   (conflicts-with-selection?
    (selection-conflicts second-selection)
    first-selection)))


;; Una selección candidata es compatible cuando
;; no entra en conflicto con ninguna selección
;; existente en la combinación parcial.
(define (selection-compatible? candidate existing-selections)
  (cond
    [(null? existing-selections)
     #t]

    [(selections-conflict?
      candidate
      (car existing-selections))
     #f]

    [else
     (selection-compatible?
      candidate
      (cdr existing-selections))]))
