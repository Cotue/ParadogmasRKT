#lang racket

(require rackunit
         racket/runtime-path
         "../../src/io/catalog.rkt"
         "../../src/models/types.rkt")

(define-runtime-path valid-json "../fixtures/catalog/valid.json")
(define-runtime-path valid-empty-json "../fixtures/catalog/valid_empty.json")
(define-runtime-path valid-zero-credits-json "../fixtures/catalog/valid_zero_credits.json")
(define-runtime-path real-computadores-json "../fixtures/catalog/real_computadores.json")
(define-runtime-path real-electronica-json "../fixtures/catalog/real_electronica.json")
(define-runtime-path invalid-malformed-json "../fixtures/catalog/invalid_malformed.json")
(define-runtime-path invalid-schema-json "../fixtures/catalog/invalid_schema_version.json")
(define-runtime-path invalid-missing-json "../fixtures/catalog/invalid_missing_fields.json")
(define-runtime-path invalid-carrera-json "../fixtures/catalog/invalid_course_carrera.json")
(define-runtime-path invalid-credits-json "../fixtures/catalog/invalid_credits.json")
(define-runtime-path invalid-groups-json "../fixtures/catalog/invalid_duplicate_groups.json")
(define-runtime-path invalid-conflict-json "../fixtures/catalog/invalid_conflict_ref.json")

(test-case "Carga catálogo válido v2.0 correctamente"
  (let ([res (read-catalog-json valid-json)])
    (check-true (result-ok? res))
    (let ([cat (result-ok-val res)])
      (check-equal? (catalog-schema-version cat) "2.0")
      (check-equal? (length (catalog-courses cat)) 1)
      (for-each
       (lambda (c)
         (check-equal? (course-carrera c) (catalog-career-code cat)))
       (catalog-courses cat)))))

(test-case "Carga catálogo vacío válido correctamente"
  (let ([res (read-catalog-json valid-empty-json)])
    (check-true (result-ok? res))
    (check-equal? (catalog-courses (result-ok-val res)) '())))

(test-case "Carga catálogo con curso de 0 créditos correctamente"
  (let ([res (read-catalog-json valid-zero-credits-json)])
    (check-true (result-ok? res))
    (let* ([cat (result-ok-val res)]
           [c (car (catalog-courses cat))])
      (check-equal? (course-credits c) 0))))

(test-case "Carga catálogo real de Computadores correctamente"
  (let ([res (read-catalog-json real-computadores-json)])
    (check-true (result-ok? res))
    (let ([cat (result-ok-val res)])
      (check-true (> (length (catalog-courses cat)) 0)))))

(test-case "Carga catálogo real de Electrónica correctamente"
  (let ([res (read-catalog-json real-electronica-json)])
    (check-true (result-ok? res))
    (let ([cat (result-ok-val res)])
      (check-true (> (length (catalog-courses cat)) 0)))))

(test-case "Rechaza JSON malformado"
  (let ([res (read-catalog-json invalid-malformed-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza schemaVersion incompatible"
  (let ([res (read-catalog-json invalid-schema-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza campos raíz faltantes"
  (let ([res (read-catalog-json invalid-missing-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza curso con campo carrera vacío"
  (let ([res (read-catalog-json invalid-carrera-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza créditos fuera de rango"
  (let ([res (read-catalog-json invalid-credits-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza números de grupo duplicados"
  (let ([res (read-catalog-json invalid-groups-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))

(test-case "Rechaza referencias de choque inválidas"
  (let ([res (read-catalog-json invalid-conflict-json)])
    (check-true (result-err? res))
    (check-true (and (string? (result-err-msg res)) (not (string=? (result-err-msg res) ""))))))
