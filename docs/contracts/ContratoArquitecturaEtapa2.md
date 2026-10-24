# Contrato maestro de arquitectura y flujo — CEmestre Etapa 2

**Versión del contrato:** 1.1
**Etapa:** 2 — Paradigma funcional
**Lenguaje:** Racket 9.3 (`#lang racket`) con contratos explícitos
**Rol del documento:** Fuente de verdad arquitectónica para el desarrollo de la Etapa 2.
**Cambio principal de la versión 1.1:** separación física de la Etapa 2 en un repositorio independiente y adopción de Racket con contratos explícitos en lugar de Typed Racket.

---

## 1. Propósito

Este documento define la arquitectura, los límites, los modelos conceptuales, los contratos de entrada y salida y las reglas funcionales de la Etapa 2 de CEmestre.

Su objetivo es permitir que cualquier integrante del equipo —o una herramienta de IA— pueda implementar un módulo de esta etapa sin depender de conocimiento informal del proyecto ni asumir comportamientos no documentados.

Este contrato **precede conceptualmente al resto de historias de usuario de la Etapa 2**. Los módulos posteriores deben respetar las decisiones aquí establecidas.

Si una implementación contradice este documento, se considera incorrecta hasta que el contrato sea actualizado explícitamente y aprobado por el equipo.

---

## 2. Objetivo de la Etapa 2

La Etapa 2 recibe el catálogo ya procesado por la Etapa 1 y las preferencias de matrícula del estudiante.

Debe:

1. leer el catálogo JSON producido por C;
2. leer las preferencias del estudiante;
3. construir las opciones candidatas;
4. generar combinaciones de matrícula mediante streams;
5. garantizar que las combinaciones no contengan grupos con choques;
6. respetar los correquisitos pendientes producidos por la Etapa 1;
7. filtrar las combinaciones por el rango de créditos solicitado;
8. exportar las combinaciones válidas a un archivo JSON consumible por Prolog.

La Etapa 2 **no selecciona un horario final**, no optimiza según preferencias adicionales y no aplica restricciones futuras propias de Prolog.

---

## 3. Límites entre Etapa 1 y Etapa 2

La Etapa 2 considera la salida JSON de la Etapa 1 como su única interfaz con el módulo en C.

```text
ETAPA 1 — C
     │
     │ catalogo_procesado.json
     ▼
ETAPA 2 — RACKET
```

Racket **NO DEBE**:

- leer `catalogo.tsv`;
- leer `historial.txt`;
- acceder a estructuras internas de C;
- depender de `struct` o archivos `.c/.h`;
- recalcular requisitos;
- recalcular correquisitos académicos;
- volver a comparar horas para descubrir choques;
- corregir datos que debieron ser validados por C.

Racket **SÍ DEBE** consumir del JSON:

- `puedeMatricular`;
- `correquisitosPendientes`;
- grupos disponibles;
- relaciones detalladas de `choques`;
- créditos;
- carrera de origen del curso.

La Etapa 2 recibe además una entrada propia:

```text
preferencias.json
```

Este archivo no pertenece a la Etapa 1.

### 3.1 Independencia física de repositorios

La Etapa 2 se desarrolla en un repositorio independiente denominado conceptualmente:

```text
CEmestre-Racket
```

La Etapa 1 permanece en su repositorio de C. No existe dependencia de código fuente entre ambos repositorios.

La integración ocurre únicamente mediante el archivo JSON producido por C. El ejecutable de Racket recibe la ruta del catálogo por argumento de línea de comandos, por lo que el archivo puede encontrarse dentro o fuera del repositorio de Racket.

```text
┌──────────────────────────┐
│ Repo Etapa 1 — C         │
│                          │
│ cemestre.exe             │
└────────────┬─────────────┘
             │
             │ catalogo_procesado.json
             ▼
┌──────────────────────────┐
│ Repo Etapa 2 — Racket    │
│                          │
│ src/main.rkt             │
└────────────┬─────────────┘
             │
             │ combinaciones_validas.json
             ▼
           PROLOG
```

Para pruebas unitarias e integración interna, el repositorio de Racket mantiene **fixtures propios** que cumplen el mismo contrato JSON. Estos fixtures permiten desarrollar y probar Etapa 2 sin ejecutar C en cada prueba.

Los fixtures no sustituyen al archivo real producido por C en las pruebas de integración entre etapas.

Queda prohibido:

- importar código del repositorio de C;
- usar rutas absolutas hardcodeadas hacia el repositorio de C;
- exigir que ambos repositorios estén en una ubicación específica del equipo;
- modificar el JSON desde Racket para compensar errores del productor.

---

## 4. Unidad de ejecución

Una ejecución de Etapa 2 procesa **un único catálogo JSON correspondiente a una carrera**.

La Etapa 1 continuará pudiendo producir un archivo para Ingeniería en Computadores y otro para Ingeniería Electrónica.

Ambos datasets deben haber sido extendidos previamente a los primeros seis semestres.

Ejemplo conceptual:

```text
catalogo_computadores.json
        ↓
      Racket

o

catalogo_electronica.json
        ↓
      Racket
```

Aunque cada ejecución procesa una sola carrera, cada curso debe conservar explícitamente el campo `carrera`, ya que la siguiente etapa necesita conocer el origen de cada curso.

---

## 5. Diagrama general del flujo

