# Contrato de unificación de modelos — CEmestre Etapa 2

**Versión del contrato:** 1.0
**Etapa:** 2 — Paradigma funcional
**Lenguaje:** Racket 9.3 (`#lang racket`) con contratos explícitos
**Rol del documento:** Registrar la unificación arquitectónica realizada después de las historias de modelos, lector de catálogo y lector de preferencias, y establecer las consideraciones obligatorias para las historias posteriores.

---

## 1. Propósito

Este documento complementa el **Contrato maestro de arquitectura y flujo — CEmestre Etapa 2**.

No sustituye al contrato maestro ni redefine la semántica general de Etapa 2.

Su propósito es documentar la unificación realizada entre los modelos de dominio y los módulos de lectura implementados durante las historias correspondientes a:

- definición de modelos y contratos;
- lectura y validación del catálogo JSON;
- lectura y validación de preferencias.

La unificación elimina representaciones duplicadas del mismo dominio y establece una única familia de estructuras que deberán utilizar las historias posteriores.

Este documento sirve como referencia para desarrolladores, diseñadores y herramientas de IA que necesiten continuar el desarrollo sin asumir estructuras antiguas o duplicadas.

---

## 2. Problema previo a la unificación

Durante el desarrollo inicial coexistieron dos representaciones del dominio.

Por un lado se encontraban los modelos canónicos:

```text
src/models/contracts.rkt
src/models/result.rkt
src/models/catalog.rkt
src/models/preferences.rkt
src/models/combination.rkt
```

Por otro lado existía:

```text
src/models/types.rkt
```

Este último definía una segunda familia de estructuras para conceptos como:

```text
catalog
course
group
Result
```

Aunque algunos conceptos tenían nombres similares, para Racket constituían estructuras diferentes.

Esto provocaba que un catálogo producido por los readers no pudiera utilizarse directamente por módulos construidos contra los modelos canónicos.

---

## 3. Decisión de unificación

A partir de esta unificación:

> Los módulos ubicados en `src/models/` constituyen la única representación válida del dominio de Etapa 2.

El archivo:

```text
src/models/types.rkt
```

fue eliminado.

Ninguna historia posterior debe:

- volver a crear `types.rkt`;
- definir otra estructura `catalog` paralela;
- definir otra estructura `course` paralela;
- crear una segunda representación de grupos;
- crear una segunda implementación de `Result`;
- introducir conversiones entre dos modelos equivalentes del dominio.

Si una historia futura necesita información nueva, primero debe determinarse si realmente corresponde modificar el modelo canónico.

---

## 4. Modelos que constituyen la fuente de verdad

Los modelos actuales son:

```text
src/models/contracts.rkt
src/models/result.rkt
src/models/catalog.rkt
src/models/preferences.rkt
src/models/combination.rkt
```

### `contracts.rkt`

Contiene contratos reutilizables para valores simples del dominio:

```text
course-code/c
career-code/c
group-number/c
credits/c
```

### `result.rkt`

Contiene la representación común de operaciones que pueden producir éxito o error:

```text
result-ok
result-err
result?
```

No deben definirse versiones alternativas de estas estructuras.

### `catalog.rkt`

Contiene:

```text
group-key
group-option
course
catalog
candidate-course
```

### `preferences.rkt`

Contiene:

```text
course-preference
preferences
```

### `combination.rkt`

Contiene:

```text
selection
combination
```

Las definiciones conceptuales detalladas de estos modelos continúan correspondiendo al contrato maestro.

---

## 5. Cambio en el flujo del catálogo

Antes de la unificación, el lector transformaba el JSON a estructuras pertenecientes al modelo legacy.

Conceptualmente:

```text
JSON de C
   ↓
estructuras de types.rkt
   ↓
modelo separado del dominio canónico
```

Después de la unificación:

```text
JSON de C
   ↓
json_reader.rkt
   ↓
validación
   ↓
models/catalog.rkt::catalog
```

El catálogo producido por los readers es ahora directamente el catálogo utilizado por las historias posteriores.

