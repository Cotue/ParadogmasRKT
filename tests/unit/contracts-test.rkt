#lang racket

(require rackunit
         racket/contract
         "../../src/models/contracts.rkt")

;; --------------------------------------------------
;; course-code/c
;; --------------------------------------------------

(check-equal?
 (contract course-code/c
           "CE2201"
           'contracts-test
           'caller)
 "CE2201")

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract course-code/c
             ""
             'contracts-test
             'caller)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract course-code/c
             "   "
             'contracts-test
             'caller)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract course-code/c
             2201
             'contracts-test
             'caller)))

;; --------------------------------------------------
;; career-code/c
;; --------------------------------------------------

(check-equal?
 (contract career-code/c
           "IC"
           'contracts-test
           'caller)
 "IC")

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract career-code/c
             ""
             'contracts-test
             'caller)))

;; --------------------------------------------------
;; group-number/c
;; --------------------------------------------------

(check-equal?
 (contract group-number/c
           1
           'contracts-test
           'caller)
 1)

(check-equal?
 (contract group-number/c
           10
           'contracts-test
           'caller)
 10)

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract group-number/c
             0
             'contracts-test
             'caller)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract group-number/c
             -1
             'contracts-test
             'caller)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract group-number/c
             1.5
             'contracts-test
             'caller)))

;; --------------------------------------------------
;; credits/c
;; --------------------------------------------------

(check-equal?
 (contract credits/c
           0
           'contracts-test
           'caller)
 0)

(check-equal?
 (contract credits/c
           4
           'contracts-test
           'caller)
 4)

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract credits/c
             -1
             'contracts-test
             'caller)))

(check-exn
 exn:fail:contract?
 (lambda ()
   (contract credits/c
             3.5
             'contracts-test
             'caller)))