```text
                REPO ETAPA 1 — C
                       │
                       ▼
            catalogo_procesado.json
                       │
                       │ ruta recibida por CLI
                       ▼
                  catalog.rkt
                (interfaz pública)
                       │
                       ▼
                json_reader.rkt
                (lectura, validación
                 y transformación)
                       │
                       ▼
                    catalog
                       │
                       │
preferencias.json      │
        │              │
        ▼              │
preferences-reader.rkt │
        │              │
        ▼              │
   preferences         │
        │              │
        └──────┬───────┘
               ▼
         candidates.rkt
               │
               ▼
       candidate-course[]
               │
               ▼
      combinations.rkt ◄──── conflicts.rkt
               │              (poda durante
               │               generación)
               ▼
       Stream<combination>
               │
               ▼
        corequisites.rkt
               │
               ▼
         stream-select
      (filtro correquisitos)
               │
               ▼
         stream-select
        (filtro créditos)
               │
               ▼
       Stream<combination>
               │
               ▼
    combination-writer.rkt
               │
               ▼
   combinaciones_validas.json
               │
               ▼
             PROLOG
```

`conflicts.rkt` participa **durante** la generación para podar ramas incompatibles. `corequisites.rkt` y `credits.rkt` se aplican como predicados puros sobre el stream generado. `stream-select` es la utilidad genérica utilizada para conservar únicamente los elementos que satisfacen cada criterio.

---

# 6. Contrato de entrada proveniente de C

## 6.1 Versión soportada

Etapa 2 soporta:

```text
schemaVersion = "2.0"
```

La versión 2.0 representa la evolución del JSON de la Etapa 1 para:

- incluir `carrera` a nivel de curso;
- trabajar con los primeros seis semestres;
- conservar toda la información calculada necesaria para Etapa 2.

Un archivo con otra versión debe rechazarse como incompatible.

---

## 6.2 Estructura JSON requerida

```json
{
  "schemaVersion": "2.0",
  "carrera": {
    "codigo": "IC",
    "nombre": "Ingeniería en Computadores"
  },
  "cursos": [
    {
      "codigo": "CE2201",
      "nombre": "Estructuras de Datos",
      "carrera": "IC",
      "creditos": 4,
      "semestre": 2,
      "requisitos": ["CE1101"],
      "correquisitos": ["MA1102"],
      "correquisitosPendientes": ["MA1102"],
      "grupos": [
        {
          "numero": 1,
          "horarios": [
            {
              "dia": "LUN",
              "inicio": "09:30",
              "fin": "11:20"
            }
          ],
          "tieneChoque": true,
          "choques": [
            {
              "curso": "MA1102",
              "grupo": 2
            }
          ]
        }
      ],
      "tieneChoque": true,
      "puedeMatricular": true
    }
  ]
}
```

---

## 6.3 Campos obligatorios utilizados por Etapa 2

Aunque el JSON conserva información completa de la Etapa 1, la lógica de generación de Etapa 2 depende principalmente de:

```text
curso.codigo
curso.carrera
curso.creditos
curso.puedeMatricular
curso.correquisitosPendientes

curso.grupos[].numero
curso.grupos[].choques[].curso
curso.grupos[].choques[].grupo
```

Los campos `requisitos`, `correquisitos` y `horarios` se conservan como parte del contrato de intercambio, pero Etapa 2 **no vuelve a ejecutar su lógica académica o temporal**.

---

## 6.4 Invariantes del catálogo de entrada

El JSON producido por la Etapa 1 debe cumplir las siguientes invariantes de
intercambio:

- `schemaVersion` debe ser `"2.0"`;
- `carrera.codigo` no puede estar vacío;
- `carrera.nombre` no puede estar vacío;
- cada `curso.codigo` debe ser no vacío;
- cada curso debe incluir `carrera`;
- `curso.carrera` debe coincidir con `carrera.codigo` del catálogo;
- los códigos de curso no se repiten dentro del archivo;
- `creditos` debe ser un entero mayor o igual que cero;
- `semestre` debe estar entre 1 y 6;
- `puedeMatricular` debe ser booleano;
- cada número de grupo debe ser entero positivo;
- no puede repetirse un número de grupo dentro de un mismo curso;
- cada referencia en `choques` debe señalar un curso y grupo existentes dentro del catálogo;
- un grupo no puede chocar consigo mismo;
- `tieneChoque = false` implica que `choques` está vacío;
- las relaciones de choque producidas por C deben ser simétricas.

Racket no corrige estas inconsistencias ni reconstruye la información de la
Etapa 1 para intentar repararlas. El productor en C es responsable de generar
un catálogo que cumpla este contrato.

---
### 6.4.1 Validaciones aplicadas por el reader de Racket

El contrato de intercambio anterior define las invariantes que debe cumplir el
catálogo producido por C. Sin embargo, el reader de Etapa 2 no vuelve a
comprobar todas las reglas que pertenecen al productor.

Actualmente, la frontera de lectura de Racket valida explícitamente:

1. `schemaVersion` es exactamente `"2.0"`;
2. la raíz contiene `schemaVersion`, `carrera` con `codigo` y `nombre`, y
   `cursos` como lista;
3. cada curso contiene `carrera` como string no vacío;
4. `creditos` es un entero entre 0 y 12 inclusive;
5. cada número de grupo es un entero positivo y no se repite dentro del curso;
6. cada referencia de `choques` apunta a un curso y grupo existentes dentro
   del catálogo.

Las demás invariantes del contrato de entrada continúan siendo responsabilidad
de la Etapa 1 y pueden verificarse en las pruebas de integración entre etapas,
pero Racket no recalcula ni reconstruye esa información durante la lectura.
En particular, el reader actual no vuelve a validar:

- el rango de `semestre`;
- requisitos o correquisitos académicos;
- el formato interno de los horarios;
- la coincidencia entre `curso.carrera` y `carrera.codigo`;
- unicidad global de códigos de curso;
- consistencia entre `tieneChoque` y `choques`;
- que un grupo no se referencie a sí mismo como choque;
- simetría de las relaciones de choque;
- el cálculo de `puedeMatricular`.

