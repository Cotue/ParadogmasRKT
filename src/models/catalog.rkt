#lang racket

(require racket/contract
         "contracts.rkt")



(struct group-key
  (course-code
   group-number)
  #:transparent)



(struct group-option
  (number
   conflicts)
  #:transparent)


(struct course
  (code
   career
   credits
   can-enroll?
   pending-corequisites
   groups)
  #:transparent)



(struct catalog
  (schema-version
   career-code
   courses)
  #:transparent)




(struct candidate-course
  (code
   career
   credits
   pending-corequisites
   groups)
  #:transparent)



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
