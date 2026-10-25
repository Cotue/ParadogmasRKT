#lang racket

(require racket/contract
         "../models/catalog.rkt"
         "../models/preferences.rkt")

(provide
 (contract-out
  [build-candidates
   (-> catalog?
       preferences?
       (listof candidate-course?))]))


;; Busca un curso por código dentro del catálogo.
;; Las preferencias ya fueron validadas, por lo que
;; normalmente el curso siempre debe existir.
(define (find-course code courses)
  (cond
    [(null? courses) #f]
    [(string=? code
               (course-code (car courses)))
     (car courses)]
    [else
     (find-course code
                  (cdr courses))]))


;; Busca un grupo por número dentro de un curso.
(define (find-group number groups)
  (cond
    [(null? groups) #f]
    [(= number
        (group-option-number (car groups)))
     (car groups)]
    [else
     (find-group number
                 (cdr groups))]))


;; Construye la lista de grupos siguiendo el orden
;; indicado explícitamente en las preferencias.
;;
;; Se reutilizan los group-option originales para
;; conservar sus referencias de conflictos.
(define (allowed-groups course allowed-group-numbers)
  (cond
    [(null? allowed-group-numbers)
     '()]
    [else
     (cons
      (find-group
       (car allowed-group-numbers)
       (course-groups course))

      (allowed-groups
       course
       (cdr allowed-group-numbers)))]))


;; Convierte un curso elegible + su preferencia
;; en el modelo canónico candidate-course.
(define (course->candidate course preference)
  (candidate-course
   (course-code course)
   (course-career course)
   (course-credits course)
   (course-pending-corequisites course)
   (allowed-groups
    course
    (course-preference-allowed-groups preference))))


;; Catalog + Preferences -> CandidateCourse[]
;;
;; Se recorren las preferencias, no el catálogo,
;; porque ellas determinan tanto los cursos de interés
;; como el orden determinista de los resultados.
(define (build-candidates cat prefs)

  (define courses
    (catalog-courses cat))

  (define (loop remaining-preferences)
    (cond
      [(null? remaining-preferences)
       '()]

      [else
       (define preference
         (car remaining-preferences))

       (define catalog-course
         (find-course
          (course-preference-course-code preference)
          courses))

       (if (and catalog-course
                (course-can-enroll? catalog-course))

           (cons
            (course->candidate
             catalog-course
             preference)

            (loop
             (cdr remaining-preferences)))

           (loop
            (cdr remaining-preferences)))]))

  (loop
   (preferences-courses prefs)))
