#lang racket

(require "../models/result.rkt"
         "../models/catalog.rkt")

(provide validate-pref-schema-version
         validate-pref-credits
         validate-pref-courses-exist
         validate-pref-course-structure
         validate-pref-unique-courses
         validate-pref-unique-groups
         validate-pref-courses-in-catalog
         validate-pref-groups-in-catalog)

;; valida que el esquema sea "2.0"
(define (validate-pref-schema-version hash-data)
  (if (not (hash? hash-data))
      (result-err "El JSON de preferencias no es un objeto válido.")
      (let ([ver (hash-ref hash-data 'schemaVersion #f)])
        (if (equal? ver "2.0")
            (result-ok hash-data)
            (result-err (format "Versión de schema de preferencias no compatible: ~a. Se requiere '2.0'." ver))))))

;; valida rango de créditos mínimo y máximo
(define (validate-pref-credits hash-data)
  (let ([cred (hash-ref hash-data 'creditos #f)])
    (if (not (hash? cred))
        (result-err "El campo 'creditos' es obligatorio y debe ser un objeto.")
        (let ([min-c (hash-ref cred 'min #f)]
              [max-c (hash-ref cred 'max #f)])
          (cond
            [(not (and (exact-integer? min-c) (>= min-c 0)))
             (result-err (format "El crédito mínimo debe ser un entero no negativo, dado: ~a" min-c))]
            [(not (and (exact-integer? max-c) (>= max-c 0)))
             (result-err (format "El crédito máximo debe ser un entero no negativo, dado: ~a" max-c))]
            [(> min-c max-c)
             (result-err (format "El crédito mínimo (~a) no puede ser mayor que el máximo (~a)." min-c max-c))]
            [else (result-ok hash-data)])))))

;; valida existencia de la lista de cursos de interés
(define (validate-pref-courses-exist hash-data)
  (let ([cursos (hash-ref hash-data 'cursosInteres #f)])
    (if (and (list? cursos) (not (null? cursos)))
        (result-ok hash-data)
        (result-err "El campo 'cursosInteres' debe ser una lista no vacía."))))

;; valida tipos de cada entrada de curso y sus grupos
(define (validate-pref-course-structure hash-data)
  (let loop ([cs (hash-ref hash-data 'cursosInteres '())])
    (cond
      [(null? cs) (result-ok hash-data)]
      [else
       (let ([c (car cs)])
         (if (not (hash? c))
             (result-err "Entrada de curso en 'cursosInteres' inválida.")
             (let ([code (hash-ref c 'curso #f)]
                   [grps (hash-ref c 'grupos #f)])
               (cond
                 [(not (string? code))
                  (result-err (format "Código de curso inválido: ~a" code))]
                 [(not (and (list? grps) (not (null? grps)) (andmap exact-integer? grps)))
                  (result-err (format "Los grupos del curso ~a deben ser una lista no vacía de enteros." code))]
                 [else (loop (cdr cs))]))))])))

;; valida que no existan códigos de curso duplicados
(define (validate-pref-unique-courses hash-data)
  (let loop ([cs (hash-ref hash-data 'cursosInteres '())]
             [seen '()])
    (cond
      [(null? cs) (result-ok hash-data)]
      [else
       (let ([code (hash-ref (car cs) 'curso)])
         (if (member code seen)
             (result-err (format "Curso duplicado en preferencias: ~a" code))
             (loop (cdr cs) (cons code seen))))])))

;; valida que no existan números de grupo duplicados dentro de la misma entrada
(define (validate-pref-unique-groups hash-data)
  (let loop-courses ([cs (hash-ref hash-data 'cursosInteres '())])
    (cond
      [(null? cs) (result-ok hash-data)]
      [else
       (let* ([c (car cs)]
              [code (hash-ref c 'curso)]
              [grps (hash-ref c 'grupos)])
         (let loop-groups ([gs grps]
                           [seen '()])
           (cond
             [(null? gs) (loop-courses (cdr cs))]
             [(member (car gs) seen)
              (result-err (format "Número de grupo duplicado (~a) en el curso ~a." (car gs) code))]
             [else (loop-groups (cdr gs) (cons (car gs) seen))])))])))

;; valida que cada curso especificado exista en el catálogo
(define (validate-pref-courses-in-catalog hash-data cat)
  (let ([cat-codes (map course-code (catalog-courses cat))])
    (let loop ([cs (hash-ref hash-data 'cursosInteres '())])
      (cond
        [(null? cs) (result-ok hash-data)]
        [else
         (let ([code (hash-ref (car cs) 'curso)])
           (if (member code cat-codes)
               (loop (cdr cs))
               (result-err (format "El curso ~a no existe en el catálogo." code))))]))))

;; valida que los grupos solicitados existan dentro de cada curso en el catálogo
(define (validate-pref-groups-in-catalog hash-data cat)
  (let loop-courses ([cs (hash-ref hash-data 'cursosInteres '())])
    (cond
      [(null? cs) (result-ok hash-data)]
      [else
       (let* ([c (car cs)]
              [code (hash-ref c 'curso)]
              [requested-groups (hash-ref c 'grupos)]
              [cat-course (findf (lambda (item) (string=? (course-code item) code))
                                 (catalog-courses cat))]
              [valid-group-nums
 (map group-option-number
     (course-groups cat-course))])
         (let loop-groups ([gs requested-groups])
           (cond
             [(null? gs) (loop-courses (cdr cs))]
             [(member (car gs) valid-group-nums) (loop-groups (cdr gs))]
             [else
              (result-err (format "El grupo ~a no existe para el curso ~a en el catálogo."
                                  (car gs) code))])))])))