No existe una segunda fase de conversión entre modelos.

---

## 6. Transformación del JSON al modelo canónico

El JSON producido por C contiene más información que la necesaria dentro de los structs utilizados por la lógica funcional.

Etapa 2 continúa recibiendo del JSON información como:

```text
nombre
semestre
requisitos
correquisitos
correquisitosPendientes
horarios
tieneChoque
choques
puedeMatricular
creditos
carrera
grupos
```

La unificación **no modifica el contrato de intercambio con C**.

Sin embargo, `json_reader.rkt` conserva dentro del modelo canónico únicamente la información utilizada por las etapas posteriores:

```text
catalog
├── schema-version
├── career-code
└── courses
    ├── code
    ├── career
    ├── credits
    ├── can-enroll?
    ├── pending-corequisites
    └── groups
        ├── number
        └── conflicts
            ├── course-code
            └── group-number
```

La ausencia de otros campos dentro de los structs no significa que hayan sido eliminados del JSON de entrada.

---

## 7. Información deliberadamente no almacenada

### Nombre del curso

No participa actualmente en:

- construcción de candidatos;
- generación de combinaciones;
- validación de conflictos;
- correquisitos;
- créditos;
- salida hacia Prolog.

El código del curso constituye su identidad funcional.

### Semestre

La selección del alcance académico corresponde a la Etapa 1.

Etapa 2 no vuelve a filtrar cursos por semestre.

### Requisitos

Etapa 2 no vuelve a calcular elegibilidad académica.

Consume el resultado:

```text
puedeMatricular
```

como:

```text
can-enroll?
```

### Correquisitos completos

La lógica posterior trabaja con:

```text
correquisitosPendientes
```

representados como:

```text
pending-corequisites
```

No necesita volver a determinar cuáles correquisitos ya fueron satisfechos.

### Horarios

Etapa 2 no compara día, hora de inicio ni hora final para descubrir choques.

Consume las relaciones de choque calculadas previamente por C.

### `tieneChoque`

La lógica funcional necesita conocer **con qué grupo específico existe el conflicto**, no únicamente si algún conflicto existe.

Por esa razón se conservan las referencias detalladas:

```text
(course-code, group-number)
```

mediante `group-key`.

### Nombre de carrera

La lógica posterior utiliza el código de carrera.

Cada curso conserva explícitamente su carrera de origen.

---

## 8. Cambios realizados por módulo

### `src/io/json_reader.rkt`

Se eliminó la dependencia de:

```text
models/types.rkt
```

y se reemplazó por:

```text
models/result.rkt
models/catalog.rkt
```

El mapping cambió conceptualmente de:

```text
schedule
group-conflict
group
course legacy
catalog legacy
```

a:

```text
group-key
group-option
course
catalog
```

El reader produce directamente el modelo canónico.

---

### `src/io/catalog.rkt`

Dejó de depender de `types.rkt`.

Utiliza la representación compartida de:

```text
result.rkt
```

---

### `src/domain/preferences-validators.rkt`

Dejó de utilizar accessors pertenecientes al modelo legacy.

Ahora opera directamente sobre:

```text
models/catalog.rkt
```

Los números de grupo se obtienen mediante:

```text
group-option-number
```

---

### `src/io/preferences-reader.rkt`

Ahora trabaja con:

```text
models/result.rkt
models/catalog.rkt
models/preferences.rkt
```

Por tanto, el catálogo recibido por el lector de preferencias es el mismo catálogo utilizado por el resto de Etapa 2.

---

### Tests

Los tests de catálogo y preferencias fueron actualizados para utilizar los modelos canónicos.

Entre los cambios de nomenclatura realizados se encuentran:

```text
course-carrera
→ course-career
```

y:

```text
course-can-enroll
→ course-can-enroll?
```

La intención funcional de los tests no fue modificada.

---

## 9. Estado verificado después de la unificación

Después de eliminar `src/models/types.rkt` se ejecutó la suite completa.

Resultado:

```text
85 tests passed
```

