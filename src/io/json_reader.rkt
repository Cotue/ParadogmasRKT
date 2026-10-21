#lang racket

(require json
         "../models/types.rkt"
         "../domain/validators.rkt")

(provide parse-and-validate-catalog
         read-json-file
         bind)

;; encadena resultados
(define (bind r f)
  (if (result-ok? r)
      (f (result-ok-val r))
      r))

;; lee el archivo JSON capturando errores de lectura o sintaxis
(define (read-json-file filepath)
  (with-handlers ([exn:fail? (lambda (e)
                               (result-err (format "Error de sintaxis JSON o de lectura: ~a" (exn-message e))))])
    (call-with-input-file filepath
      (lambda (port)
        (result-ok (read-json port))))))

;; mapea estructura de horario
(define (json->schedule h)
  (schedule (string->symbol (hash-ref h 'dia))
            (hash-ref h 'inicio)
            (hash-ref h 'fin)))

;; mapea conflicto de grupo
(define (json->group-conflict h)
  (group-conflict (hash-ref h 'curso)
                  (hash-ref h 'grupo)))

;; mapea estructura de grupo
(define (json->group h)
  (group (hash-ref h 'numero)
         (map json->schedule (hash-ref h 'horarios '()))
         (hash-ref h 'tieneChoque)
         (map json->group-conflict (hash-ref h 'choques '()))))

;; mapea estructura de curso leyendo la carrera directamente del objeto
(define (json->course h)
  (course (hash-ref h 'codigo)
          (hash-ref h 'nombre)
          (hash-ref h 'creditos)
          (hash-ref h 'semestre)
          (hash-ref h 'carrera)
          (hash-ref h 'requisitos '())
          (hash-ref h 'correquisitos '())
          (hash-ref h 'correquisitosPendientes '())
          (map json->group (hash-ref h 'grupos '()))
          (hash-ref h 'tieneChoque)
          (hash-ref h 'puedeMatricular)))

;; mapea objeto JSON a la estructura principal catalog
(define (json->catalog h)
  (let ([carrera (hash-ref h 'carrera)])
    (catalog (hash-ref h 'schemaVersion)
             (hash-ref carrera 'codigo)
             (hash-ref carrera 'nombre)
             (map json->course (hash-ref h 'cursos '())))))

;; pipeline funcional con 6 validadores
(define (parse-and-validate-catalog filepath)
  (bind (read-json-file filepath)
    (lambda (json-data)
      (bind (validate-required-fields json-data)
        (lambda (_)
          (bind (validate-schema-version json-data)
            (lambda (_)
              (let ([courses (hash-ref json-data 'cursos)])
                (bind (validate-course-carrera courses)
                  (lambda (_)
                    (bind (validate-course-credits courses)
                      (lambda (_)
                        (bind (validate-group-numbers courses)
                          (lambda (_)
                            (bind (validate-conflict-references courses)
                              (lambda (_)
                                (result-ok (json->catalog json-data))))))))))))))))))
