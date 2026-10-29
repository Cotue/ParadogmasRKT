#lang racket

(require racket/contract
         "contracts.rkt")

;; ==================================================
;; La validación de existencia de cursos, existencia
;; de grupos, duplicados o min <= max pertenece al
;; preferences-reader
;; ==================================================


;; --------------------------------------------------
;; course-preference
;;
;; Representa un curso de interés y los grupos que
;; el estudiante acepta considerar
;; --------------------------------------------------

(struct course-preference
  (course-code
   allowed-groups)
  #:transparent)


;; --------------------------------------------------
;; preferences
;;
;; Representa todas las preferencias para una
;; ejecución
;; --------------------------------------------------

(struct preferences
  (min-credits
   max-credits
   courses)
  #:transparent)


;; ==================================================
;; Interfaz pública
;; ==================================================

(provide
 (contract-out

  [struct course-preference
    ([course-code course-code/c]
     [allowed-groups (listof group-number/c)])]

  [struct preferences
    ([min-credits credits/c]
     [max-credits credits/c]
     [courses (listof course-preference?)])]))
