#lang racket

(require rackunit
         "../../src/domain/corequisites.rkt"
         "../../src/models/combination.rkt")

;;helper local para construir selecciones con valores por defecto
(define (make-test-selection code pending #:group [grp 1] #:career [career "IC"] #:credits [cred 3] #:conflicts [confs '()])
  (selection code grp career cred pending confs))

;;helper local para construir combinaciones calculando el total de créditos
(define (make-test-combination selections)
  (let ([total (apply + (map selection-credits selections))])
    (combination selections total)))

(test-case "Combinación sin ningún pendiente es válida"
  (let* ([s1 (make-test-selection "CE1101" '())]
         [s2 (make-test-selection "MA1403" '())]
         [comb (make-test-combination (list s1 s2))])
    (check-true (corequisites-satisfied? comb))))

(test-case "Curso A con pendiente B y B presente es válido"
  (let* ([s1 (make-test-selection "CE1104" '("CE1101"))]
         [s2 (make-test-selection "CE1101" '())]
         [comb (make-test-combination (list s1 s2))])
    (check-true (corequisites-satisfied? comb))))

(test-case "Curso A con pendiente B y B ausente es inválido"
  (let* ([s1 (make-test-selection "CE1104" '("CE1101"))]
         [comb (make-test-combination (list s1))])
    (check-false (corequisites-satisfied? comb))))

(test-case "Curso A con pendientes B y C, ambos presentes es válido"
  (let* ([s1 (make-test-selection "CE2103" '("CE1104" "MA1403"))]
         [s2 (make-test-selection "CE1104" '())]
         [s3 (make-test-selection "MA1403" '())]
         [comb (make-test-combination (list s1 s2 s3))])
    (check-true (corequisites-satisfied? comb))))

(test-case "Curso A con pendientes B y C, solo B presente es inválido"
  (let* ([s1 (make-test-selection "CE2103" '("CE1104" "MA1403"))]
         [s2 (make-test-selection "CE1104" '())]
         [comb (make-test-combination (list s1 s2))])
    (check-false (corequisites-satisfied? comb))))

(test-case "Verifica que el grupo del correquisito no influye en la validez"
  (let* ([s1 (make-test-selection "CE1104" '("CE1101") #:group 1)]
         [s2 (make-test-selection "CE1101" '() #:group 5)]
         [comb (make-test-combination (list s1 s2))])
    (check-true (corequisites-satisfied? comb))))

(test-case "Curso A con pendiente B, B presente y curso Z no relacionado es válido"
  (let* ([s1 (make-test-selection "CE1104" '("CE1101"))]
         [s2 (make-test-selection "CE1101" '())]
         [sz (make-test-selection "FI1101" '())]
         [comb (make-test-combination (list s1 s2 sz))])
    (check-true (corequisites-satisfied? comb))))

(test-case "Manejo de correquisitos cíclicos entre dos cursos"
  (let* ([q1 (make-test-selection "QU1106" '("QU1102"))]
         [q2 (make-test-selection "QU1102" '("QU1106"))]
         [comb-both (make-test-combination (list q1 q2))]
         [comb-single (make-test-combination (list q1))])
    (check-true (corequisites-satisfied? comb-both))
    (check-false (corequisites-satisfied? comb-single))))

(test-case "Manejo de cadenas de correquisitos"
  (let* ([sa (make-test-selection "CURSO-A" '("CURSO-B"))]
         [sb (make-test-selection "CURSO-B" '("CURSO-C"))]
         [sc (make-test-selection "CURSO-C" '())]
         [comb-incomplete (make-test-combination (list sa sb))]
         [comb-complete (make-test-combination (list sa sb sc))])
    (check-false (corequisites-satisfied? comb-incomplete))
    (check-true (corequisites-satisfied? comb-complete))))

(test-case "Combinación vacía devuelve #t"
  (let ([empty-comb (make-test-combination '())])
    (check-true (corequisites-satisfied? empty-comb))))

(test-case "Evaluación de datos reales (CE1104 con pendiente CE1101)"
  (let* ([ce1104 (make-test-selection "CE1104" '("CE1101") #:group 2 #:career "Computadores" #:credits 3)]
         [ce1101 (make-test-selection "CE1101" '() #:group 1 #:career "Computadores" #:credits 3)]
         [comb-alone (make-test-combination (list ce1104))]
         [comb-pair (make-test-combination (list ce1104 ce1101))])
    (check-false (corequisites-satisfied? comb-alone))
    (check-true (corequisites-satisfied? comb-pair))))

(test-case "Verifica inmutabilidad de la combinación evaluada"
  (let* ([s1 (make-test-selection "CE1104" '("CE1101"))]
         [s2 (make-test-selection "CE1101" '())]
         [comb (make-test-combination (list s1 s2))]
         [expected-comb (make-test-combination (list s1 s2))])
    (corequisites-satisfied? comb)
    (check-equal? comb expected-comb)))
