#lang racket

(require "../models/types.rkt")

(provide validate-schema-version
         validate-required-fields
         validate-course-credits
         validate-group-numbers
         validate-conflict-references)

(define (validate-schema-version hash-data)
  (let ([ver (hash-ref hash-data 'schemaVersion #f)])
    (if (equal? ver "1.0")
        (result-ok hash-data)
        (result-err (format "Versión de schema no compatible: ~a. Se requiere '1.0'." ver)))))

(define (validate-required-fields hash-data)
  (if (not (hash? hash-data))
      (result-err "El JSON no es un objeto válido.")
      (let ([has-version? (hash-has-key? hash-data 'schemaVersion)]
            [has-carrera? (hash-has-key? hash-data 'carrera)]
            [has-cursos? (hash-has-key? hash-data 'cursos)])
        (if (and has-version? has-carrera? has-cursos? (list? (hash-ref hash-data 'cursos)))
            (let ([carrera (hash-ref hash-data 'carrera)])
              (if (and (hash? carrera)
                       (hash-has-key? carrera 'codigo)
                       (hash-has-key? carrera 'nombre))
                  (result-ok hash-data)
                  (result-err "El campo 'carrera' carece de 'codigo' o 'nombre'.")))
            (result-err "Faltan campos obligatorios de nivel superior ('schemaVersion', 'carrera', 'cursos').")))))

(define (validate-course-credits courses-list)
  (let loop ([cs courses-list])
    (cond
      [(null? cs) (result-ok courses-list)]
      [else
       (let* ([c (car cs)]
              [cred (hash-ref c 'creditos #f)])
         (if (and (exact-integer? cred) (>= cred 0) (<= cred 12))
             (loop (cdr cs))
             (result-err (format "Créditos inválidos (~a) en curso ~a. Debe ser entero entre 0 y 12."
                                 cred (hash-ref c 'codigo "DESCONOCIDO")))))])))

(define (validate-group-numbers courses-list)
  (define (check-groups grps seen-nums course-code)
    (cond
      [(null? grps) (result-ok #t)]
      [else
       (let* ([g (car grps)]
              [num (hash-ref g 'numero #f)])
         (cond
           [(not (and (exact-integer? num) (> num 0)))
            (result-err (format "Número de grupo inválido (~a) en el curso ~a." num course-code))]
           [(member num seen-nums)
            (result-err (format "Número de grupo duplicado (~a) en el curso ~a." num course-code))]
           [else
            (check-groups (cdr grps) (cons num seen-nums) course-code)]))]))

  (let loop ([cs courses-list])
    (cond
      [(null? cs) (result-ok courses-list)]
      [else
       (let* ([c (car cs)]
              [code (hash-ref c 'codigo "DESCONOCIDO")]
              [grps (hash-ref c 'grupos '())]
              [res (check-groups grps '() code)])
         (if (result-ok? res)
             (loop (cdr cs))
             res))])))

(define (validate-conflict-references courses-list)
  (define valid-pairs
    (append-map
     (lambda (c)
       (let ([ccode (hash-ref c 'codigo)])
         (map (lambda (g) (cons ccode (hash-ref g 'numero)))
              (hash-ref c 'grupos '()))))
     courses-list))

  (define (check-conflicts-in-group grp course-code)
    (let loop ([choques (hash-ref grp 'choques '())])
      (cond
        [(null? choques) (result-ok #t)]
        [else
         (let* ([ch (car choques)]
                [target-course (hash-ref ch 'curso #f)]
                [target-group (hash-ref ch 'grupo #f)]
                [pair (cons target-course target-group)])
           (if (member pair valid-pairs)
               (loop (cdr choques))
               (result-err (format "Referencia de choque inválida (~a, grupo ~a) desde ~a."
                                   target-course target-group course-code))))])))

  (let loop-courses ([cs courses-list])
    (cond
      [(null? cs) (result-ok courses-list)]
      [else
       (let* ([c (car cs)]
              [ccode (hash-ref c 'codigo)]
              [grps (hash-ref c 'grupos '())])
         (let loop-groups ([gs grps])
           (cond
             [(null? gs) (loop-courses (cdr gs))]
             [else
              (let ([res (check-conflicts-in-group (car gs) ccode)])
                (if (result-ok? res)
                    (loop-groups (cdr gs))
                    res))])))])))