Estas reglas no deben incorporarse a Racket de forma unilateral en una historia
posterior. Si se decide ampliar la frontera de validación, debe actualizarse
primero el contrato correspondiente.

# 7. Contrato de preferencias del estudiante

## 7.1 Formato

La Etapa 2 utilizará JSON también para las preferencias.

Versión inicial:

```text
schemaVersion = "2.0"
```

Ejemplo:

```json
{
  {
  "schemaVersion": "2.0",
  "creditos": {
    "min": 12,
    "max": 18
  },
  "cursosInteres": [
    {
      "curso": "CE2201",
      "grupos": [1, 2]
    },
    {
      "curso": "MA2104",
      "grupos": [3, 4]
    },
    {
      "curso": "FI1202",
      "grupos": [1]
    }
  ]
}
```

## 7.2 Semántica

`cursosInteres` representa las opciones que el estudiante permite explorar.

No significa que todos los cursos deban aparecer en todas las combinaciones.

Cada elemento como:

```json
{
  "curso": "CE2201",
  "grupos": [1, 2]
}
```

significa que si `CE2201` aparece en una combinación, solamente podrá utilizar uno de los grupos `1` o `2`.

## 7.3 Reglas de validación

- `schemaVersion = "2.0"`;
- `creditos.min` y `creditos.max` son enteros no negativos;
- `creditos.min <= creditos.max`;
- `cursosInteres` debe contener al menos un curso;
- un código de curso no puede repetirse;
- cada curso debe existir en el catálogo cargado;
- cada entrada debe indicar al menos un grupo;
- un número de grupo no puede repetirse dentro de la misma preferencia;
- cada grupo indicado debe existir dentro del curso correspondiente;
- el formato soporta múltiples grupos por curso;
- los fixtures oficiales de prueba deben incluir al menos un curso con más de un grupo de interés.

Un curso con `puedeMatricular = false` puede aparecer en el archivo de preferencias, pero será eliminado posteriormente durante la construcción de candidatos.

Esto mantiene separadas la validación de la entrada y la elegibilidad académica producida por C.

---

# 8. Modelos conceptuales de Etapa 2

La implementación utilizará `struct` **inmutables** de Racket. Los modelos no se declaran mediante Typed Racket; sus fronteras públicas se protegen mediante contratos.

Los nombres definidos en esta sección constituyen la nomenclatura base para las historias posteriores.

## 8.1 Contratos base de dominio

El módulo `src/models/contracts.rkt` definirá contratos reutilizables para los valores simples del dominio.

Conceptualmente:

```text
course-code/c   -> string no vacío
career-code/c   -> string no vacío
group-number/c  -> entero exacto positivo
credits/c       -> entero exacto no negativo
```

Estos contratos evitan repetir validaciones de forma inconsistente entre módulos.

## 8.2 Resultado de operaciones

Las operaciones de frontera que pueden fallar utilizan una representación
explícita de éxito o error.

```racket
(struct result-ok
  (val)
  #:transparent)

(struct result-err
  (msg)
  #:transparent)
  ```
Semántica:
result-ok -> contiene el valor producido correctamente
result-err -> contiene un mensaje descriptivo del error
La definición canónica se encuentra en:
src/models/result.rkt
## 8.3 Identidad de grupo

```racket
(struct group-key
  (course-code group-number)
  #:transparent)
```

Contrato conceptual de campos:

```text
course-code  : course-code/c
group-number : group-number/c
```

Un grupo se identifica mediante el par:

```text
(códigoCurso, númeroGrupo)
```

El número de grupo por sí solo no constituye una identidad global.

## 8.4 Grupo

```racket
(struct group-option
  (number conflicts)
  #:transparent)
```

Contrato conceptual:

```text
number    : group-number/c
conflicts : (listof group-key?)
```

Etapa 2 no necesita conservar horarios dentro del modelo de generación porque C ya produjo las relaciones de conflicto.

## 8.5 Curso

```racket
(struct course
  (code
   career
   credits
   can-enroll?
   pending-corequisites
   groups)
  #:transparent)
```

Contrato conceptual:

```text
code                   : course-code/c
career                 : career-code/c
credits                : credits/c
can-enroll?            : boolean?
pending-corequisites   : (listof course-code/c)
groups                 : (listof group-option?)
```

## 8.6 Catálogo

```racket
(struct catalog
  (schema-version
   career-code
   courses)
  #:transparent)
```

Contrato conceptual:

```text
schema-version : string?
career-code    : career-code/c
courses        : (listof course?)
```

## 8.7 Preferencia de curso

```racket
(struct course-preference
  (course-code allowed-groups)
  #:transparent)
```

Contrato conceptual:

```text
course-code    : course-code/c
allowed-groups : (listof group-number/c)
```

## 8.8 Preferencias

```racket
(struct preferences
  (min-credits
   max-credits
   courses)
  #:transparent)
```

Contrato conceptual:

```text
min-credits : credits/c
max-credits : credits/c
courses     : (listof course-preference?)
```

La relación `min-credits <= max-credits` es una **invariante de dominio** validada por el reader; no puede expresarse únicamente revisando cada campo por separado.

## 8.9 Curso candidato

Un curso candidato representa un curso de interés que:

1. existe en el catálogo;
2. posee `puedeMatricular = true`;
3. conserva únicamente los grupos permitidos por las preferencias.

```racket
(struct candidate-course
  (code
   career
   credits
   pending-corequisites
   groups)
  #:transparent)
```

Contrato conceptual:

```text
code                 : course-code/c
career               : career-code/c
credits              : credits/c
pending-corequisites : (listof course-code/c)
groups               : (listof group-option?)
```

## 8.10 Selección