También se verificó que no existieran referencias a:

```text
types.rkt
```

dentro de:

```text
src/
tests/
```

Además, se verificó que la implementación no utilice:

```text
set!
#:mutable
```

El estado anterior constituye el nuevo punto de partida para las historias posteriores.

---

## 10. Reglas para las siguientes historias

### Utilizar únicamente modelos canónicos

Antes de crear cualquier nuevo `struct`, debe comprobarse si el concepto ya existe dentro de `src/models/`.

No deben duplicarse:

```text
catalog
course
group-option
candidate-course
preferences
selection
combination
Result
```

---

### Construcción de candidatos

La historia encargada de candidatos debe trabajar conceptualmente como:

```text
catalog + preferences
        ↓
listof candidate-course
```

Debe:

- recorrer los cursos respetando el orden de preferencias;
- buscar el curso correspondiente dentro del catálogo;
- excluir cursos cuyo `can-enroll?` sea falso;
- conservar únicamente los grupos permitidos por las preferencias;
- conservar carrera;
- conservar créditos;
- conservar correquisitos pendientes;
- conservar las referencias de conflictos existentes.

No debe:

- recalcular requisitos;
- recalcular elegibilidad;
- comparar horarios;
- validar correquisitos de una combinación;
- generar combinaciones.

---

### Significado de `candidate-course`

`candidate-course` no contiene `can-enroll?`.

Esto es deliberado.

La presencia de un curso dentro de la lista de candidatos significa que ya pasó la regla:

```text
can-enroll? = #t
```

---

### Conflictos

La identidad de un grupo debe considerarse siempre:

```text
(course-code, group-number)
```

No debe utilizarse únicamente el número de grupo como identidad global.

Las historias de conflictos deben trabajar con las referencias detalladas producidas por C.

No deben reconstruir conflictos a partir de horarios.

---

### Correquisitos

Las historias posteriores utilizan:

```text
pending-corequisites
```

No la lista original completa de correquisitos académicos.

Si un curso seleccionado requiere otro curso pendiente, la combinación final deberá contenerlo.

Racket no agrega automáticamente cursos que no pertenezcan al conjunto permitido de candidatos.

---

### Preferencias

Una preferencia como:

```text
CE1101 → grupos [1, 2]
```

significa:

> Si CE1101 aparece en una combinación, solo puede utilizar uno de esos grupos.

No significa que CE1101 deba aparecer en todas las combinaciones.

---

### Créditos

El rango continúa siendo inclusivo:

```text
min-credits <= total-credits <= max-credits
```

---

### Inmutabilidad

Las historias posteriores deben mantener el paradigma funcional.

No deben introducir:

```text
set!
set-box!
#:mutable
```

ni mecanismos equivalentes de mutación dentro de la lógica de dominio.

---

### Streams

La generación de combinaciones debe producir un stream lazy real.

No debe:

```text
generar todas las combinaciones como lista
↓
convertir la lista completa a stream
```

El stream debe construirse progresivamente durante la generación.

---

## 11. Separación de responsabilidades

Las historias posteriores deben mantener la separación establecida por el contrato maestro.

### Etapa 1 — C

Responsable de calcular información académica y temporal como:

```text
elegibilidad
correquisitos pendientes
choques de horario
```

### Etapa 2 — Racket

Responsable de consumir esos resultados para:

```text
construir candidatos
generar combinaciones
podar conflictos
validar correquisitos pendientes
filtrar créditos
generar la salida hacia Prolog
```

Etapa 2 no debe volver a leer TSV ni historial ni reconstruir decisiones académicas ya calculadas por C.

---

## 12. Dependencias

Los modelos constituyen una capa base.

Conceptualmente:

```text
models
  ↑
  │
readers
  │
  ▼
domain
  │
  ▼
generation
  │
  ▼
writer / main
```

Los módulos dentro de `models/` no deben depender de:

```text
io/
domain/
generation/
tests/
```

Los módulos de dominio no deben leer directamente archivos JSON.

---

## 13. Señales de alerta para futuras revisiones

