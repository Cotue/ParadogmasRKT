#lang racket

(require rackunit
         json
         racket/file
         racket/list
         racket/runtime-path
         racket/system)



;; Rutas


(define-runtime-path project-root "../..")

(define main-path
  (build-path project-root "src" "main.rkt"))

(define valid-catalog-path
  (build-path project-root
              "tests"
              "fixtures"
              "catalog"
              "real_computadores.json"))

(define invalid-catalog-path
  (build-path project-root
              "tests"
              "fixtures"
              "catalog"
              "invalid_missing_fields.json"))

(define valid-preferences-path
  (build-path project-root
              "tests"
              "fixtures"
              "preferences"
              "valid.json"))

(define invalid-preferences-path
  (build-path project-root
              "tests"
              "fixtures"
              "preferences"
              "invalid_credits_order.json"))

(define racket-executable
  (find-executable-path "racket"))



(define (run-main args)
  (define stdout-port
    (open-output-string))

  (define stderr-port
    (open-output-string))

  (define exit-code
    (parameterize
        ([current-directory project-root]
         [current-output-port stdout-port]
         [current-error-port stderr-port])

      (apply system*/exit-code
             racket-executable
             (path->string main-path)
             args)))

  (values
   exit-code
   (get-output-string stdout-port)
   (get-output-string stderr-port)))


(define (read-json-file path)
  (call-with-input-file path
    (lambda (port)
      (read-json port))))


