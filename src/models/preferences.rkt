#lang racket

(require racket/contract
         "contracts.rkt")




(struct course-preference
  (course-code
   allowed-groups)
  #:transparent)



(struct preferences
  (min-credits
   max-credits
   courses)
  #:transparent)



(provide
 (contract-out

  [struct course-preference
    ([course-code course-code/c]
     [allowed-groups (listof group-number/c)])]

  [struct preferences
    ([min-credits credits/c]
     [max-credits credits/c]
     [courses (listof course-preference?)])]))
