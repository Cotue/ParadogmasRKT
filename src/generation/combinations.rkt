#lang racket

(require racket/contract
         racket/stream
         "../models/catalog.rkt"
         "../models/combination.rkt"
         "../domain/conflicts.rkt"
         "../functional/stream-utils.rkt")

(provide
 (contract-out
  [generate-combinations
   (-> (listof candidate-course?)
       (stream-of/c combination?))]))

;; Genera todas las combinaciones válidas (sin choques y no vacías)
;; de forma perezosa mediante streams.
(define (generate-combinations candidates)
  (explore candidates '() 0))

;; Función recursiva que explora la inclusión o exclusión de cursos.
;; La pereza (laziness) se logra envolviendo el cuerpo en stream-lazy.
;; Esto difiere la evaluación del stream-append y la recursión hasta
;; que el consumidor requiera evaluar el flujo.
(define (explore remaining acc total)
  (stream-lazy
   (if (empty? remaining)
       ;; Caso base: si ya exploramos todos y hay elementos en acc, devolvemos la combinación.
       (if (empty? acc)
           empty-stream
           (stream (combination (reverse acc) total)))
       (let ([c (first remaining)]
             [rest-rem (rest remaining)])
         (stream-append
          ;; Rama 1: NO incluir el curso
          (explore rest-rem acc total)
          ;; Ramas 2..N: Incluir el curso con cada grupo de forma ordenada
          (include-course c (candidate-course-groups c) rest-rem acc total))))))

;; Explora las ramas de inclusión iterando sobre los grupos del curso.
;; La evaluación perezosa se mantiene usando stream-lazy.
(define (include-course c groups rest-rem acc total)
  (stream-lazy
   (if (empty? groups)
       empty-stream
       (let* ([g (first groups)]
              [sel (selection (candidate-course-code c)
                              (group-option-number g)
                              (candidate-course-career c)
                              (candidate-course-credits c)
                              (candidate-course-pending-corequisites c)
                              (group-option-conflicts g))])
         (stream-append
          ;; PODA TEMPRANA: Evaluamos si esta selección es compatible.
          ;; Si es #f, podamos la rama completa devolviendo empty-stream.
          (if (selection-compatible? sel acc)
              (explore rest-rem (cons sel acc) (+ total (candidate-course-credits c)))
              empty-stream)
          ;; Concatenamos recursivamente la evaluación del resto de grupos.
          (include-course c (rest groups) rest-rem acc total))))))
