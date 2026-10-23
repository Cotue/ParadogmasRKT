#lang racket

(require "result.rkt")

(provide valid-days
         day?
         (struct-out schedule)
         (struct-out group-conflict)
         (struct-out group)
         (struct-out course)
         (struct-out catalog)
         (all-from-out "result.rkt"))

(define valid-days '(LUN MAR MIE JUE VIE SAB))

(define (day? x)
  (and (symbol? x)
       (member x valid-days)
       #t))

(struct schedule
  (day start end)
  #:transparent)

(struct group-conflict
  (course-code group-number)
  #:transparent)

(struct group
  (number schedules has-conflict conflicts)
  #:transparent)

(struct course
  (code
   name
   credits
   semester
   carrera
   requirements
   corequisites
   pending-corequisites
   groups
   has-conflict
   can-enroll)
  #:transparent)

(struct catalog
  (schema-version
   career-code
   career-name
   courses)
  #:transparent)
