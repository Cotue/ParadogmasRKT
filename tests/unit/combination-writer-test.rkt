#lang racket

(require rackunit
         json
         racket/runtime-path
         "../../src/io/combination-writer.rkt"
         "../../src/io/catalog.rkt"
         "../../src/io/preferences-reader.rkt"
         "../../src/domain/candidates.rkt"
         "../../src/domain/corequisites.rkt"
         "../../src/generation/combinations.rkt"
         "../../src/functional/stream-utils.rkt"
         "../../src/models/result.rkt"
         "../../src/models/combination.rkt"
         "../../src/models/preferences.rkt")

(define-runtime-path catalog-path "../fixtures/catalog/real_computadores.json")
(define-runtime-path valid-pref-path "../fixtures/preferences/valid.json")

;;helper local para construir selecciones de prueba
(define (make-test-selection c-code g-num #:career [c-career "Computadores"] #:credits [c-credits 3] #:pending [c-pending '()] #:conflicts [c-conflicts '()])
  (selection c-code g-num c-career c-credits c-pending c-conflicts))

;;helper local para construir combinaciones de prueba
(define (make-test-combination selections-list)
  (let ([total (apply + (map selection-credits selections-list))])
    (combination selections-list total)))

(test-case "Dos combinaciones serializan correctamente con esquema y datos exactos"
  (let* ([sel1 (make-test-selection "CE1101" 1 #:credits 3)]
         [sel2 (make-test-selection "CE1104" 2 #:credits 3)]
         [comb1 (make-test-combination (list sel1 sel2))]
         [comb2 (make-test-combination (list sel1))]
         [st (stream comb1 comb2)]
         [port (open-output-string)])
    (write-combinations-to-port port st)
    (let ([parsed (string->jsexpr (get-output-string port))])
      (check-equal? (hash-ref parsed 'schemaVersion) "2.0")
      (check-equal? (length (hash-ref parsed 'combinaciones)) 2)
      (check-equal? (map (lambda (c) (length (hash-ref c 'selecciones)))
                         (hash-ref parsed 'combinaciones))
                    '(2 1)))))

(test-case "Cada selección parseada conserva exactamente las claves curso, grupo y carrera"
  (let* ([sel (make-test-selection "CE1101" 1 #:career "Computadores")]
         [comb (make-test-combination (list sel))]
         [port (open-output-string)])
    (write-combinations-to-port port (stream comb))
    (let* ([parsed (string->jsexpr (get-output-string port))]
           [combs (hash-ref parsed 'combinaciones)]
           [first-comb (car combs)]
           [parsed-sel (car (hash-ref first-comb 'selecciones))])
      (check-equal? (hash-ref parsed-sel 'curso) "CE1101")
      (check-equal? (hash-ref parsed-sel 'grupo) 1)
      (check-equal? (hash-ref parsed-sel 'carrera) "Computadores")
      (check-equal? (length (hash-keys parsed-sel)) 3))))

(test-case "creditosTotales coincide y la combinación conserva la estructura requerida"
  (let* ([sel1 (make-test-selection "CE1101" 1 #:credits 3)]
         [sel2 (make-test-selection "MA1403" 4 #:credits 4)]
         [comb (make-test-combination (list sel1 sel2))]
         [port (open-output-string)])
    (write-combinations-to-port port (stream comb))
    (let* ([parsed (string->jsexpr (get-output-string port))]
           [parsed-comb (car (hash-ref parsed 'combinaciones))])
      (check-equal? (hash-ref parsed-comb 'creditosTotales) 7)
      (check-equal? (length (hash-keys parsed-comb)) 2))))

(test-case "Escribe correctamente una sola combinación verificando bordes de comas"
  (let* ([comb (make-test-combination (list (make-test-selection "CE1101" 1)))]
         [port (open-output-string)])
    (write-combinations-to-port port (stream comb))
    (let ([parsed (string->jsexpr (get-output-string port))])
      (check-equal? (length (hash-ref parsed 'combinaciones)) 1))))

(test-case "Stream vacío produce JSON válido con combinaciones vacías"
  (let ([port (open-output-string)])
    (write-combinations-to-port port empty-stream)
    (let ([parsed (string->jsexpr (get-output-string port))])
      (check-equal? (hash-ref parsed 'schemaVersion) "2.0")
      (check-equal? (hash-ref parsed 'combinaciones) '()))))

(test-case "Procesa adecuadamente un stream de 300 combinaciones"
  (let* ([base-comb (make-test-combination (list (make-test-selection "CE1101" 1)))]
         [st (stream-map (lambda (_) base-comb) (in-range 300))]
         [port (open-output-string)])
    (write-combinations-to-port port st)
    (let ([parsed (string->jsexpr (get-output-string port))])
      (check-equal? (length (hash-ref parsed 'combinaciones)) 300))))

(test-case "Demuestra procesamiento perezoso evaluando hasta la falla"
  (let* ([c1 (make-test-combination (list (make-test-selection "CE1101" 1)))]
         [c2 (make-test-combination (list (make-test-selection "CE1104" 2)))]
         [lazy-st (stream-cons c1 (stream-cons c2 (error "Falla perezosa intencional")))]
         [port (open-output-string)])
    (check-exn exn:fail? (lambda () (write-combinations-to-port port lazy-st)))
    (let ([partial-output (get-output-string port)])
      (check-true (string-contains? partial-output "\"CE1101\""))
      (check-true (string-contains? partial-output "\"CE1104\"")))))

(test-case "Escribe y vuelve a leer correctamente desde disco"
  (let* ([tmp (make-temporary-file "test_comb_~a.json")]
         [comb (make-test-combination (list (make-test-selection "CE1101" 1)))]
         [st (stream comb)])
    (write-combinations-json tmp st)
    (let ([parsed (call-with-input-file tmp read-json)])
      (check-equal? (hash-ref parsed 'schemaVersion) "2.0")
      (check-equal? (length (hash-ref parsed 'combinaciones)) 1))
    (delete-file tmp)))

(test-case "Sobrescribe archivos existentes correctamente"
  (let* ([tmp (make-temporary-file "test_overwrite_~a.json")]
         [comb1 (make-test-combination (list (make-test-selection "CE1101" 1)))]
         [comb2 (make-test-combination (list (make-test-selection "CE1104" 2)))]
         [st1 (stream comb1 comb2)]
         [st2 (stream comb1)])
    (write-combinations-json tmp st1)
    (write-combinations-json tmp st2)
    (let ([parsed (call-with-input-file tmp read-json)])
      (check-equal? (length (hash-ref parsed 'combinaciones)) 1))
    (delete-file tmp)))

(test-case "Lanza excepción de sistema de archivos al intentar escribir en carpeta inexistente"
  (let ([invalid-path "carpeta_inexistente_xyz/salida.json"]
        [st (stream (make-test-combination (list (make-test-selection "CE1101" 1))))])
    (check-exn exn:fail:filesystem? (lambda () (write-combinations-json invalid-path st)))))

(test-case "Prueba de integración de flujo completo con datos reales de producción"
  (let* ([cat (result-ok-val (read-catalog-json catalog-path))]
         [prefs (result-ok-val (read-preferences-json valid-pref-path cat))]
         [cands (build-candidates cat prefs)]
         [raw-st (generate-combinations cands)]
         [filtered-st (stream-select corequisites-satisfied? raw-st)]
         [tmp (make-temporary-file "test_integration_~a.json")])
    (write-combinations-json tmp filtered-st)
    (let* ([parsed (call-with-input-file tmp read-json)]
           [combs (hash-ref parsed 'combinaciones)])
      (check-true (> (length combs) 0))
      (for-each
       (lambda (comb-hash)
         (let ([sels (hash-ref comb-hash 'selecciones)])
           (let ([course-codes (map (lambda (s) (hash-ref s 'curso)) sels)])
             (when (member "CE1104" course-codes)
               (check-not-false (member "CE1101" course-codes))))
           (for-each
            (lambda (s-hash)
              (let ([c-code (hash-ref s-hash 'curso)]
                    [g-num (hash-ref s-hash 'grupo)]
                    [c-career (hash-ref s-hash 'carrera)])
                (check-not-false (member c-code '("CE1101" "CE1104" "MA1403")))
                (check-equal? c-career "Computadores")
                (cond
                  [(string=? c-code "CE1101") (check-not-false (member g-num '(1 2 3)))]
                  [(string=? c-code "CE1104") (check-not-false (member g-num '(2 3)))]
                  [(string=? c-code "MA1403") (check-not-false (member g-num '(4 5)))])))
            sels)))
       combs))
    (delete-file tmp)))
