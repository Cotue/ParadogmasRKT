# Contrato KANE2-29: Integración Ejecutable de Etapa 2

**Versión:** 1.0
**Historia:** KANE2-29

## 1. Propósito

Proporcionar el punto de entrada ejecutable de la Etapa 2 de CEmestre.

El usuario entrega:

1. un catálogo JSON generado por la Etapa 1 en C;
2. un archivo JSON de preferencias;
3. una ruta para el archivo de salida.

La Etapa 2 conecta los módulos ya implementados para producir el archivo JSON que posteriormente consumirá Prolog.

KANE2-29 es una historia de **integración y orquestación**.

No implementa nuevamente ninguna regla de negocio ya resuelta por historias anteriores.

---

## 2. Ejecutable

Archivo:

```text
src/main.rkt
```

Interfaz desde terminal:

```text
racket src/main.rkt <catalogo.json> <preferencias.json> <salida.json>
```

Ejemplo:

```text
racket src/main.rkt \
  tests/fixtures/catalog/real_computadores.json \
  tests/fixtures/preferences/valid.json \
  data/output/combinaciones_validas.json
```

La ejecución requiere exactamente tres argumentos:

```text
1. ruta del catálogo;
2. ruta de preferencias;
3. ruta del archivo de salida.
```

---

## 3. Flujo Funcional

El flujo obligatorio es:

```text
catalogo.json
      ↓
read-catalog-json
      ↓
result-ok Catalog
      │
      ▼
preferencias.json
      ↓
read-preferences-json
      ↓
result-ok Preferences
      │
      ▼
build-candidates
      ↓
List<CandidateCourse>
      │
      ▼
generate-combinations
      ↓
Stream<Combination>
      │
      ▼
stream-select
corequisites-satisfied?
      ↓
Stream<Combination>
      │
      ▼
stream-select
credits-in-range?
      ↓
Stream<Combination>
      │
      ▼
write-combinations-json
      ↓
salida.json
```

No se permite alterar este flujo agregando cálculos de negocio dentro de `main.rkt`.

---

## 4. Interfaces Existentes Utilizadas

### 4.1 Catálogo

Módulo:

```text
src/io/catalog.rkt
```

Interfaz existente:

```text
read-catalog-json :
path-string? -> result?
```

Resultado válido:

```text
(result-ok catalog)
```

Resultado inválido:

```text
(result-err mensaje)
```

`main.rkt` no vuelve a validar el contenido del catálogo.

---

## 4.2 Preferencias

Módulo:

```text
src/io/preferences-reader.rkt
```

Interfaz existente:

```text
read-preferences-json :
path-string? × catalog? -> result?
```

Resultado válido:

```text
(result-ok preferences)
```

Resultado inválido:

```text
(result-err mensaje)
```

La lectura de preferencias se realiza únicamente después de haber obtenido correctamente el catálogo.

---

## 4.3 Construcción de candidatos

Módulo:

```text
src/domain/candidates.rkt
```

Interfaz:

```text
build-candidates :
catalog? × preferences?
-> (listof candidate-course?)
```

Esta función ya se encarga de:

- conservar cursos de interés;
- aplicar `can-enroll?`;
- conservar los grupos permitidos;
- preservar carrera;
- preservar créditos;
- preservar correquisitos pendientes;
- preservar conflictos.

`main.rkt` no repite estas operaciones.

---

## 4.4 Generación de combinaciones

Módulo:

```text
src/generation/combinations.rkt
```

Interfaz:

```text
generate-combinations :
(listof candidate-course?)
-> Stream<combination?>
```

El generador ya garantiza estructuralmente que:

- las combinaciones emitidas no son vacías;
- cada curso aparece como máximo una vez;
- cada curso seleccionado posee exactamente un grupo;
- se conserva la carrera;
- se calculan los créditos totales;
- las combinaciones emitidas no poseen choques;
- los conflictos se podan antes de continuar una rama;
- la generación es lazy.

`main.rkt` no vuelve a comprobar horarios ni conflictos.

---

## 4.5 Filtro de correquisitos

Módulo:

```text
src/domain/corequisites.rkt
```