```racket
(struct selection
  (course-code
   group-number
   career
   credits
   pending-corequisites
   conflicts)
  #:transparent)
```

Contrato conceptual:

```text
course-code           : course-code/c
group-number          : group-number/c
career                : career-code/c
credits               : credits/c
pending-corequisites  : (listof course-code/c)
conflicts             : (listof group-key?)
```

`pending-corequisites` se conserva en cada selección para que una `combination` pueda validar correquisitos sin volver a consultar el JSON ni depender de I/O.

Los campos `credits`, `pending-corequisites` y `conflicts` son información interna útil durante el procesamiento y no tienen que exportarse completos a Prolog.

## 8.11 Combinación

```racket
(struct combination
  (selections total-credits)
  #:transparent)
```

Contrato conceptual:

```text
selections    : (listof selection?)
total-credits : credits/c
```

Una combinación es un valor inmutable. Agregar una selección produce una **nueva combinación**; nunca modifica una combinación existente.

---

# 9. Semántica de una combinación

Esta sección bloquea una decisión central del proyecto.

Una combinación es:

> Un subconjunto no vacío de los cursos candidatos, donde cada curso incluido posee exactamente un grupo seleccionado.

Si los cursos candidatos son `A`, `B` y `C`, pueden existir combinaciones estructurales como:

```text
A
B
C
A+B
A+C
B+C
A+B+C
```

Para cada curso incluido debe escogerse exactamente un grupo permitido.

La combinación vacía puede utilizarse internamente como caso base de la recursión, pero **no debe exportarse como resultado final**.

---

# 10. Regla de grupos

Para cada curso seleccionado:

```text
cantidad de grupos elegidos = 1
```

No se permite seleccionar dos grupos del mismo curso dentro de la misma combinación.

Los grupos posibles de un curso quedan restringidos por `Preferences.allowed-groups` y no por todos los grupos existentes en el catálogo.

---

# 11. Tratamiento de `puedeMatricular`

`puedeMatricular` es calculado exclusivamente por C.

Racket no vuelve a revisar requisitos.

Durante `build-candidates` se aplica:

```text
puedeMatricular = true
    ↓
curso candidato

puedeMatricular = false
    ↓
curso excluido
```

Un curso excluido no puede aparecer en ninguna combinación final.

---

# 12. Regla de conflictos

La Etapa 2 utiliza exclusivamente las relaciones `GroupOption.conflicts` producidas por C.

No compara `dia`, `inicio` ni `fin` para descubrir choques.

Dos selecciones `A-G1` y `B-G2` son incompatibles cuando la clave `(B, G2)` aparece dentro de los conflictos de `A-G1`.

El contrato de entrada exige relaciones simétricas.

La implementación del predicado de compatibilidad puede consultar ambos sentidos como medida defensiva, pero **no debe recalcular el choque a partir del horario**.

---

# 13. Poda temprana de conflictos

El generador debe evitar continuar una rama tan pronto como intenta agregar un grupo incompatible con la combinación parcial.

```text
combinación parcial
        +
nuevo grupo
        ↓
¿choca?
   │
   ├── sí → rama descartada
   │
   └── no → continuar recursión
```

Invariante:

> Toda combinación parcial que continúa dentro del generador ya es libre de choques.

---

# 14. Regla de correquisitos pendientes

Racket consume `pending-corequisites` pero no vuelve a determinar qué es o no un correquisito.

Para cada curso seleccionado `A`:

```text
A.pending-corequisites = [B, C]
```

la combinación final solo es válida si también contiene `B` y `C`, independientemente del grupo elegido para cada uno.

Si un correquisito pendiente no aparece en las preferencias, fue excluido porque `puedeMatricular = false`, o no posee ningún grupo permitido, entonces cualquier combinación que contenga el curso que lo requiere será inválida.

Racket **no agrega automáticamente cursos que el estudiante no incluyó en sus preferencias**.

La exclusión de un curso que requiere ese correquisito no invalida otras combinaciones que no incluyan dicho curso.

---

# 15. Rango de créditos

El rango es inclusivo.

```text
min <= totalCredits <= max
```

Los créditos totales se calculan sumando exactamente una vez los créditos de cada curso incluido.

El grupo seleccionado no altera los créditos.

Un rango para el cual no exista ninguna combinación válida produce:

```json
"combinaciones": []
```

y no se considera un error.

---

# 16. Inmutabilidad

La Etapa 2 utilizará paradigma funcional.

Queda prohibido:

```racket
set!
set-box!
vector-set!
hash-set!
set-car!
set-cdr!
```

y cualquier estrategia equivalente basada en mutación.

También queda prohibido:

- `struct` con `#:mutable`;
- variables globales reasignadas;
- acumuladores actualizados mediante efectos laterales.

Se permite:

- recursión;
- parámetros acumuladores;
- listas inmutables;
- structs inmutables;
- hashes inmutables para datos JSON;
- creación de nuevos valores a partir de valores anteriores;
- streams.

---

# 17. Streams

La generación principal debe retornar conceptualmente:

```text
Stream<combination>
```

En contratos de Racket, una interfaz pública que devuelva este valor se expresa mediante:

```racket
(stream/c combination?)
```

No se permite generar primero una lista completa de combinaciones y convertirla después a stream.

Contrato público planeado:

```racket
(provide
 (contract-out
  [generate-combinations
   (-> (listof candidate-course?)
       (stream/c combination?))]))
```

El generador debe poder producir la primera combinación sin construir previamente todas las combinaciones posteriores.

El writer debe consumir el stream progresivamente.

Queda prohibido convertir el conjunto completo mediante:

```racket
(stream->list all-combinations)
```

antes de serializarlo.

