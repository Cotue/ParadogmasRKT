#lang racket

(require rackunit
         racket/stream
         "../../src/functional/stream-utils.rkt")

;; Struct local de prueba: demuestra que stream-select no depende del dominio.
(struct test-box (val) #:transparent)

(module+ test
  (test-case "1. Enteros: filtrar pares"
    (check-equal? (stream->list (stream-select even? (stream 1 2 3 4 5 6 7 8 9 10)))
                  '(2 4 6 8 10)))

  (test-case "2. Strings: palabras cortas"
    (check-equal? (stream->list
                   (stream-select (lambda (s) (<= (string-length s) 4))
                                  (stream "racket" "c" "java" "prolog" "uno")))
                  '("c" "java" "uno")))

  (test-case "3. Struct local (tercer tipo)"
    (check-equal? (stream->list
                   (stream-select (lambda (b) (> (test-box-val b) 10))
                                  (stream (test-box 10) (test-box 20) (test-box 5))))
                  (list (test-box 20))))

  (test-case "4. Stream vacío"
    (check-true (stream-empty? (stream-select even? empty-stream))))

  (test-case "5. Ningún elemento cumple"
    (check-true (stream-empty? (stream-select even? (stream 1 3 5 7)))))

  (test-case "6. Todos cumplen"
    (check-equal? (stream->list (stream-select even? (stream 2 4 6 8))) '(2 4 6 8)))

  (test-case "7. Preserva el orden"
    (check-equal? (stream->list (stream-select even? (stream 10 2 8 4 6))) '(10 2 8 4 6)))

  (test-case "8. Laziness: stream infinito"
    (define (naturals n) (stream-cons n (naturals (+ n 1))))
    (define evens (stream-select even? (naturals 0)))
    (check-equal? (list (stream-first evens)
                        (stream-first (stream-rest evens))
                        (stream-first (stream-rest (stream-rest evens))))
                  '(0 2 4)))

  (test-case "9. Laziness: no evalúa elementos posteriores"
    (define src (stream-cons 2 (error "¡Evaluación forzada!")))
    (check-equal? (stream-first (stream-select even? src)) 2))

  (test-case "10. Violaciones de contrato"
    (check-exn exn:fail:contract?
               (lambda () (stream-select "no-es-funcion" empty-stream)))
    (check-exn exn:fail:contract?
               (lambda () (stream-select even? "no-es-stream"))))

  (test-case "11. Reutilización encadenada"
    (define mayores-que-5 (stream-select (lambda (x) (> x 5)) (stream 1 2 3 4 5 6 7 8 9 10)))
    (check-equal? (stream->list (stream-select even? mayores-que-5)) '(6 8 10)))

  (test-case "12. Acepta una lista como fuente (las listas son streams)"
    (check-equal? (stream->list (stream-select even? '(1 2 3 4))) '(2 4)))

  (test-case "13. stream-of/c verifica elementos de forma perezosa"
    (define f (contract (-> (stream-of/c exact-integer?) any/c) stream-first 'pos 'neg))
    (check-equal? (f (stream-cons 1 (stream-cons "malo" empty-stream))) 1)
    (check-exn exn:fail:contract? (lambda () (f (stream "malo"))))))
