#lang racket

(require json
         racket/contract
         "../models/combination.rkt"
         "../functional/stream-utils.rkt")

(provide
 (contract-out
  [write-combinations-json (-> path-string? (stream-of/c combination?) void?)]
  [write-combinations-to-port (-> output-port? (stream-of/c combination?) void?)]))

;;versión del esquema de salida para combinaciones
(define schema-version "2.0")

;;convierte una selección individual al hash esperado por el formato JSON
(define (selection->hash sel)
  (hasheq 'curso (selection-course-code sel)
          'grupo (selection-group-number sel)
          'carrera (selection-career sel)))

;;convierte una combinación al hash con selecciones y créditos totales
(define (combination->hash comb)
  (hasheq 'selecciones (map selection->hash (combination-selections comb))
          'creditosTotales (combination-total-credits comb)))

;;escribe de forma perezosa el sobre JSON y las combinaciones en el puerto suministrado
(define (write-combinations-to-port port comb-stream)
  (display (format "{\"schemaVersion\":\"~a\",\"combinaciones\":[" schema-version) port)
  (let loop ([st comb-stream]
             [is-first? #t])
    (cond
      [(stream-empty? st)
       (display "]}" port)]
      [else
       (if is-first?
           (newline port)
           (display ",\n" port))
       (write-json (combination->hash (stream-first st)) port)
       (loop (stream-rest st) #f)])))

;;abre el archivo de destino sobrescribiendo su contenido y delega la escritura
(define (write-combinations-json filepath comb-stream)
  (call-with-output-file filepath
    (lambda (port)
      (write-combinations-to-port port comb-stream))
    #:exists 'truncate))
