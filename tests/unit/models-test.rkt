#lang racket

(require rackunit
         "../../src/models/catalog.rkt"
         "../../src/models/preferences.rkt"
         "../../src/models/combination.rkt")


;; ==================================================
;; group-key
;; ==================================================

(define conflict-key
  (group-key "MA2104" 2))

(check-true
 (group-key? conflict-key))

(check-equal?
 (group-key-course-code conflict-key)
 "MA2104")

(check-equal?
 (group-key-group-number conflict-key)
 2)


;; Un grupo no puede tener número 0.
(check-exn
 exn:fail:contract?
 (lambda ()
   (group-key "MA2104" 0)))


;; ==================================================
;; group-option
;; ==================================================

(define group-1
  (group-option
   1
   (list conflict-key)))

(check-true
 (group-option? group-1))

(check-equal?
 (group-option-number group-1)
 1)

(check-equal?
 (group-option-conflicts group-1)
 (list conflict-key))


;; conflicts debe contener group-key.
(check-exn
 exn:fail:contract?
 (lambda ()
   (group-option
    1
    (list "invalid-conflict"))))


;; ==================================================
;; course
;; ==================================================

(define course-a
  (course
   "CE2201"
   "IC"
   4
   #t
   (list "MA1102")
   (list group-1)))

(check-true
 (course? course-a))

(check-equal?
 (course-code course-a)
 "CE2201")

(check-equal?
 (course-credits course-a)
 4)

(check-true
 (course-can-enroll? course-a))

(check-equal?
 (course-pending-corequisites course-a)
 (list "MA1102"))


;; can-enroll? debe ser boolean.
(check-exn
 exn:fail:contract?
 (lambda ()
   (course
    "CE2201"
    "IC"
    4
    "yes"
    '()
    '())))


;; ==================================================
;; catalog
;; ==================================================

(define sample-catalog
  (catalog
   "2.0"
   "IC"
   (list course-a)))

(check-true
 (catalog? sample-catalog))

(check-equal?
 (catalog-schema-version sample-catalog)
 "2.0")

(check-equal?
 (catalog-career-code sample-catalog)
 "IC")

(check-equal?
 (catalog-courses sample-catalog)
 (list course-a))


;; ==================================================
;; candidate-course
;; ==================================================

(define candidate-a
  (candidate-course
   "CE2201"
   "IC"
   4
   (list "MA1102")
   (list group-1)))

(check-true
 (candidate-course? candidate-a))

(check-equal?
 (candidate-course-groups candidate-a)
 (list group-1))


;; Un candidato no puede tener créditos negativos.
(check-exn
 exn:fail:contract?
 (lambda ()
   (candidate-course
    "CE2201"
    "IC"
    -1
    '()
    '())))


;; ==================================================
;; course-preference
;; ==================================================

(define preference-a
  (course-preference
   "CE2201"
   (list 1 2)))

(check-true
 (course-preference? preference-a))

(check-equal?
 (course-preference-course-code preference-a)
 "CE2201")

(check-equal?
 (course-preference-allowed-groups preference-a)
 (list 1 2))


;; Los números de grupo deben ser positivos.
(check-exn
 exn:fail:contract?
 (lambda ()
   (course-preference
    "CE2201"
    (list 0))))


;; ==================================================
;; preferences
;; ==================================================

(define sample-preferences
  (preferences
   12
   18
   (list preference-a)))

(check-true
 (preferences? sample-preferences))

(check-equal?
 (preferences-min-credits sample-preferences)
 12)

(check-equal?
 (preferences-max-credits sample-preferences)
 18)

(check-equal?
 (preferences-courses sample-preferences)
 (list preference-a))


;; Créditos mínimos no pueden ser negativos.
(check-exn
 exn:fail:contract?
 (lambda ()
   (preferences
    -1
    18
    '())))


;; ==================================================
;; selection
;; ==================================================

(define selection-a
  (selection
   "CE2201"
   1
   "IC"
   4
   (list "MA1102")
   (list conflict-key)))

(check-true
 (selection? selection-a))

(check-equal?
 (selection-course-code selection-a)
 "CE2201")

(check-equal?
 (selection-group-number selection-a)
 1)

(check-equal?
 (selection-career selection-a)
 "IC")

(check-equal?
 (selection-credits selection-a)
 4)

(check-equal?
 (selection-pending-corequisites selection-a)
 (list "MA1102"))

(check-equal?
 (selection-conflicts selection-a)
 (list conflict-key))


;; conflicts debe contener group-key.
(check-exn
 exn:fail:contract?
 (lambda ()
   (selection
    "CE2201"
    1
    "IC"
    4
    '()
    (list "invalid-conflict"))))


;; ==================================================
;; combination
;; ==================================================

(define sample-combination
  (combination
   (list selection-a)
   4))

(check-true
 (combination? sample-combination))

(check-equal?
 (combination-selections sample-combination)
 (list selection-a))

(check-equal?
 (combination-total-credits sample-combination)
 4)


;; total-credits no puede ser negativo.
(check-exn
 exn:fail:contract?
 (lambda ()
   (combination
    (list selection-a)
    -4)))


;; selections solamente puede contener selection.
(check-exn
 exn:fail:contract?
 (lambda ()
   (combination
    (list "CE2201-G1")
    4)))
