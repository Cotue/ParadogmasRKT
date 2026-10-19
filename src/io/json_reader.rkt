#lang racket

(require json
         "../models/types.rkt"
         "../domain/validators.rkt")

(provide parse-and-validate-catalog
         bind)

(define (bind r f)
  (if (result-ok? r)
      (f (result-ok-val r))
      r))

(define (read-json-file filepath)
  (with-handlers ([exn:fail? (lambda (e)
                               (result-err (format "Error de sintaxis JSON o de lectura: ~a" (exn-message e))))])
    (call-with-input-file filepath
      (lambda (port)
        (result-ok (read-json port))))))

(define (json->schedule h)
  (schedule (string->symbol (hash-ref h 'dia))
            (hash-ref h 'inicio)
            (hash-ref h 'fin)))

(define (json->group-conflict h)
  (group-conflict (hash-ref h 'curso)
                  (hash-ref h 'grupo)))

(define (json->group h)
  (group (hash-ref h 'numero)
         (map json->schedule (hash-ref h 'horarios '()))
         (hash-ref h 'tieneChoque)
         (map json->group-conflict (hash-ref h 'choques '()))))

(define (json->course h career-code)
  (course (hash-ref h 'codigo)
          (hash-ref h 'nombre)
          (hash-ref h 'creditos)
          (hash-ref h 'semestre)
          career-code
          (hash-ref h 'requisitos '())
          (hash-ref h 'correquisitos '())
          (hash-ref h 'correquisitosPendientes '())
          (map json->group (hash-ref h 'grupos '()))
          (hash-ref h 'tieneChoque)
          (hash-ref h 'puedeMatricular)))

(define (json->catalog h)
  (let* ([carrera (hash-ref h 'carrera)]
         [career-code (hash-ref carrera 'codigo)])
    (catalog (hash-ref h 'schemaVersion)
             career-code
             (hash-ref carrera 'nombre)
             (map (lambda (c) (json->course c career-code)) (hash-ref h 'cursos '())))))

(define (parse-and-validate-catalog filepath)
  (bind (read-json-file filepath)
    (lambda (json-data)
      (bind (validate-required-fields json-data)
        (lambda (_)
          (bind (validate-schema-version json-data)
            (lambda (_)
              (let ([courses (hash-ref json-data 'cursos)])
                (bind (validate-course-credits courses)
                  (lambda (_)
                    (bind (validate-group-numbers courses)
                      (lambda (_)
                        (bind (validate-conflict-references courses)
                          (lambda (_)
                            (result-ok (json->catalog json-data)))))))))))))))))
