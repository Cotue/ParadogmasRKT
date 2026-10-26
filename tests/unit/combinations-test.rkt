#lang racket

(module+ test
  (require rackunit
           racket/stream
           "../../src/models/catalog.rkt"
           "../../src/models/combination.rkt"
           "../../src/domain/conflicts.rkt"
           "../../src/generation/combinations.rkt")

  ;; Helpers locales para la creación de datos de prueba
  (define (make-group n [conflicts '()])
    (group-option n conflicts))

  (define (make-course code cred groups)
    (candidate-course code "IC" cred '() groups))

  (define (make-key code n)
    (group-key code n))

  (begin

   (test-case "1. 0 cursos -> stream vacío"
     (check-true (stream-empty? (generate-combinations '()))))

   (test-case "2. 1 curso con 1 grupo -> exactamente una combinación"
     (define c1 (make-course "C1" 3 (list (make-group 1))))
     (define res (generate-combinations (list c1)))
     (check-false (stream-empty? res))
     (check-equal? (length (stream->list res)) 1))

   (test-case "3. 1 curso con 2 grupos -> 2 combinaciones, en orden"
     (define c1 (make-course "C1" 3 (list (make-group 1) (make-group 2))))
     (define res (stream->list (generate-combinations (list c1))))
     (check-equal? (length res) 2)
     (check-equal? (selection-group-number (first (combination-selections (first res)))) 1)
     (check-equal? (selection-group-number (first (combination-selections (second res)))) 2))

   (test-case "4. 2 cursos sin conflictos (2 grupos cada uno) -> 8 combinaciones"
     (define c1 (make-course "A" 3 (list (make-group 1) (make-group 2))))
     (define c2 (make-course "B" 4 (list (make-group 1) (make-group 2))))
     (define res (stream->list (generate-combinations (list c1 c2))))
     (check-equal? (length res) 8))

   (test-case "5. 3 cursos de 2 grupos, sin conflictos -> exactamente 26 combinaciones"
     (define c1 (make-course "A" 3 (list (make-group 1) (make-group 2))))
     (define c2 (make-course "B" 4 (list (make-group 1) (make-group 2))))
     (define c3 (make-course "C" 3 (list (make-group 1) (make-group 2))))
     (define res (stream->list (generate-combinations (list c1 c2 c3))))
     (check-equal? (length res) 26))

   (test-case "6. Conflicto total entre 2 cursos de 1 grupo"
     (define c1 (make-course "A" 3 (list (make-group 1 (list (make-key "B" 1))))))
     (define c2 (make-course "B" 4 (list (make-group 1))))
     (define res (stream->list (generate-combinations (list c1 c2))))
     (check-equal? (length res) 2)
     ;; La combinación conjunta nunca se emite
     (for ([comb res])
       (check-equal? (length (combination-selections comb)) 1)))

   (test-case "7. Conflicto parcial (A-G1 choca con B-G2)"
     (define c1 (make-course "A" 3 (list (make-group 1 (list (make-key "B" 2))) (make-group 2))))
     (define c2 (make-course "B" 4 (list (make-group 1) (make-group 2))))
     (define res (stream->list (generate-combinations (list c1 c2))))
     ;; Extraer combinaciones que incluyen a ambos cursos (tamaño 2)
     (define completas (filter (lambda (c) (= (length (combination-selections c)) 2)) res))
     (check-equal? (length completas) 3)
     ;; Validamos que A1+B2 no está presente
     (for ([comb completas])
       (define gA (selection-group-number (first (combination-selections comb))))
       (define gB (selection-group-number (second (combination-selections comb))))
       (check-false (and (= gA 1) (= gB 2)))))

   (test-case "8. Orden determinista"
     (define c1 (make-course "A" 3 (list (make-group 1))))
     (define c2 (make-course "B" 4 (list (make-group 1))))
     (define res (stream->list (generate-combinations (list c1 c2))))
     (check-equal? (length res) 3)
     ;; El orden esperado de combinaciones: (B), (A), (A+B)
     (check-equal? (selection-course-code (first (combination-selections (first res)))) "B")
     (check-equal? (selection-course-code (first (combination-selections (second res)))) "A")
     (check-equal? (length (combination-selections (third res))) 2)
     (check-equal? (selection-course-code (first (combination-selections (third res)))) "A")
     (check-equal? (selection-course-code (second (combination-selections (third res)))) "B"))

   (test-case "9. Ninguna combinación está vacía y no hay duplicados"
     (define c1 (make-course "A" 3 (list (make-group 1) (make-group 2))))
     (define c2 (make-course "B" 4 (list (make-group 1))))
     (define res (stream->list (generate-combinations (list c1 c2))))
     (for ([comb res])
       (define sels (combination-selections comb))
       (check-false (empty? sels))
       (define codes (map selection-course-code sels))
       (check-false (check-duplicates codes))))

   (test-case "10. Créditos correctos (suma de cursos)"
     (define c1 (make-course "A" 3 (list (make-group 1))))
     (define c2 (make-course "B" 4 (list (make-group 1))))
     (define res (stream->list (generate-combinations (list c1 c2))))
     (for ([comb res])
       (define suma (apply + (map selection-credits (combination-selections comb))))
       (check-equal? (combination-total-credits comb) suma)))

   (test-case "11. Conservación de career y pending-corequisites"
     (define c1 (candidate-course "A" "XX" 3 '("Z" "W") (list (make-group 1))))
     (define comb (stream-first (generate-combinations (list c1))))
     (define sel (first (combination-selections comb)))
     (check-equal? (selection-career sel) "XX")
     (check-equal? (selection-pending-corequisites sel) '("Z" "W")))

   (test-case "12. Invariante global de compatibilidad"
     (define c1 (make-course "A" 3 (list (make-group 1 (list (make-key "B" 1))))))
     (define c2 (make-course "B" 4 (list (make-group 1 (list (make-key "C" 1))))))
     (define c3 (make-course "C" 3 (list (make-group 1))))
     (define res (stream->list (generate-combinations (list c1 c2 c3))))
     (for ([comb res])
       (define sels (combination-selections comb))
       (for ([s1 sels])
         (check-true (selection-compatible? s1 (remove s1 sels))))))

   (test-case "13. LAZINESS comprobada en espacio masivo (~4^40)"
     ;; Construir 40 cursos de 3 grupos = combinatoria gigante
     (define big-candidates
       (for/list ([i (in-range 40)])
         (make-course (number->string i) 3 (list (make-group 1) (make-group 2) (make-group 3)))))
     (define strm (generate-combinations big-candidates))
     ;; Extraer los primeros 3 usando stream-first y stream-rest.
     ;; Si el stream no fuera lazy, este test colgaría al intentar evaluarlo todo.
     (define e1 (stream-first strm))
     (define e2 (stream-first (stream-rest strm)))
     (define e3 (stream-first (stream-rest (stream-rest strm))))
     (check-true (combination? e1))
     (check-true (combination? e2))
     (check-true (combination? e3)))

   (test-case "14. Contrato"
     (check-exn exn:fail:contract?
                (lambda () (generate-combinations "no-es-lista"))))))
