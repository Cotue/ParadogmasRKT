#lang racket

(require racket/contract
         "../models/combination.rkt")

(provide
 (contract-out
  [corequisites-satisfied? (-> combination? boolean?)]))

;;determina si todos los correquisitos pendientes de cada selección están presentes en la combinación
(define (corequisites-satisfied? comb)
  (let* ([selections (combination-selections comb)]
         [present-codes (map selection-course-code selections)])
    (andmap (lambda (sel)
              (andmap (lambda (req-code)
                        (and (member req-code present-codes) #t))
                      (selection-pending-corequisites sel)))
            selections)))
