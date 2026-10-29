#lang racket

(module+ test
  (require rackunit
           racket/stream
           "../../src/domain/credits.rkt"
           "../../src/models/preferences.rkt"
           "../../src/models/combination.rkt"
           "../../src/models/catalog.rkt"
           "../../src/generation/combinations.rkt"
           "../../src/functional/stream-utils.rkt")


  (define (make-prefs min max)
    (preferences min max '()))

  (define (make-comb total)
    (combination '() total))

  (define prefs-12-18 (make-prefs 12 18))

  (test-case "1. total < min (11) -> #f"
    (check-false (credits-in-range? prefs-12-18 (make-comb 11))))

  (test-case "2. total = min (12) -> #t"
    (check-true (credits-in-range? prefs-12-18 (make-comb 12))))

  (test-case "3. min < total < max (15) -> #t"
    (check-true (credits-in-range? prefs-12-18 (make-comb 15))))

  (test-case "4. total = max (18) -> #t"
    (check-true (credits-in-range? prefs-12-18 (make-comb 18))))

  (test-case "5. total > max (19) -> #f"
    (check-false (credits-in-range? prefs-12-18 (make-comb 19))))

  (test-case "6. Rango degenerado min = max = 16"
    (define prefs-16 (make-prefs 16 16))
    (check-true (credits-in-range? prefs-16 (make-comb 16)))
    (check-false (credits-in-range? prefs-16 (make-comb 15)))
    (check-false (credits-in-range? prefs-16 (make-comb 17))))

  (test-case "7. Rango que empieza en 0: [0, 5], total 0"
    (check-true (credits-in-range? (make-prefs 0 5) (make-comb 0))))

  (test-case "8. Contratos: fallan con tipos inválidos"
    (check-exn exn:fail:contract?
               (lambda () (credits-in-range? "no-prefs" (make-comb 10))))
    (check-exn exn:fail:contract?
               (lambda () (credits-in-range? prefs-12-18 "no-combinacion"))))


  (define cand-A
    (candidate-course "A" "IC" 3 '() (list (group-option 1 '()))))
  (define cand-B
    (candidate-course "B" "IC" 4 '() (list (group-option 1 '()))))
  (define combos (generate-combinations (list cand-A cand-B)))

  (test-case "9. INTEGRACIÓN: rango [4, 7] filtra (B) y (A+B)"
    (define filtrado (stream-select (lambda (c) (credits-in-range? (make-prefs 4 7) c)) combos))
    (define lista-filtrada (stream->list filtrado))

    (check-equal? (length lista-filtrada) 2)
    ;; Combinación 1: (B)
    (check-equal? (combination-total-credits (first lista-filtrada)) 4)
    (check-equal? (selection-course-code (first (combination-selections (first lista-filtrada)))) "B")
    ;; Combinación 2: (A+B)
    (check-equal? (combination-total-credits (second lista-filtrada)) 7)
    (check-equal? (selection-course-code (first (combination-selections (second lista-filtrada)))) "A")
    (check-equal? (selection-course-code (second (combination-selections (second lista-filtrada)))) "B"))

  (test-case "10. INTEGRACIÓN: rango [100, 200] devuelve stream vacío"
    (define filtrado (stream-select (lambda (c) (credits-in-range? (make-prefs 100 200) c)) combos))
    (check-true (empty? (stream->list filtrado))))

  (test-case "11. INTEGRACIÓN: rango [3, 7] incluye (B), (A), (A+B)"
    (define filtrado (stream-select (lambda (c) (credits-in-range? (make-prefs 3 7) c)) combos))
    (define lista-filtrada (stream->list filtrado))

    (check-equal? (length lista-filtrada) 3)
    (check-equal? (combination-total-credits (first lista-filtrada)) 4)  ;; (B)
    (check-equal? (combination-total-credits (second lista-filtrada)) 3) ;; (A)
    (check-equal? (combination-total-credits (third lista-filtrada)) 7)) ;; (A+B)

  (test-case "12. Laziness: espacio gigante"
    (define (crear-cursos-gigantes n)
      (if (zero? n)
          '()
          (cons (candidate-course (number->string n) "IC" 3 '()
                                  (list (group-option 1 '()) (group-option 2 '()) (group-option 3 '())))
                (crear-cursos-gigantes (- n 1)))))

    (define gigante (generate-combinations (crear-cursos-gigantes 40)))
    (define filtrado-gigante (stream-select (lambda (c) (credits-in-range? (make-prefs 3 6) c)) gigante))

    (define c1 (stream-first filtrado-gigante))
    (define c2 (stream-first (stream-rest filtrado-gigante)))

    (check-true (<= 3 (combination-total-credits c1) 6))
    (check-true (<= 3 (combination-total-credits c2) 6))))
