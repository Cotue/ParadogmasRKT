#lang racket

(require racket/contract
         "../models/types.rkt"
         "../models/preferences.rkt"
         "../domain/preferences-validators.rkt"
         "json_reader.rkt")

(provide
 (contract-out
  [read-preferences-json (-> path-string? catalog? result?)]))

;; mapea entrada JSON a struct course-preference
(define (json->course-preference h)
  (course-preference (hash-ref h 'curso)
                     (hash-ref h 'grupos)))

;; mapea hash de preferencias validado a struct preferences
(define (json->preferences h)
  (let ([cred (hash-ref h 'creditos)])
    (preferences (hash-ref cred 'min)
                 (hash-ref cred 'max)
                 (map json->course-preference (hash-ref h 'cursosInteres '())))))

;; lee y valida el archivo de preferencias del estudiante contra el catálogo
(define (read-preferences-json filepath cat)
  (bind (read-json-file filepath)
    (lambda (json-data)
      (bind (validate-pref-schema-version json-data)
        (lambda (_)
          (bind (validate-pref-credits json-data)
            (lambda (_)
              (bind (validate-pref-courses-exist json-data)
                (lambda (_)
                  (bind (validate-pref-course-structure json-data)
                    (lambda (_)
                      (bind (validate-pref-unique-courses json-data)
                        (lambda (_)
                          (bind (validate-pref-unique-groups json-data)
                            (lambda (_)
                              (bind (validate-pref-courses-in-catalog json-data cat)
                                (lambda (_)
                                  (bind (validate-pref-groups-in-catalog json-data cat)
                                    (lambda (_)
                                      (result-ok (json->preferences json-data)))))))))))))))))))))
