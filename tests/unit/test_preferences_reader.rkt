#lang racket

(require rackunit
         racket/runtime-path
         "../../src/io/catalog.rkt"
         "../../src/io/preferences-reader.rkt"
         "../../src/models/result.rkt"
         "../../src/models/preferences.rkt")

(define-runtime-path catalog-path "../fixtures/catalog/real_computadores.json")

(define-runtime-path valid-pref "../fixtures/preferences/valid.json")
(define-runtime-path valid-not-enrollable-pref "../fixtures/preferences/valid_not_enrollable.json")
(define-runtime-path invalid-malformed-pref "../fixtures/preferences/invalid_malformed.json")
(define-runtime-path invalid-schema-pref "../fixtures/preferences/invalid_schema_version.json")
(define-runtime-path invalid-credits-order-pref "../fixtures/preferences/invalid_credits_order.json")
(define-runtime-path invalid-negative-credits-pref "../fixtures/preferences/invalid_negative_credits.json")
(define-runtime-path invalid-empty-courses-pref "../fixtures/preferences/invalid_empty_courses.json")
(define-runtime-path invalid-empty-groups-pref "../fixtures/preferences/invalid_empty_groups.json")
(define-runtime-path invalid-duplicate-course-pref "../fixtures/preferences/invalid_duplicate_course.json")
(define-runtime-path invalid-duplicate-group-pref "../fixtures/preferences/invalid_duplicate_group.json")
(define-runtime-path invalid-unknown-course-pref "../fixtures/preferences/invalid_unknown_course.json")
(define-runtime-path invalid-unknown-group-pref "../fixtures/preferences/invalid_unknown_group.json")
(define-runtime-path non-existent-pref "../fixtures/preferences/non_existent.json")

;; carga el catálogo de producción una sola vez
(define cat (result-ok-val (read-catalog-json catalog-path)))

(test-case "Carga archivo de preferencias válido correctamente"
  (let ([res (read-preferences-json valid-pref cat)])
    (check-true (result-ok? res))
    (let ([p (result-ok-val res)])
      (check-equal? (preferences-min-credits p) 8)
      (check-equal? (preferences-max-credits p) 16)
      (check-equal? (length (preferences-courses p)) 3)
      (let ([first-course (car (preferences-courses p))])
        (check-equal? (course-preference-course-code first-course) "CE1101")
        (check-equal? (course-preference-allowed-groups first-course) '(1 2 3))))))

(test-case "Acepta preferencia sobre curso no matriculable"
  (let ([res (read-preferences-json valid-not-enrollable-pref cat)])
    (check-true (result-ok? res))))

(test-case "Rechaza archivo JSON malformado"
  (let ([res (read-preferences-json invalid-malformed-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza schemaVersion incompatible"
  (let ([res (read-preferences-json invalid-schema-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza orden de créditos inválido (min > max)"
  (let ([res (read-preferences-json invalid-credits-order-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza créditos negativos"
  (let ([res (read-preferences-json invalid-negative-credits-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza lista de cursos vacía"
  (let ([res (read-preferences-json invalid-empty-courses-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza lista de grupos vacía en un curso"
  (let ([res (read-preferences-json invalid-empty-groups-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza cursos duplicados en preferencias"
  (let ([res (read-preferences-json invalid-duplicate-course-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza números de grupo duplicados en un curso"
  (let ([res (read-preferences-json invalid-duplicate-group-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza curso inexistente en el catálogo"
  (let ([res (read-preferences-json invalid-unknown-course-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza grupo inexistente para un curso existente"
  (let ([res (read-preferences-json invalid-unknown-group-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Verifica inmutabilidad del catálogo durante la lectura de preferencias"
  (let ([cat-before cat])
    (read-preferences-json valid-pref cat)
    (check-equal? cat cat-before)))

(test-case "Maneja archivo inexistente retornando result-err sin excepciones"
  (let ([res (read-preferences-json non-existent-pref cat)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))