Se permite materializar pequeñas porciones de un stream únicamente en pruebas controladas cuando el objetivo sea verificar resultados finitos y explícitos.

---

# 18. Estrategia de contratos y modelado explícito

La Etapa 2 se desarrollará utilizando:

```racket
#lang racket
```

La estrategia elegida para cumplir el requisito de modelado explícito será el **sistema de contratos de Racket**, principalmente:

```racket
(require racket/contract)
```

Los módulos públicos expondrán contratos mediante `contract-out` cuando una función o estructura forme parte de la interfaz entre módulos.

Ejemplo conceptual:

```racket
(provide
 (contract-out
  [build-candidates
   (-> catalog?
       preferences?
       (listof candidate-course?))]))
```

## 18.1 Justificación de la decisión

Durante la configuración inicial se evaluó Typed Racket como estrategia de tipado. Sin embargo, el proyecto depende de forma central de los streams nativos de `racket/stream`. En la prueba real del entorno, el uso directo de esta biblioteca desde `#lang typed/racket` introdujo una frontera adicional de tipado para operaciones esenciales de streams.

Como la especificación del proyecto permite explícitamente **Typed Racket o contratos**, el equipo adopta Racket con contratos para:

- utilizar directamente `racket/stream`;
- mantener interfaces explícitas y verificables;
- evitar una capa adicional de adaptación tipada;
- reducir dependencias y diferencias de configuración entre equipos;
- mantener el código de defensa más simple;
- conservar el paradigma funcional y la inmutabilidad.

Esta decisión **no elimina el modelado explícito**. Los modelos siguen teniendo contratos de dominio y las interfaces públicas siguen declarando qué reciben y qué producen.

## 18.2 Frontera entre datos externos y dominio

Los valores obtenidos mediante `read-json` son datos externos y no deben circular directamente por la lógica de negocio.

El flujo obligatorio es:

```text
JSON / jsexpr
      ↓
validación de schema e invariantes
      ↓
structs inmutables del dominio
      ↓
lógica funcional
```

Los readers son responsables de transformar la representación externa en modelos válidos.

## 18.3 Alcance de los contratos

Los contratos fuertes se colocan principalmente en las **interfaces públicas** de módulos.

No es obligatorio envolver cada helper privado con `define/contract`, ya que eso aumentaría ruido sin mejorar la separación modular.

Regla:

```text
interfaz pública  -> contrato explícito
helper privado    -> pruebas + invariantes del módulo
```

## 18.4 Dependencias de ejecución

La aplicación se apoya únicamente en bibliotecas estándar de la distribución de Racket 9.3:

```text
racket/contract
racket/contract/parametric
racket/stream
json
rackunit (pruebas)
```

`racket-langserver` y Magic Racket son herramientas de desarrollo y no forman parte de las dependencias de ejecución de CEmestre.

---

# 19. Polimorfismo paramétrico

Se implementará una utilidad genérica de filtrado de streams protegida mediante un contrato paramétrico.

El módulo utilizará:

```racket
(require racket/contract
         racket/contract/parametric
         racket/stream)
```

Contrato planeado:

```racket
(parametric->/c [A]
  (-> (-> A boolean?)
      (stream/c A)
      (stream/c A)))
```

La función pública será conceptualmente:

```racket
(define (stream-select predicate source-stream)
  (stream-filter predicate source-stream))
```

La variable paramétrica `A` indica que la función no depende del tipo concreto de los elementos.

Puede utilizarse, por ejemplo, sobre:

```text
Stream<combination>
Stream<selection>
Stream<number>
```

siempre que reciba un predicado compatible con el elemento correspondiente.

La función **no debe conocer** `course`, `combination` ni `selection` de forma específica.

Debe probarse al menos con dos tipos de elemento diferentes para demostrar que la utilidad no está acoplada a un modelo concreto.

Uso esperado con combinaciones:

```racket
(stream-select
 (lambda (combination)
   (credits-in-range? preferences combination))
 combinations)
```

La implementación exacta y sus pruebas se desarrollarán en la historia correspondiente, pero su contrato conceptual queda bloqueado desde KAN-E2-01.

---

# 20. Orden determinista

Aunque los streams son lazy, para facilitar pruebas y reproducibilidad se define un orden estable.

El sistema conserva:

1. el orden de cursos indicado en `cursosInteres`;
2. el orden de grupos indicado en cada preferencia;
3. el orden producido por la recursión.

Dos ejecuciones sobre las mismas entradas deben producir el mismo orden de salida.

---

# 21. Contrato de salida hacia Prolog

## 21.1 Formato

La salida será JSON.

```text
schemaVersion = "1.0"
```

Nombre conceptual:

```text
combinaciones_validas.json
```

## 21.2 Estructura exacta

```json
{
  "schemaVersion": "1.0",
  "combinaciones": [
    {
      "selecciones": [
        {
          "curso": "CE2201",
          "grupo": 1,
          "carrera": "IC"
        },
        {
          "curso": "MA2104",
          "grupo": 3,
          "carrera": "IC"
        }
      ],
      "creditosTotales": 8
    }
  ]
}
```

## 21.3 Campos obligatorios

Por combinación:

```text
selecciones
creditosTotales
```

Por selección:

```text
curso
grupo
carrera
```

El writer no recalcula choques, requisitos, correquisitos ni elegibilidad.

## 21.4 Stream vacío

Si no existen combinaciones válidas:

```json
{
  "schemaVersion": "1.0",
  "combinaciones": []
}
```

Esto es una ejecución válida.

---

# 22. Manejo de errores

Los errores externos deben detectarse en las fronteras de I/O antes de que los datos entren en la lógica funcional.

Categorías conceptuales:

