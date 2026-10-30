#lang racket

(require json
         "../models/result.rkt"
         "../models/catalog.rkt"
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

;; mapea una referencia de choque al identificador
(define (json->group-key h)
  (group-key (hash-ref h 'curso)
             (hash-ref h 'grupo)))

;; mapea un grupo conservando únicamente su número
;; y las referencias de choque calculadas por C
(define (json->group-option h)
  (group-option
   (hash-ref h 'numero)
   (map json->group-key
        (hash-ref h 'choques '()))))

;; mapea un curso únicamente con los datos requeridos
;; por las etapas posteriores de Racket
(define (json->course h)
  (course
   (hash-ref h 'codigo)
   (hash-ref h 'carrera)
   (hash-ref h 'creditos)
   (hash-ref h 'puedeMatricular)
   (hash-ref h 'correquisitosPendientes '())
   (map json->group-option
        (hash-ref h 'grupos '()))))

;; mapea el objeto raíz al catálogo canónico
(define (json->catalog h)
  (let ([carrera (hash-ref h 'carrera)])
    (catalog
     (hash-ref h 'schemaVersion)
     (hash-ref carrera 'codigo)
     (map json->course
          (hash-ref h 'cursos '())))))

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
