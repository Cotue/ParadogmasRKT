# CEmestre - Etapa 2: Generador de Combinaciones de Horario

## Documentación Técnica y Arquitectura del Sistema (Paradigma Funcional)

**Curso:** Paradigmas de Programación (CE1106)
**Lenguaje:** Racket 9.3 (`#lang racket`)
**Estrategia de Tipado:** Contratos explícitos (`racket/contract`)
**Ecosistema:** Proyecto CEmestre - Etapa 2

---

## 1. Visión General y Propósito

En esta segunda etapa del proyecto **CEmestre**, construimos el módulo en Racket encargándose de procesar la salida que nos generó el módulo de C (el catálogo de cursos con sus choques calculados) junto con un archivo de preferencias de matrícula que define el estudiante.

El objetivo principal de nuestro programa es explorar todas las posibles combinaciones de horarios de forma perezosa (*lazy evaluation*). Filtramos los choques entre grupos, validamos que se cumplan los correquisitos pendientes y que el total de créditos quede dentro del rango deseado. Finalmente, exportamos los resultados a un JSON que servirá de insumo para la Etapa 3 en Prolog.

Diseñamos todo el sistema siguiendo los principios de la programación funcional pura: nada de mutación, separación clara de responsabilidades y flujo de datos a través de *streams*.

---

## 2. Arquitectura del Sistema

Organizamos el código usando un patrón de tubería (*pipeline*) funcional. El flujo de datos es unidireccional y está dividido en capas desacopladas:

```text
┌─────────────────────────────────────────────────────────────────┐
│                      Capas de Entrada (I/O)                     │
│   catalogo.json (C)                   preferencias.json (User)  │
└─────────┬───────────────────────────────────────┬───────────────┘
          │                                       │
          ▼                                       ▼
┌──────────────────┐                    ┌──────────────────┐
│  catalog-reader  │                    │preferences-reader│
└─────────┬────────┘                    └─────────┬────────┘
          │ (catalog)                             │ (preferences)
          └───────────────────┬───────────────────┘
                              ▼
                ┌───────────────────────────┐
                │   domain/candidates.rkt   │
                └─────────────┬─────────────┘
                              │ List<candidate-course>
                              ▼
                ┌───────────────────────────┐
                │ generation/combinations   │ ◄─── Poda temprana de
                └─────────────┬─────────────┘      conflictos
                              │ Stream<combination>
                              ▼
                ┌───────────────────────────┐
                │ functional/stream-utils   │ ◄─── stream-select
                └─────────────┬─────────────┘      (Paramétrico)
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
          ┌──────────────────┐ ┌──────────────────┐
          │   corequisites   │ │  credits-filter  │
          └─────────┬────────┘ └─────────┬────────┘
                    │                    │
                    └─────────┬──────────┘
                              │ Stream<combination> filtrado
                              ▼
                ┌───────────────────────────┐
                │ io/combination-writer.rkt │
                └─────────────┬─────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Salida Final (I/O)                       │
│                     combinaciones_validas.json                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 Módulos y Responsabilidades

* **`src/models/`**: Contiene los structs inmutables y los contratos del dominio (`contracts.rkt`, `catalog.rkt`, `preferences.rkt`, `combination.rkt`, `result.rkt`). Ningún módulo de esta capa realiza I/O.
* **`src/io/`**: Administra la lectura y escritura. Valida la estructura JSON de entrada, parsea los datos a nuestros modelos y serializa el resultado hacia el archivo de salida.
* **`src/domain/`**: Concentra las reglas de negocio en funciones puras (`candidates.rkt`, `conflicts.rkt`, `corequisites.rkt`, `credits.rkt`).
* **`src/generation/`**: Contiene el algoritmo recursivo que genera las combinaciones sobre `racket/stream`.
* **`src/functional/`**: Herramientas genéricas sobre streams, como nuestro filtro paramétrico (`stream-utils.rkt`).
* **`src/main.rkt`**: El punto de entrada por línea de comandos (CLI). Orquesta la lectura, procesamiento y escritura.

---

## 3. Decisiones de Diseño

### 3.1 Justificación de Decisiones Técnicas

1. **Uso de Streams en lugar de Listas:**
   Como la cantidad de combinaciones puede crecer de forma exponencial, cargar todo en memoria en una lista tradicional habría provocado un desbordamiento de memoria (*out-of-memory*) con catálogos grandes. Nos decidimos por `racket/stream` y construcciones perezosas (`stream-cons`), lo que nos permite ir generando y guardando en disco combinación por combinación manteniendo el consumo de memoria muy bajo $O(1)$.

2. **Poda Temprana de Conflictos (*Early Pruning*):**
   En lugar de armar todas las combinaciones posibles y descartar al final las que tienen choques de horario, decidimos revisar los conflictos en el momento en que intentamos agregar un nuevo grupo a la combinación parcial. Si el grupo choca con alguno de los que ya habíamos seleccionado, descartamos esa rama de inmediato y no seguimos explorando por ahí.

3. **Modelos Autosuficientes:**
   Diseñamos la estructura de cada selección (`selection`) de modo que guarde sus propios créditos, carrera y correquisitos pendientes. De esta forma, cuando evaluamos una combinación entera no tenemos que devolvernos a hacer búsquedas en el catálogo ni realizar I/O.

4. **Manejo de Errores con `Result`:**
   Para evitar que el programa se caiga con excepciones feos al leer archivos inválidos, creamos una estructura `Result` (`result-ok` | `result-err`) en `src/models/result.rkt`. Esto nos permite manejar los errores de formato o sintaxis de forma puramente funcional.

### 3.2 Caso Límite Real y Cómo lo Resolvimos

* **El Problema:**
   Nos topamos con un caso límite complejo al validar los *Correquisitos Pendientes en Cadenas o Ciclos* (por ejemplo, si el curso $A$ requiere a $B$, y el curso $B$ requiere a $C$). Teníamos el riesgo de caer en ciclos infinitos de verificación o de tener que hacer lecturas repetidas al catálogo para resolver dependencias encadenadas.

* **Nuestra Solución:**
   Aprovechamos que cada `selection` guarda inmutablemente sus correquisitos pendientes en `selection-pending-corequisites`. Diseñamos el predicado `corequisites-satisfied?` para que trabaje directo sobre la combinación armada: recolecta todos los cursos que están presentes en esa combinación y revisa que contengan todos los correquisitos pendientes solicitados por cada uno de ellos. Si falta algún correquisito (porque el estudiante no lo puso en sus preferencias o no podía matricularlo), la combinación simplemente no se da por válida. Con esto evitamos cualquier recursión infinita o ciclo.

### 3.3 Justificación del Formato de Salida JSON (`schemaVersion: "2.0"`)

Elegimos serializar la salida en formato JSON con la versión de esquema `"2.0"` por dos razones principales:

1. **Facilidad de integración con Prolog:** JSON es un estándar fácil de parsear desde la siguiente etapa del proyecto, lo que independiza a Prolog de las estructuras internas de Racket.
2. **Escritura progresiva (Lazy):** Implementamos la escritura en `combination-writer.rkt` usando recursión de cola sobre el puerto de salida (`write-combinations-to-port`). Conforme el stream produce una combinación, esta se escribe al archivo de inmediato, lo que nos evitó tener que convertir el stream a una lista en memoria (`stream->list`).

---

## 4. Estructuras de Datos Desarrolladas

Definimos todos nuestros modelos de dominio como estructuras **transparentes e inmutables** (`#:transparent`):