;; Ejecuta el pipeline completo con los datos reales.
;; La función thunk recibe el JSON final ya parseado.
(define (with-valid-output thunk)
  (define temp-dir
    (make-temporary-file
     "kane2-29-~a"
     'directory))

  (define output-path
    (build-path temp-dir "salida.json"))

  (dynamic-wind
   void

   (lambda ()
     (define-values
       (exit-code stdout stderr)
       (run-main
        (list
         (path->string valid-catalog-path)
         (path->string valid-preferences-path)
         (path->string output-path))))

     (check-equal?
      exit-code
      0
      (string-append stdout stderr))

     (check-true
      (file-exists? output-path))

     ;; Evita que una falla de ejecución produzca
     ;; errores secundarios intentando leer un archivo

     (when (and (= exit-code 0)
                (file-exists? output-path))
       (thunk
        (read-json-file output-path))))

   (lambda ()
     (when (directory-exists? temp-dir)
       (delete-directory/files temp-dir)))))




(define catalog-json
  (read-json-file valid-catalog-path))

(define preferences-json
  (read-json-file valid-preferences-path))


(define (find-course code)
  (findf
   (lambda (course)
     (string=?
      code
      (hash-ref course 'codigo)))
   (hash-ref catalog-json 'cursos)))


(define (find-group course group-number)
  (findf
   (lambda (group)
     (=
      group-number
      (hash-ref group 'numero)))
   (hash-ref course 'grupos)))


(define (group-declares-conflict?
         first-selection
         second-selection)

  (define course
    (find-course
     (hash-ref first-selection 'curso)))

  (define group
    (and course
         (find-group
          course
          (hash-ref first-selection 'grupo))))

  (and
   group

   (ormap
    (lambda (conflict)
      (and
       (string=?
        (hash-ref conflict 'curso)
        (hash-ref second-selection 'curso))

       (=
        (hash-ref conflict 'grupo)
        (hash-ref second-selection 'grupo))))

    (hash-ref group 'choques '()))))


(define (selections-conflict? first second)
  (or
   (group-declares-conflict? first second)
   (group-declares-conflict? second first)))


(define (all-pairs-compatible? selections)
  (cond
    [(null? selections)
     #t]

    [else
     (and
      (andmap
       (lambda (other)
         (not
          (selections-conflict?
           (car selections)
           other)))
       (cdr selections))

      (all-pairs-compatible?
       (cdr selections)))]))




;; Ejecución completa con datos reales.


(test-case
 "Etapa 2 genera un JSON válido con catálogo y preferencias reales"

 (with-valid-output
  (lambda (output-json)

    (check-equal?
     (hash-ref output-json 'schemaVersion)
     "2.0")

    (check-true
     (hash-has-key?
      output-json
      'combinaciones))

    (check-true
     (list?
      (hash-ref output-json 'combinaciones)))

    (check-false
     (null?
      (hash-ref output-json 'combinaciones))))))



;; Todas las combinaciones respetan el rango.


(test-case
 "Todas las combinaciones están dentro del rango de créditos"

 (define credit-data
   (hash-ref preferences-json 'creditos))

 (define minimum
   (hash-ref credit-data 'min))

 (define maximum
   (hash-ref credit-data 'max))

 (with-valid-output
  (lambda (output-json)

    (check-true
     (andmap
      (lambda (combination)
        (<=
         minimum
         (hash-ref combination 'creditosTotales)
         maximum))

      (hash-ref output-json 'combinaciones))))))



;; Ningún curso aparece dos veces.


(test-case
 "Ninguna combinación repite un curso"

 (with-valid-output
  (lambda (output-json)

    (check-true
     (andmap
      (lambda (combination)

        (define codes
          (map
           (lambda (selection)
             (hash-ref selection 'curso))
           (hash-ref combination 'selecciones)))

        (=
         (length codes)
         (length
          (remove-duplicates
           codes
           string=?))))

      (hash-ref output-json 'combinaciones))))))


;; ==================================================
;; TC-04
;; Cada selección posee curso, grupo y carrera.
;; ==================================================

(test-case
 "Cada selección contiene exactamente curso grupo y carrera"

 (with-valid-output
  (lambda (output-json)

    (check-true
     (andmap
      (lambda (combination)

        (andmap
         (lambda (selection)

           (equal?
            (sort
             (hash-keys selection)
             symbol<?)

            '(carrera curso grupo)))

         (hash-ref combination 'selecciones)))

      (hash-ref output-json 'combinaciones))))))



;; Carrera conservada desde el catálogo.


(test-case
 "La carrera de cada selección se conserva"

 (with-valid-output
  (lambda (output-json)

    (check-true
     (andmap
      (lambda (combination)

        (andmap
         (lambda (selection)

           (define course
             (find-course
              (hash-ref selection 'curso)))

           (and
            course
            (string=?
             (hash-ref selection 'carrera)
             (hash-ref course 'carrera))))

         (hash-ref combination 'selecciones)))

      (hash-ref output-json 'combinaciones))))))



;; Ninguna combinación posee choques.


(test-case
 "Ninguna combinación final contiene grupos con choque"

 (with-valid-output
  (lambda (output-json)

    (check-true
     (andmap
      (lambda (combination)

        (all-pairs-compatible?
         (hash-ref combination 'selecciones)))

      (hash-ref output-json 'combinaciones))))))



;; Correquisitos pendientes satisfechos.


(test-case
 "Todas las combinaciones cumplen correquisitos pendientes"

 (with-valid-output
  (lambda (output-json)

    (check-true
     (andmap
      (lambda (combination)

        (define selections
          (hash-ref combination 'selecciones))

        (define selected-codes
          (map
           (lambda (selection)
             (hash-ref selection 'curso))
           selections))

        (andmap
         (lambda (selection)

           (define course
             (find-course
              (hash-ref selection 'curso)))

           (and
            course

            (andmap
             (lambda (required-code)
               (and
                (member
                 required-code
                 selected-codes
                 string=?)
                #t))

             (hash-ref
              course
              'correquisitosPendientes
              '()))))

         selections))

      (hash-ref output-json 'combinaciones))))))



;; Preferencias inválidas.


(test-case
 "Preferencias inválidas detienen la ejecución"

 (define temp-dir
   (make-temporary-file
    "kane2-29-invalid-pref-~a"
    'directory))

 (define output-path
   (build-path temp-dir "salida.json"))

 (dynamic-wind
  void

  (lambda ()
    (define-values
      (exit-code stdout stderr)
      (run-main
       (list
        (path->string valid-catalog-path)
        (path->string invalid-preferences-path)
        (path->string output-path))))

    (check-not-equal?
     exit-code
     0)

    (check-true
     (regexp-match?
      #rx"E2_PREFERENCES"
      (string-append stdout stderr)))

    (check-false
     (file-exists? output-path)))

  (lambda ()
    (delete-directory/files temp-dir))))



;; Catálogo inválido.


(test-case
 "Catálogo inválido detiene la ejecución"

 (define temp-dir
   (make-temporary-file
    "kane2-29-invalid-cat-~a"
    'directory))

 (define output-path
   (build-path temp-dir "salida.json"))

 (dynamic-wind
  void

  (lambda ()
    (define-values
      (exit-code stdout stderr)
      (run-main
       (list
        (path->string invalid-catalog-path)
        (path->string valid-preferences-path)
        (path->string output-path))))

    (check-not-equal?
     exit-code
     0)

    (check-true
     (regexp-match?
      #rx"E2_SCHEMA"
      (string-append stdout stderr)))

    (check-false
     (file-exists? output-path)))

  (lambda ()
    (delete-directory/files temp-dir))))



;; Argumentos incorrectos.


(test-case
 "Cantidad incorrecta de argumentos produce E2_ARGS"

 (define-values
   (exit-code stdout stderr)
   (run-main '()))

 (check-not-equal?
  exit-code
  0)

 (check-true
  (regexp-match?
   #rx"E2_ARGS"
   (string-append stdout stderr))))



;; Error al escribir la salida.


(test-case
 "Una ruta de salida inválida produce E2_OUTPUT_IO"

 (define temp-dir
   (make-temporary-file
    "kane2-29-output-error-~a"
    'directory))

 (define missing-directory
   (build-path
    temp-dir
    "no-existe"))

 (define output-path
   (build-path
    missing-directory
    "salida.json"))

 (dynamic-wind
  void

  (lambda ()
    (define-values
      (exit-code stdout stderr)
      (run-main
       (list
        (path->string valid-catalog-path)
        (path->string valid-preferences-path)
        (path->string output-path))))

    (check-not-equal?
     exit-code
     0)

    (check-true
     (regexp-match?
      #rx"E2_OUTPUT_IO"
      (string-append stdout stderr))))

  (lambda ()
    (delete-directory/files temp-dir))))