Interfaz:

```text
corequisites-satisfied? :
combination? -> boolean?
```

Se aplica sobre el stream generado utilizando:

```text
stream-select
```

Conceptualmente:

```racket
(stream-select
 corequisites-satisfied?
 combinations)
```

Solo sobreviven combinaciones donde todos los correquisitos pendientes de cada selección están presentes.

---

## 4.6 Filtro de créditos

Módulo:

```text
src/domain/credits.rkt
```

Interfaz:

```text
credits-in-range? :
preferences? × combination? -> boolean?
```

Se aplica después del filtro de correquisitos:

```racket
(stream-select
 (lambda (comb)
   (credits-in-range? prefs comb))
 combinations-with-valid-corequisites)
```

El rango es inclusivo.

`main.rkt` no recalcula los créditos de una combinación.

---

## 4.7 Utilidad de streams

Módulo canónico:

```text
src/functional/stream-utils.rkt
```

Interfaz utilizada:

```text
stream-select
```

El archivo duplicado:

```text
src/domain/functional/stream-utils.rkt
```

no forma parte de la arquitectura y fue eliminado.

Todos los módulos deben utilizar exclusivamente:

```text
src/functional/stream-utils.rkt
```

---

## 4.8 Escritura de salida

Módulo:

```text
src/io/combination-writer.rkt
```

Interfaz:

```text
write-combinations-json :
path-string?
× Stream<combination?>
-> void?
```

El writer:

- consume el stream progresivamente;
- conserva el orden recibido;
- genera JSON válido;
- conserva carrera;
- escribe curso, grupo y carrera por selección;
- escribe créditos totales por combinación;
- no recalcula reglas de negocio.

El `schemaVersion` de salida pertenece al writer y `main.rkt` no debe duplicar esa constante.

---

## 5. Composición del Pipeline

Una vez obtenidos `catalog` y `preferences`, la composición conceptual es:

```racket
(define candidates
  (build-candidates catalog preferences))

(define generated
  (generate-combinations candidates))

(define with-corequisites
  (stream-select
   corequisites-satisfied?
   generated))

(define valid
  (stream-select
   (lambda (comb)
     (credits-in-range?
      preferences
      comb))
   with-corequisites))

(write-combinations-json
 output-path
 valid)
```

Esta composición representa la responsabilidad principal de KANE2-29.

---

## 6. Laziness

KANE2-29 debe conservar la evaluación perezosa existente.

Queda prohibido utilizar dentro de `src/main.rkt`:

```text
stream->list
stream-length
stream-count
```

o cualquier operación cuyo propósito sea materializar todas las combinaciones antes de escribirlas.

El pipeline debe permanecer:

```text
generate-combinations
        ↓
stream-select
        ↓
stream-select
        ↓
writer
```

sin conversiones intermedias a listas completas.

---

## 7. Invariantes del Resultado

Toda combinación escrita en la salida debe cumplir simultáneamente:

### 7.1 Sin choques

Ningún par de selecciones puede entrar en conflicto según las referencias producidas por C.

Esta propiedad es garantizada por `generate-combinations` utilizando `selection-compatible?`.

---

### 7.2 Sin cursos repetidos

Una combinación no puede contener dos selecciones correspondientes al mismo curso.

Esta propiedad es garantizada estructuralmente por el generador.

---

### 7.3 Exactamente un grupo por curso seleccionado

Cada selección representa:

```text
curso + grupo
```

El generador nunca incluye dos grupos del mismo curso dentro de una combinación.

---

### 7.4 Correquisitos satisfechos

Para cada selección:

```text
pending-corequisites
```

todos los códigos requeridos deben aparecer entre los cursos de la misma combinación.

Esto se garantiza mediante:

```text
corequisites-satisfied?
```

---

### 7.5 Créditos dentro del rango

Toda combinación escrita debe satisfacer:

```text
preferences.min-credits
<= combination.total-credits
<= preferences.max-credits
```

---

### 7.6 Carrera conservada

La carrera escrita para cada selección debe ser la misma carrera almacenada originalmente en el curso candidato y posteriormente en `selection`.

