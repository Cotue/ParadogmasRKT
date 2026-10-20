#lang racket

(require racket/contract
         "contracts.rkt"
         "catalog.rkt")

;; ==================================================
;; Modelos utilizados durante la generación de
;; combinaciones
;;
;; Una selección contiene toda la información
;; necesaria para que una combinación pueda ser
;; evaluada sin regresar al JSON origina
;; ==================================================


;; --------------------------------------------------
;; selection
;;
;; Representa la selección de exactamente un grupo
;; para un curso
;;
;; pending-corequisites permite validar posteriormente
;; la regla de correquisitos
;;
;; conflicts permite comprobar compatibilidad sin
;; recalcular horarios
;; --------------------------------------------------

(struct selection
  (course-code
   group-number
   career
   credits
   pending-corequisites
   conflicts)
  #:transparent)


;; --------------------------------------------------
;; combination
;;
;; Representa un conjunto de selecciones y el total
;; acumulado de créditos
;;
;; El generador será responsable de mantener:
;;
;; total-credits =
;; suma de los créditos de las selecciones
;; --------------------------------------------------

(struct combination
  (selections
   total-credits)
  #:transparent)


;; ==================================================
;; Interfaz pública
;; ==================================================

(provide
 (contract-out

  [struct selection
    ([course-code course-code/c]
     [group-number group-number/c]
     [career career-code/c]
     [credits credits/c]
     [pending-corequisites (listof course-code/c)]
     [conflicts (listof group-key?)])]

  [struct combination
    ([selections (listof selection?)]
     [total-credits credits/c])]))
