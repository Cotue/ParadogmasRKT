#lang racket

(require racket/contract
         "contracts.rkt")

;; ==================================================
;; Modelos relacionados con el catálogo.
;; ==================================================


;; --------------------------------------------------
;; group-key
;;
;; Identifica de forma única un grupo mediante:
;;
;;   código de curso + número de grupo
;;
;; Ejemplo:
;;   CE2201, grupo 2
;; --------------------------------------------------

(struct group-key
  (course-code
   group-number)
  #:transparent)


;; --------------------------------------------------
;; group-option
;;
;; Representa un grupo disponible de un curso.
;;
;; conflicts contiene las identidades de los grupos
;; incompatibles, ya calculadas previamente por C.
;; --------------------------------------------------

(struct group-option
  (number
   conflicts)
  #:transparent)


;; --------------------------------------------------
;; course
;;
;; Representa un curso recibido desde el catálogo.
;;
;; can-enroll? NO se recalcula aquí.
;;
;; pending-corequisites contiene solamente los
;; correquisitos que C determinó como pendientes.
;; --------------------------------------------------

(struct course
  (code
   career
   credits
   can-enroll?
   pending-corequisites
   groups)
  #:transparent)


;; --------------------------------------------------
;; catalog
;;
;; Representa el catálogo completo cargado.
;;
;; Una ejecución procesa una única carrera.
;; --------------------------------------------------

(struct catalog
  (schema-version
   career-code
   courses)
  #:transparent)


;; --------------------------------------------------
;; candidate-course
;;
;; Representa un curso que ya superó la construcción
;; de candidatos.
;;
;; Si un valor es candidate-course, se asume que:
;;
;;   can-enroll? = #t
;;
;; y que groups contiene únicamente los grupos
;; permitidos por las preferencias.
;; --------------------------------------------------

(struct candidate-course
  (code
   career
   credits
   pending-corequisites
   groups)
  #:transparent)


;; ==================================================
;; Interfaz pública
;; ==================================================

(provide
 (contract-out

  [struct group-key
    ([course-code course-code/c]
     [group-number group-number/c])]

  [struct group-option
    ([number group-number/c]
     [conflicts (listof group-key?)])]

  [struct course
    ([code course-code/c]
     [career career-code/c]
     [credits credits/c]
     [can-enroll? boolean?]
     [pending-corequisites (listof course-code/c)]
     [groups (listof group-option?)])]

  [struct catalog
    ([schema-version string?]
     [career-code career-code/c]
     [courses (listof course?)])]

  [struct candidate-course
    ([code course-code/c]
     [career career-code/c]
     [credits credits/c]
     [pending-corequisites (listof course-code/c)]
     [groups (listof group-option?)])]))