`main.rkt` no modifica este valor.

---

## 8. Stream Vacío

Es válido que después de aplicar:

```text
generación
→ correquisitos
→ créditos
```

no sobreviva ninguna combinación.

Esto no constituye un error.

El writer debe producir un archivo JSON válido cuya colección de combinaciones esté vacía.

---

## 9. Inmutabilidad

KANE2-29 mantiene el paradigma funcional utilizado por toda la Etapa 2.

Queda prohibido:

```text
set!
set-box!
vector-set!
hash-set!
set-car!
set-cdr!
```

También queda prohibido crear structs mutables o introducir estado global modificable.

Los valores se pasan entre módulos sin modificarlos.

---

## 10. Manejo de `Result`

Los readers utilizan el modelo:

```text
result-ok
result-err
```

definido en:

```text
src/models/result.rkt
```

El flujo debe detenerse cuando un reader devuelve `result-err`.

Ejemplo conceptual:

```text
read-catalog-json
     ↓
result-err
     ↓
mostrar error
terminar con estado no exitoso
```

No debe ejecutarse:

```text
read-preferences-json
build-candidates
generate-combinations
writer
```

si el catálogo no fue cargado correctamente.

Del mismo modo, si las preferencias producen `result-err`, no se inicia la generación.

---

## 11. Manejo de Errores Externos

El contrato maestro define conceptualmente las categorías:

```text
E2_ARGS
E2_INPUT_IO
E2_JSON_SYNTAX
E2_SCHEMA
E2_PREFERENCES
E2_OUTPUT_IO
```

### 11.1 Argumentos

Si la cantidad de argumentos es distinta de tres:

```text
E2_ARGS
```

La ejecución termina con estado distinto de cero y no intenta abrir archivos.

---

### 11.2 Errores devueltos por los readers

Los readers actuales encapsulan sus errores mediante:

```text
result-err mensaje
```

KANE2-29 debe:

- mostrar el mensaje recibido;
- detener el pipeline;
- terminar con estado distinto de cero.

### Limitación heredada del reader

Actualmente `read-json-file` captura tanto:

- errores de lectura del archivo;
- errores de sintaxis JSON;

dentro del mismo mensaje:

```text
"Error de sintaxis JSON o de lectura: ..."
```

Por lo tanto KANE2-29 **no debe intentar distinguir `E2_INPUT_IO` de `E2_JSON_SYNTAX` inspeccionando el texto del mensaje**.

Una clasificación más fina requeriría modificar el contrato del reader y queda fuera de KANE2-29 salvo decisión explícita posterior del equipo.

---

### 11.3 Preferencias inválidas

Un `result-err` producido durante:

```text
read-preferences-json
```

detiene la ejecución antes de construir candidatos.

---

### 11.4 Error de escritura

Las excepciones de filesystem propagadas por:

```text
write-combinations-json
```

deben ser tratadas por `main.rkt` como error de salida.

Conceptualmente:

```text
E2_OUTPUT_IO
```

La ejecución termina con estado distinto de cero.

---

## 12. Separación de Responsabilidades

### KANE2-29 SÍ se encarga de:

- recibir los argumentos de línea de comandos;
- invocar el reader del catálogo;
- desempaquetar `result-ok`;
- detener el flujo ante `result-err`;
- invocar el reader de preferencias;
- construir candidatos;
- iniciar el generador lazy;
- filtrar correquisitos;
- filtrar créditos;
- ejecutar el writer;
- informar errores de frontera;
- producir el archivo final.

### KANE2-29 NO se encarga de:

- parsear manualmente JSON;
- validar nuevamente el catálogo;
- validar nuevamente las preferencias;
- calcular elegibilidad;
- calcular choques;
- comparar horarios;
- construir manualmente candidatos;
- generar manualmente combinaciones;
- validar manualmente correquisitos;
- recalcular créditos;
- construir manualmente el JSON de salida;
- materializar el stream completo;
- seleccionar un horario final;
- ejecutar Prolog.

---

## 13. Pruebas de Integración

Archivo:

```text
tests/integration/main-test.rkt
```

Las pruebas deben ejecutar el pipeline completo y verificar resultados observables.