Debe detenerse y revisarse una implementación si aparece alguno de los siguientes patrones.

### Referencia al modelo eliminado

```text
require ".../models/types.rkt"
```

### Nuevos modelos paralelos

```racket
(struct catalog ...)
```

o:

```racket
(struct course ...)
```

fuera del módulo canónico correspondiente.

### Recalcular conflictos mediante

```text
dia
inicio
fin
```

### Recalcular elegibilidad utilizando

```text
requisitos
correquisitos
historial
```

### Crear un segundo tipo de éxito/error

Por ejemplo:

```text
Success
Failure
Ok
Error
```

cuando la operación ya puede utilizar `Result`.

### Convertir un catálogo a otro catálogo equivalente

Una conversión:

```text
catalog-A
   ↓
catalog-B
```

dentro de Etapa 2 indicaría probablemente que se está creando nuevamente una arquitectura duplicada.

---

## 14. Política de cambios futuros

La existencia de una nueva historia no justifica por sí sola modificar un modelo canónico.

Antes de agregar o eliminar campos debe analizarse:

1. si la información ya existe;
2. qué módulo es responsable de producirla;
3. si pertenece realmente a Etapa 2;
4. si puede calcularse sin almacenarla;
5. qué interfaces públicas cambiarían;
6. qué historias existentes dependen del modelo;
7. qué tests deben modificarse;
8. qué contratos deben actualizarse.

Cambiar la estructura de:

```text
course
catalog
group-option
candidate-course
preferences
selection
combination
```

se considera un cambio arquitectónico y debe revisarse de forma coordinada.

---

## 15. Checklist para implementar historias posteriores

Antes de comenzar una nueva historia debe responderse:

- [ ] ¿Qué modelo canónico recibe?
- [ ] ¿Qué modelo canónico produce?
- [ ] ¿Existe ya la información necesaria?
- [ ] ¿Estoy duplicando una estructura existente?
- [ ] ¿Estoy recalculando algo que corresponde a C?
- [ ] ¿La función puede permanecer pura?
- [ ] ¿Estoy preservando la inmutabilidad?
- [ ] ¿Estoy utilizando `(curso, grupo)` como identidad?
- [ ] ¿Estoy utilizando `pending-corequisites`?
- [ ] ¿Estoy utilizando los conflictos detallados existentes?
- [ ] ¿Estoy respetando el orden determinista de preferencias?
- [ ] ¿Estoy respetando la semántica de subconjuntos de cursos?
- [ ] ¿Estoy respetando el rango inclusivo de créditos?
- [ ] ¿Estoy manteniendo lazy evaluation cuando corresponde?
- [ ] ¿Los tests existentes continúan pasando?

---

## 16. Relación con otros contratos

Este documento **no reemplaza**:

```text
Contrato maestro de arquitectura y flujo — CEmestre Etapa 2
Contrato del lector y validador del catálogo
Contrato del lector de preferencias
contratos específicos de las historias posteriores
```

El contrato maestro continúa definiendo la arquitectura general, la semántica de combinaciones, responsabilidades entre etapas, streams, errores y salida hacia Prolog.

Este contrato registra exclusivamente:

- la eliminación del modelo duplicado;
- la arquitectura resultante después de la unificación;
- la fuente de verdad de los modelos;
- las reglas que deben respetar las historias posteriores para mantener esa arquitectura.

Si aparece una contradicción entre documentos, no debe resolverse creando una nueva interpretación dentro del código.

La contradicción debe identificarse y resolverse explícitamente en los contratos correspondientes antes de modificar la arquitectura.

---

## 17. Resultado de la unificación

A partir de esta unificación:

```text
una representación de Catalog
una representación de Course
una representación de GroupOption
una representación de Preferences
una representación de CandidateCourse
una representación de Selection
una representación de Combination
una representación de Result
```

Los readers y los módulos posteriores comparten directamente estas estructuras.

Este estado constituye la base arquitectónica para continuar con las siguientes historias de usuario de Etapa 2.
