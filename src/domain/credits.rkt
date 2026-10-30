#lang racket

(require racket/contract
         "../models/preferences.rkt"
         "../models/combination.rkt")

(provide
 (contract-out
  [credits-in-range?
   (-> preferences? combination? boolean?)]))

;; Verifica que el total de créditos de una combinación se encuentre
;; dentro del rango inclusivo definido por las preferencias del estudiante
(define (credits-in-range? prefs comb)
  (<= (preferences-min-credits prefs)
      (combination-total-credits comb)
      (preferences-max-credits prefs)))