### TC-01 — Ejecución real completa

Entradas:

```text
tests/fixtures/catalog/real_computadores.json
tests/fixtures/preferences/valid.json
```

Resultado:

- ejecución exitosa;
- archivo creado;
- JSON parseable;
- `schemaVersion` válido según el writer;
- campo `combinaciones` presente.

---

### TC-02 — Todas las combinaciones respetan créditos

Para cada combinación escrita:

```text
min <= creditosTotales <= max
```

utilizando el rango definido por las preferencias reales.

---

### TC-03 — Ningún curso se repite

En cada combinación:

```text
curso
```

debe aparecer como máximo una vez.

---

### TC-04 — Cada selección contiene exactamente un grupo

Cada selección escrita posee:

```text
curso
grupo
carrera
```

y representa una única elección de grupo.

---

### TC-05 — Carrera conservada

La carrera de cada selección escrita coincide con la carrera correspondiente del catálogo procesado.

---

### TC-06 — Ninguna combinación contiene choques

A partir del catálogo cargado se verifica que ningún par:

```text
curso + grupo
```

presente en una combinación aparezca en las referencias de conflicto correspondientes.

La prueba comprueba el resultado observable del pipeline; no implica recalcular horarios.

---

### TC-07 — Correquisitos pendientes satisfechos

Utilizando los datos del catálogo, toda selección que posea correquisitos pendientes debe encontrarlos presentes dentro de la misma combinación.

---

### TC-08 — Preferencias inválidas

Entrada:

```text
tests/fixtures/preferences/invalid_*.json
```

Resultado:

- ejecución no exitosa;
- no continúa hacia la generación;
- no se produce una salida válida como si la ejecución hubiera sido exitosa.

Se puede escoger un fixture representativo para esta prueba; no es necesario duplicar todos los casos ya cubiertos por los tests unitarios del reader.

---

### TC-09 — Catálogo inválido

Con un fixture inválido de catálogo:

- el reader devuelve error;
- no se leen las preferencias;
- no comienza la generación;
- la ejecución termina como error.

---

### TC-10 — Cantidad incorrecta de argumentos

Ejecutar `main.rkt` sin exactamente tres argumentos produce:

```text
E2_ARGS
```

o el mensaje equivalente definido por el ejecutable, y termina con estado distinto de cero.

---

### TC-11 — Error de escritura

Usar como salida una ruta cuya carpeta no existe.

Resultado:

- el error de filesystem se maneja en `main.rkt`;
- la ejecución termina con estado distinto de cero.

---

### TC-12 — Todas las pruebas anteriores siguen pasando

Ejecutar:

```text
raco test tests
```

debe conservar verdes todos los tests unitarios e integración existentes.

---

## 14. Datos Reales

La integración principal utilizará como mínimo:

```text
tests/fixtures/catalog/real_computadores.json
tests/fixtures/preferences/valid.json
```

El catálogo real proviene del formato generado por C.

No se modifica manualmente para KANE2-29.

Antes de incorporar otros catálogos reales a pruebas de integración debe comprobarse que exista un archivo de preferencias compatible con ellos.

---

## 15. Resultado Esperado

Archivos nuevos:

```text
src/main.rkt
tests/integration/main-test.rkt
docs/contracts/ContratoKANE2-29IntegracionEtapa2.md
```

Cambio de limpieza ya realizado en esta rama:

```text
eliminar src/domain/functional/stream-utils.rkt
```

El módulo canónico permanece:

```text
src/functional/stream-utils.rkt
```

No se espera modificar lógica de:

```text
src/io/catalog.rkt
src/io/preferences-reader.rkt
src/io/combination-writer.rkt
src/domain/candidates.rkt
src/domain/conflicts.rkt
src/domain/corequisites.rkt
src/domain/credits.rkt
src/generation/combinations.rkt
src/functional/stream-utils.rkt
src/models/*
```

Si durante KANE2-29 fuese necesario modificar alguno de estos módulos para que el pipeline funcione, primero debe determinarse si se trata de un defecto de integración real o de una nueva responsabilidad no contemplada por esta historia.