```text
E2_ARGS
E2_INPUT_IO
E2_JSON_SYNTAX
E2_SCHEMA
E2_PREFERENCES
E2_OUTPUT_IO
```

Semántica:

### `E2_ARGS`

Cantidad o formato incorrecto de argumentos de ejecución.

### `E2_INPUT_IO`

No fue posible abrir o leer un archivo de entrada.

### `E2_JSON_SYNTAX`

El archivo no contiene JSON sintácticamente válido.

### `E2_SCHEMA`

El JSON del catálogo no cumple el contrato de entrada.

### `E2_PREFERENCES`

El archivo de preferencias no cumple su contrato.

### `E2_OUTPUT_IO`

No fue posible crear o escribir la salida.

Los módulos de dominio puros no deben imprimir errores ni terminar el programa.

`main.rkt` es responsable de traducir los errores de frontera a mensajes comprensibles para el usuario y a un código de salida distinto de cero.

Las violaciones de `contract-out` representan errores de programación o de integración entre módulos y deben detectarse durante las pruebas. No deben utilizarse como sustituto de la validación del JSON externo.

No encontrar combinaciones válidas **no es un error**.

---

# 23. Interfaz del ejecutable

```bash
racket src/main.rkt <catalogo.json> <preferencias.json> <salida.json>
```

Ejemplo:

```bash
racket src/main.rkt \
  data/input/catalogo_computadores.json \
  data/input/preferencias.json \
  data/output/combinaciones_validas.json
```

---

# 24. Estructura de carpetas

El repositorio de Etapa 2 tendrá como raíz:

```text
CEmestre-Racket/
│
├── src/
│   ├── main.rkt
│   │
│   ├── models/
│   │   ├── contracts.rkt
│   │   ├── result.rkt
│   │   ├── catalog.rkt
│   │   ├── preferences.rkt
│   │   └── combination.rkt
│   │
│   ├── io/
│   │   ├── catalog.rkt
│   │   ├── json_reader.rkt
│   │   ├── preferences-reader.rkt
│   │   └── combination-writer.rkt
│   │
│   ├── domain/
│   │   ├── candidates.rkt
│   │   ├── conflicts.rkt
│   │   ├── corequisites.rkt
│   │   └── credits.rkt
│   │
│   ├── generation/
│   │   └── combinations.rkt
│   │
│   └── functional/
│       └── stream-utils.rkt
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
│       ├── catalog/
│       ├── preferences/
│       └── output/
│
├── docs/
│   └── contracts/
│       └── Contrato_Arquitectura_Etapa2.md
│
├── data/
│   ├── input/
│   └── output/
│
├── .vscode/
│   ├── extensions.json
│   └── settings.json
│
├── .gitignore
└── README.md
```

No existe una carpeta adicional `etapa2/`, porque el repositorio completo representa esta etapa.

`tests/fixtures/catalog/` contiene catálogos pequeños que respetan el mismo contrato que el JSON real producido por C. Esto permite ejecutar las pruebas de Racket de forma autónoma.

---

# 25. Responsabilidades por módulo

## `src/main.rkt`

**Tipo:** I/O / orquestación.

Responsable de:

- leer argumentos de línea de comandos;
- invocar los readers;
- conectar los módulos de dominio;
- iniciar la generación;
- aplicar filtros;
- ejecutar el writer;
- traducir errores de frontera a mensajes para el usuario.

No contiene lógica de negocio.

## `src/models/contracts.rkt`

**Tipo:** puro.

Define contratos reutilizables para valores simples del dominio, por ejemplo:

```text
course-code/c
group-number/c
career-code/c
credits/c
```

No realiza I/O.

## `src/models/result.rkt`

**Tipo:** puro.

Define la representación común de operaciones que pueden producir éxito o error:

```text
result-ok
result-err
result?
```

## `src/models/catalog.rkt`

**Tipo:** puro.

Define los structs inmutables:

```text
group-key
group-option
course
catalog
candidate-course
```

y expone sus interfaces públicas mediante contratos.

## `src/models/preferences.rkt`

**Tipo:** puro.

Define:

```text
course-preference
preferences
```

y sus contratos públicos.

## `src/models/combination.rkt`

**Tipo:** puro.

Define:

```text
selection
combination
```

y sus contratos públicos.

## `src/io/catalog-reader.rkt`

**Tipo:** I/O + frontera de validación.

Responsable de:

```text
archivo JSON
     ↓
read-json
     ↓
jsexpr
     ↓
validaciones definidas para la frontera de Racket
     ↓
transformación a structs canónicos
     ↓
catalog
```

No calcula elegibilidad ni choques.

## `src/io/preferences-reader.rkt`

**Tipo:** I/O + frontera de validación.

Valida que los cursos y grupos referenciados existan en el catálogo y produce `preferences`.

No aplica `puedeMatricular`; esa responsabilidad corresponde a `candidates.rkt`.

## `src/domain/candidates.rkt`

**Tipo:** puro.

Cruza `catalog` y `preferences` para producir una lista de `candidate-course`.

Responsabilidades:

- conservar únicamente cursos de interés;
- aplicar `puedeMatricular`;
- conservar únicamente grupos permitidos;
- preservar créditos, carrera, correquisitos pendientes y conflictos necesarios.

No genera combinaciones.

## `src/domain/conflicts.rkt`

**Tipo:** puro.

Determina compatibilidad entre selecciones utilizando únicamente los `choques` provenientes de C.

No procesa horarios.

## `src/domain/corequisites.rkt`

**Tipo:** puro.

Valida los `pending-corequisites` almacenados en las selecciones contra los códigos presentes en una combinación.

No consulta archivos ni recalcula correquisitos académicos.

## `src/domain/credits.rkt`

**Tipo:** puro.

Responsable de:

- calcular créditos de nuevas combinaciones cuando corresponda;
- comprobar el rango inclusivo.

## `src/generation/combinations.rkt`

**Tipo:** puro / lazy.

Responsable de la generación recursiva mediante streams.

Debe:

- permitir omitir un curso candidato;
- permitir incluirlo con exactamente uno de sus grupos;
- consultar `conflicts.rkt` antes de extender una combinación;
- podar inmediatamente ramas con choques;
- evitar combinaciones duplicadas;
- devolver un stream lazy.

No realiza I/O.

## `src/functional/stream-utils.rkt`

**Tipo:** puro / genérico.

Contiene utilidades reutilizables sobre streams.

Incluye obligatoriamente `stream-select` con contrato paramétrico.

## `src/io/combination-writer.rkt`

**Tipo:** I/O.

Consume progresivamente un stream de `combination` y escribe el JSON de salida.

No debe materializar todas las combinaciones en memoria y no recalcula reglas de negocio.

---

# 26. Interfaces públicas planeadas

La siguiente notación describe las fronteras que deberán reflejarse mediante `contract-out`.

```text
read-catalog-json
path-string? -> result?
```

```text
read-preferences-json
path-string? × catalog? -> result?
```
Los readers utilizan `Result` para representar errores esperados de lectura o
validación.

En caso de éxito:

```text
read-catalog-json
→ (result-ok catalog)

read-preferences-json
→ (result-ok preferences)
En caso de error:
→ (result-err mensaje)
```
---------------------------------------------------------
```text
build-candidates
catalog? × preferences? -> (listof candidate-course?)
```

```text
selection-compatible?
selection? × (listof selection?) -> boolean?
```

```text
corequisites-valid?
combination? -> boolean?
```

`corequisites-valid?` puede operar únicamente sobre `combination?` porque cada `selection` conserva sus `pending-corequisites`.

```text
generate-combinations
(listof candidate-course?) -> (stream/c combination?)
```

```text
credits-in-range?
preferences? × combination? -> boolean?
```

```text
stream-select
∀A.
(A -> boolean?)
× Stream<A>
-> Stream<A>
```

Su implementación contractual utiliza `parametric->/c` y `stream/c`.

```text
write-combinations-json
path-string? × (stream/c combination?) -> void?
```

Los nombres y responsabilidades de estas interfaces quedan congelados conceptualmente. Ajustes menores de sintaxis exigidos por Racket pueden realizarse únicamente si no alteran la semántica definida aquí.

---

# 27. Dependencias permitidas

Dependencias conceptuales:

```text
models
  ↑
  │
io readers
  │
  ▼
domain
  │
  ▼
generation
  │
  ▼
io writer
```

Reglas:

- `models/` no depende de `io/`;
- `models/contracts.rkt` no depende de módulos de dominio;
- `domain/` no depende de archivos ni de JSON;
- `generation/` no depende del parser JSON;
- `generation/combinations.rkt` puede depender de `domain/conflicts.rkt` y de los modelos;
- `domain/corequisites.rkt` y `domain/credits.rkt` operan sobre modelos, no sobre jsexpr;
- `combination-writer.rkt` no depende de los readers;
- `main.rkt` puede depender de todos los módulos públicos necesarios para orquestar el flujo;
- los tests pueden depender directamente del módulo que prueban;
- no se permiten dependencias circulares;
- ningún módulo de Racket depende de archivos fuente del repositorio de C.

---

# 28. Paralelización del trabajo

Una vez aprobados este contrato y los modelos con contratos públicos, el equipo puede trabajar en paralelo.

```text
                 CONTRATO MAESTRO
                        │
                        ▼
             MODELOS + CONTRATOS
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
    catalog I/O preferences-reader  stream-utils
          │             │             │
          └──────┬──────┘             │
                 ▼                    │
            candidates                │
                 │                    │
          ┌──────┴──────┐             │
          ▼             ▼             ▼
     conflicts      corequisites     writer
          │             │             │
          └──────┬──────┘             │
                 ▼                    │
          combinations ───────────────┘
                 │
                 ▼
             integración
```

El equipo que mantenga o adapte la Etapa 1 puede generar el JSON real en paralelo. Los desarrolladores de Etapa 2 trabajan contra fixtures que cumplen el mismo contrato hasta el momento de la integración real.

Los módulos pueden probarse con fixtures sin esperar a que todos los demás estén terminados.

---

# 29. Ejemplo mínimo completo

## Catálogo

```json
{
  "schemaVersion": "2.0",
  "carrera": {
    "codigo": "IC",
    "nombre": "Ingeniería en Computadores"
  },
  "cursos": [
    {
      "codigo": "A",
      "nombre": "Curso A",
      "carrera": "IC",
      "creditos": 4,
      "semestre": 2,
      "requisitos": [],
      "correquisitos": [],
      "correquisitosPendientes": [],
      "grupos": [
        {
          "numero": 1,
          "horarios": [],
          "tieneChoque": false,
          "choques": []
        },
        {
          "numero": 2,
          "horarios": [],
          "tieneChoque": false,
          "choques": []
        }
      ],
      "tieneChoque": false,
      "puedeMatricular": true
    }
  ]
}
```

## Preferencias

```json
{
  "schemaVersion": "2.0",
  "creditos": {
    "min": 4,
    "max": 8
  },
  "cursosInteres": [
    {
      "curso": "A",
      "grupos": [1, 2]
    }
  ]
}
```

## Stream conceptual generado

```text
Combination
└── A-G1

Combination
└── A-G2
```

## Salida

