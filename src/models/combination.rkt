#lang racket

(require racket/contract
         "contracts.rkt"
         "catalog.rkt")



(struct selection
  (course-code
   group-number
   career
   credits
   pending-corequisites
   conflicts)
  #:transparent)


(struct combination
  (selections
   total-credits)
  #:transparent)



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
