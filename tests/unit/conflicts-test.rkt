#lang racket

(require rackunit
         "../../src/models/catalog.rkt"
         "../../src/models/combination.rkt"
         "../../src/domain/conflicts.rkt")


;; ==================================================
;; Helpers
;; ==================================================

;; Construye una selección simple para las pruebas.
;; Los campos que no pertenecen a la regla de choques
;; utilizan valores válidos pero neutrales.
(define (make-test-selection code
                             group
                             #:conflicts [conflicts '()]
                             #:career [career "IC"]
                             #:credits [credits 3]
                             #:pending [pending '()])
  (selection
   code
   group
   career
   credits
   pending
   conflicts))


;; ==================================================
;; TC-01
;; Lista parcial vacía.
;; ==================================================

(test-case
 "Una selección es compatible con una combinación parcial vacía"

 (define candidate
   (make-test-selection "A" 1))

 (check-true
  (selection-compatible?
   candidate
   '())))


;; ==================================================
;; TC-02
;; Dos selecciones sin choque.
;; ==================================================

(test-case
 "Dos selecciones sin conflicto son compatibles"

 (define candidate
   (make-test-selection "A" 1))

 (define existing
   (make-test-selection "B" 2))

 (check-true
  (selection-compatible?
   candidate
   (list existing))))


;; ==================================================
;; TC-03
;; Choque directo declarado por la candidata.
;; ==================================================

(test-case
 "Un conflicto declarado por la selección candidata devuelve falso"

 (define candidate
   (make-test-selection
    "A"
    1
    #:conflicts
    (list
     (group-key "B" 2))))

 (define existing
   (make-test-selection "B" 2))

 (check-false
  (selection-compatible?
   candidate
   (list existing))))


;; ==================================================
;; TC-04
;; Choque declarado únicamente en sentido inverso.
;; ==================================================

(test-case
 "Un conflicto declarado por una selección existente devuelve falso"

 (define candidate
   (make-test-selection "A" 1))

 (define existing
   (make-test-selection
    "B"
    2
    #:conflicts
    (list
     (group-key "A" 1))))

 (check-false
  (selection-compatible?
   candidate
   (list existing))))


;; ==================================================
;; TC-05
;; Varias selecciones sin conflictos.
;; ==================================================

(test-case
 "Una candidata compatible con varias selecciones devuelve verdadero"

 (define candidate
   (make-test-selection "A" 1))

 (define partial
   (list
    (make-test-selection "B" 1)
    (make-test-selection "C" 2)
    (make-test-selection "D" 3)))

 (check-true
  (selection-compatible?
   candidate
   partial)))


;; ==================================================
;; TC-06
;; Varias selecciones y una sola produce choque.
;; ==================================================

(test-case
 "Un solo choque dentro de varias selecciones vuelve incompatible la candidata"

 (define candidate
   (make-test-selection
    "A"
    1
    #:conflicts
    (list
     (group-key "C" 2))))

 (define partial
   (list
    (make-test-selection "B" 1)
    (make-test-selection "C" 2)
    (make-test-selection "D" 3)))

 (check-false
  (selection-compatible?
   candidate
   partial)))


;; ==================================================
;; TC-07
;; Mismo número de grupo en cursos distintos.
;; ==================================================

(test-case
 "El mismo número de grupo en cursos distintos no implica choque"

 (define candidate
   (make-test-selection "A" 1))

 (define existing
   (make-test-selection "B" 1))

 (check-true
  (selection-compatible?
   candidate
   (list existing))))


;; ==================================================
;; TC-08
;; Mismo curso, grupos distintos sin conflicto
;; explícito.
;;
;; La regla de un grupo por curso pertenece al
;; generador, no a conflicts.rkt.
;; ==================================================

(test-case
 "Grupos distintos del mismo curso no chocan sin una referencia explícita"

 (define candidate
   (make-test-selection "A" 1))

 (define existing
   (make-test-selection "A" 2))

 (check-true
  (selection-compatible?
   candidate
   (list existing))))


;; ==================================================
;; TC-09
;; No modifica la selección candidata.
;; ==================================================

(test-case
 "selection-compatible? no modifica la selección candidata"

 (define candidate
   (make-test-selection
    "A"
    1
    #:conflicts
    (list
     (group-key "B" 2))))

 (define expected-candidate
   (make-test-selection
    "A"
    1
    #:conflicts
    (list
     (group-key "B" 2))))

 (define existing
   (make-test-selection "B" 2))

 (selection-compatible?
  candidate
  (list existing))

 (check-equal?
  candidate
  expected-candidate))


;; ==================================================
;; TC-10
;; No modifica la lista parcial.
;; ==================================================

(test-case
 "selection-compatible? no modifica las selecciones existentes"

 (define candidate
   (make-test-selection "A" 1))

 (define partial
   (list
    (make-test-selection "B" 1)
    (make-test-selection "C" 2)))

 (define expected-partial
   (list
    (make-test-selection "B" 1)
    (make-test-selection "C" 2)))

 (selection-compatible?
  candidate
  partial)

 (check-equal?
  partial
  expected-partial))