```racket
;; Clave para identificar un grupo en el catálogo
(struct group-key (course-code group-number) #:transparent)

;; Opción de grupo de un curso con sus choques calculados por C
(struct group-option (number conflicts) #:transparent)

;; Curso tal como viene del catálogo
(struct course (code career credits can-enroll? pending-corequisites groups) #:transparent)

;; Curso filtrado (elegible para matricular según C y preferencias)
(struct candidate-course (code career credits pending-corequisites groups) #:transparent)

;; Preferencias de créditos y cursos elegidos por el estudiante
(struct preferences (min-credits max-credits courses) #:transparent)

;; Decisión puntual de llevar un curso en un grupo específico
(struct selection (course-code group-number career credits pending-corequisites conflicts) #:transparent)

;; Combinación resultante de horario
(struct combination (selections total-credits) #:transparent)
```

---

## 5. Tipado Explícito y Polimorfismo Paramétrico

### 5.1 Sistema de Contratos Explícitos

Para cumplir con el requerimiento de tipado explícito sin complicar el uso de la librería de streams de Racket, aseguramos las interfaces públicas de los módulos usando `provide/contract`. Definimos contratos para los tipos primitivos del dominio (`course-code/c`, `group-number/c`, `credits/c`, `career-code/c`).

### 5.2 Función con Polimorfismo Paramétrico

Implementamos nuestra función genérica de filtrado en `src/functional/stream-utils.rkt` utilizando contratos paramétricos con `parametric->/c`:

```racket
(provide
 (contract-out
  [stream-select
   (parametric->/c [A]
     (-> (-> A boolean?)
         (stream/c A)
         (stream/c A)))]))

(define (stream-select predicate source-stream)
  (stream-filter predicate source-stream))
```

Esta función no sabe ni le importa qué tipo de dato $A$ está procesando. Gracias a eso, la reutilizamos para aplicar tanto el filtro de correquisitos (`corequisites-satisfied?`) como el filtro de rango de créditos (`credits-in-range?`) sobre los streams.

---

## 6. Verificación de Inmutabilidad

Nos aseguramos de respetar el paradigma funcional puro en todo el proyecto:

* **0 usos** de funciones de mutación (`set!`, `set-box!`, `vector-set!`, `hash-set!`).
* Todo el estado se maneja mediante recursión de cola, acumuladores y evaluación sobre *streams*.

---

## 7. Compilación, Pruebas y Ejecución

### 7.1 Requisitos

* **Racket**: Versión 9.3 o superior con `racket` y `raco` configurados en el PATH.

### 7.2 Compilación

Para compilar el proyecto y verificar que no existan errores de sintaxis:

```bash
raco make src/main.rkt
```

### 7.3 Ejecución de Pruebas Automáticas

Para correr todas las pruebas unitarias y de integración que desarrollamos:

```bash
raco test tests
```

### 7.4 Ejecución del Programa (CLI)

El ejecutable recibe tres argumentos por línea de comandos:

```bash
racket src/main.rkt <ruta-catalogo.json> <ruta-preferencias.json> <ruta-salida.json>
```

#### Ejemplo de uso:

```bash
racket src/main.rkt \
  tests/fixtures/catalog/real_computadores.json \
  tests/fixtures/preferences/valid.json \
  data/output/combinaciones_validas.json
```
