#lang racket

(require rackunit
         "../../src/models/catalog.rkt"
         "../../src/models/preferences.rkt"
         "../../src/domain/candidates.rkt")


;; ==================================================
;; Helpers
;; ==================================================

(define (pref code groups)
  (course-preference code groups))

(define (prefs . course-prefs)
  (preferences 0 20 course-prefs))


;; ==================================================
;; Fixtures
;; ==================================================

;; El catálogo base contiene:
;;
;; A -> matriculable, 4 créditos, pendiente B,
;;      grupos 1, 2 y 3.
;;
;; B -> NO matriculable.
;;
;; C -> matriculable, 2 créditos,
;;      pendientes A y B.
;;
;; Los conflictos permiten comprobar que
;; build-candidates conserva los group-option
;; completos y no solo sus números.

(define (make-base-catalog)
  (catalog
   "2.0"
   "IC"
   (list

    (course
     "A"
     "IC"
     4
     #t
     '("B")
     (list
      (group-option
       1
       (list (group-key "B" 1)))

      (group-option
       2
       '())

      (group-option
       3
       (list (group-key "C" 1)))))

    (course
     "B"
     "IC"
     3
     #f
     '()
     (list
      (group-option
       1
       (list (group-key "A" 1)))))

    (course
     "C"
     "IC"
     2
     #t
     '("A" "B")
     (list
      (group-option
       1
       (list (group-key "A" 3))))))))


;; ==================================================
;; TC-01
;; Curso de interés elegible produce candidato
;; y conserva su información.
;; ==================================================

(test-case
 "Curso elegible de interés produce un candidato"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "A" '(1))))

 (check-equal?
  (build-candidates cat ps)

  (list
   (candidate-course
    "A"
    "IC"
    4
    '("B")
    (list
     (group-option
      1
      (list (group-key "B" 1))))))))


;; ==================================================
;; TC-02
;; Curso con can-enroll? = #f se excluye.
;; ==================================================

(test-case
 "Curso no matriculable se excluye"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "B" '(1))))

 (check-equal?
  (build-candidates cat ps)
  '()))


;; ==================================================
;; TC-03
;; Curso fuera de preferencias no aparece.
;; ==================================================

(test-case
 "Solo se incluyen cursos de interés"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "C" '(1))))

 (check-equal?
  (map candidate-course-code
       (build-candidates cat ps))

  '("C")))


;; ==================================================
;; TC-04
;; Solo se conservan grupos permitidos.
;; ==================================================

(test-case
 "Solo se conservan grupos permitidos por preferencias"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "A" '(1 3))))

 (define candidate
   (first (build-candidates cat ps)))

 (check-equal?
  (map group-option-number
       (candidate-course-groups candidate))

  '(1 3)))


;; ==================================================
;; TC-05
;; El orden de grupos viene de preferencias.
;; ==================================================

(test-case
 "Se preserva el orden de grupos de las preferencias"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "A" '(3 1))))

 (define candidate
   (first (build-candidates cat ps)))

 (check-equal?
  (map group-option-number
       (candidate-course-groups candidate))

  '(3 1)))


;; ==================================================
;; TC-06
;; El orden de cursos viene de preferencias.
;; ==================================================

(test-case
 "Se preserva el orden de cursos de las preferencias"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "C" '(1))
    (pref "A" '(1))))

 (check-equal?
  (map candidate-course-code
       (build-candidates cat ps))

  '("C" "A")))


;; ==================================================
;; TC-07
;; Los conflictos de los grupos se conservan.
;; ==================================================

(test-case
 "Se conservan las referencias de conflictos"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "A" '(3))))

 (define candidate
   (first (build-candidates cat ps)))

 (define selected-group
   (first (candidate-course-groups candidate)))

 (check-equal?
  (group-option-conflicts selected-group)

  (list
   (group-key "C" 1))))


;; ==================================================
;; TC-08
;; Los correquisitos pendientes se conservan.
;; ==================================================

(test-case
 "Se conservan los correquisitos pendientes"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "C" '(1))))

 (define candidate
   (first (build-candidates cat ps)))

 (check-equal?
  (candidate-course-pending-corequisites candidate)

  '("A" "B")))


;; ==================================================
;; TC-09
;; Un curso no matriculable se elimina sin alterar
;; el orden de los demás.
;; ==================================================

(test-case
 "Excluir un curso no matriculable preserva el orden restante"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "A" '(1))
    (pref "B" '(1))
    (pref "C" '(1))))

 (check-equal?
  (map candidate-course-code
       (build-candidates cat ps))

  '("A" "C")))


;; ==================================================
;; TC-10
;; Ningún candidato elegible produce lista vacía.
;; ==================================================

(test-case
 "Sin cursos elegibles se obtiene lista vacía"

 (define cat
   (catalog
    "2.0"
    "IC"
    (list
     (course
      "D"
      "IC"
      4
      #f
      '()
      (list
       (group-option 1 '())))

     (course
      "E"
      "IC"
      3
      #f
      '()
      (list
       (group-option 1 '()))))))

 (define ps
   (prefs
    (pref "D" '(1))
    (pref "E" '(1))))

 (check-equal?
  (build-candidates cat ps)
  '()))


;; ==================================================
;; TC-11
;; No modifica Catalog.
;; ==================================================

(test-case
 "build-candidates no modifica el catálogo"

 (define cat
   (make-base-catalog))

 (define expected-cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "A" '(3 1))
    (pref "C" '(1))))

 (build-candidates cat ps)

 (check-equal?
  cat
  expected-cat))


;; ==================================================
;; TC-12
;; No modifica Preferences.
;; ==================================================

(test-case
 "build-candidates no modifica las preferencias"

 (define cat
   (make-base-catalog))

 (define ps
   (prefs
    (pref "C" '(1))
    (pref "A" '(3 1))))

 (define expected-ps
   (prefs
    (pref "C" '(1))
    (pref "A" '(3 1))))

 (build-candidates cat ps)

 (check-equal?
  ps
  expected-ps))