```json
{
  "schemaVersion": "1.0",
  "combinaciones": [
    {
      "selecciones": [
        {
          "curso": "A",
          "grupo": 1,
          "carrera": "IC"
        }
      ],
      "creditosTotales": 4
    },
    {
      "selecciones": [
        {
          "curso": "A",
          "grupo": 2,
          "carrera": "IC"
        }
      ],
      "creditosTotales": 4
    }
  ]
}
```

---

# 30. Caso mínimo con conflicto

```text
A-G1 choca con B-G2
```

Durante generación:

```text
[]
 ↓
A-G1
 ↓ intentar agregar B-G2
¿choca?
 ↓
sí
 ↓
rama descartada
```

La combinación `A-G1 + B-G2` nunca llega al stream de resultados válidos.

---

# 31. Caso mínimo con correquisito pendiente

```text
A.pending-corequisites = [B]
```

`A-G1` solo es inválida.

`A-G1 + B-G2` puede ser válida si ambos cursos son candidatos, sus grupos no chocan y cumple el rango de créditos.

---

# 32. Reglas que quedan bloqueadas por este contrato

```text
Racket no lee TSV.
Racket no lee historial.
Racket no recalcula requisitos.
Racket no recalcula choques usando horarios.
Racket consume puedeMatricular.
Racket consume choques grupo-grupo.
Racket consume correquisitosPendientes.
Etapa 2 vive en un repositorio independiente de Etapa 1.
La integración C -> Racket ocurre únicamente mediante JSON.
La ruta del catálogo se recibe por línea de comandos.
Las pruebas de Racket pueden utilizar fixtures propios del contrato JSON.
Una ejecución procesa un catálogo de una carrera.
Cada curso conserva su carrera de origen.
Las combinaciones utilizan un subconjunto de cursos de interés.
Una combinación final nunca es vacía.
Cada curso incluido tiene exactamente un grupo.
Los grupos se restringen a los indicados en preferencias.
Los choques se podan durante la generación.
Los correquisitos pendientes deben aparecer en la combinación final.
Racket no agrega automáticamente cursos ausentes de preferencias.
El rango de créditos es inclusivo.
No se utiliza mutación.
La implementación utiliza #lang racket.
Los modelos son structs inmutables.
Las interfaces públicas se protegen mediante contratos de Racket.
El generador retorna un stream lazy de combinaciones.
El writer consume el stream directamente.
No se materializa el stream completo antes de escribir.
La función polimórfica utiliza un contrato paramétrico.
JSON es el contrato de salida hacia Prolog.
```

---

# 33. Política de cambios

Este archivo es un contrato versionado.

Después de ser aprobado por los integrantes:

- ningún módulo puede cambiar unilateralmente una interfaz pública;
- ningún módulo puede reinterpretar la semántica de combinación;
- cambios al JSON requieren actualizar el `schemaVersion` cuando rompan compatibilidad;
- cambios de arquitectura deben actualizar primero este documento;
- las historias dependientes se implementan contra la versión aprobada del contrato.

Cambios compatibles pueden incrementar una versión menor del contrato:

```text
1.0 -> 1.1
```

Cambios incompatibles:

```text
1.x -> 2.0
```

---

# 34. Criterios de aceptación de KAN-E2-01

La historia se considera terminada cuando:

- [ ] existe `docs/contracts/Contrato_Arquitectura_Etapa2.md`;
- [ ] el equipo revisó propósito y alcance;
- [ ] se definieron responsabilidades de C y Racket;
- [ ] se documentó que Etapa 2 vive en un repositorio independiente;
- [ ] se documentó que la única integración con C es mediante JSON;
- [ ] se documentó el uso de fixtures para desarrollo autónomo;
- [ ] existe un diagrama completo del flujo;
- [ ] está definido el JSON exacto proveniente de C;
- [ ] está definido el JSON exacto de preferencias;
- [ ] está definido el JSON exacto hacia Prolog;
- [ ] está definida la versión soportada del input de C;
- [ ] están definidos los modelos conceptuales e inmutables;
- [ ] está definida la semántica exacta de una combinación;
- [ ] está definida la regla de un grupo por curso;
- [ ] está definida la interpretación de choques;
- [ ] está definido el tratamiento de `puedeMatricular`;
- [ ] está definido el tratamiento de `correquisitosPendientes`;
- [ ] está definido el rango inclusivo de créditos;
- [ ] se prohíbe explícitamente la mutación;
- [ ] se define el uso de streams lazy reales;
- [ ] se define `#lang racket` como lenguaje de implementación;
- [ ] se define el sistema de contratos de Racket como estrategia de modelado explícito;
- [ ] se define `contract-out` para las interfaces públicas;
- [ ] se define `stream/c` para streams en interfaces públicas;
- [ ] se define la función polimórfica planeada con `parametric->/c`;
- [ ] están definidos errores conceptuales;
- [ ] está definida la estructura de carpetas del repositorio independiente;
- [ ] están definidos los módulos y sus responsabilidades;
- [ ] están definidas las interfaces públicas planeadas;
- [ ] se distingue explícitamente entre módulos puros y módulos de I/O;
- [ ] existen ejemplos mínimos de catálogo, preferencias y salida;
- [ ] los tres integrantes aprobaron el contrato antes de comenzar historias dependientes.

---

# 35. Resultado de esta historia

Después de aprobar KAN-E2-01, el proyecto posee una única fuente de verdad para iniciar el desarrollo de Etapa 2.

A partir de este punto, las siguientes historias pueden desarrollarse sin redefinir:

```text
qué recibe Racket
qué produce Racket
qué significa una combinación
qué información pertenece a C
qué información pertenece a Etapa 2
cómo se representan los modelos
cómo se interpretan los conflictos
cómo se manejan los correquisitos
cómo se filtran créditos
cómo se utilizan streams
cómo se aplica el paradigma funcional
qué módulos pueden trabajar en paralelo
```
