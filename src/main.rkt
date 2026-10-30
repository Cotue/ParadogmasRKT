#lang racket

(require "models/result.rkt"
         "io/catalog.rkt"
         "io/preferences-reader.rkt"
         "io/combination-writer.rkt"
         "domain/candidates.rkt"
         "domain/corequisites.rkt"
         "domain/credits.rkt"
         "generation/combinations.rkt"
         "functional/stream-utils.rkt")




;; Reporta un error comprensible para el usuario
;; y finaliza la ejecución con estado no exitoso.
(define (fail-with-code code message)
  (eprintf "~a: ~a\n"
           code
           message)
  (exit 1))



(define (run-stage2 catalog-path
                    preferences-path
                    output-path)


  (define catalog-result
    (read-catalog-json catalog-path))

  (cond
    [(result-err? catalog-result)


     (fail-with-code
      "E2_SCHEMA"
      (result-err-msg catalog-result))]

    [else

     (define catalog
       (result-ok-val catalog-result))



     (define preferences-result
       (read-preferences-json
        preferences-path
        catalog))

     (cond
       [(result-err? preferences-result)

        (fail-with-code
         "E2_PREFERENCES"
         (result-err-msg preferences-result))]

       [else

        (define preferences
          (result-ok-val preferences-result))


        (define candidates
          (build-candidates
           catalog
           preferences))



        (define combinations
          (generate-combinations
           candidates))



        (define combinations-with-corequisites
          (stream-select
           corequisites-satisfied?
           combinations))



        (define valid-combinations
          (stream-select
           (lambda (comb)
             (credits-in-range?
              preferences
              comb))
           combinations-with-corequisites))



        (with-handlers
            ([exn:fail:filesystem?
              (lambda (e)
                (fail-with-code
                 "E2_OUTPUT_IO"
                 (exn-message e)))])

          (write-combinations-json
           output-path
           valid-combinations))])]))




(module+ main

  (define args
    (vector->list
     (current-command-line-arguments)))

  (if (= (length args) 3)

      (run-stage2
       (first args)
       (second args)
       (third args))

      (fail-with-code
       "E2_ARGS"
       "Uso: racket src/main.rkt <catalogo.json> <preferencias.json> <salida.json>")))
