v1.3

# Contrato KANE 20: Lector y Validador del JSON de C

## 1. Propósito
Leer el JSON que produce la Etapa 1 (C), validar su estructura e integridad y transformarlo en structs inmutables del dominio en Racket. No recalcula nada que C ya haya resuelto (choques, elegibilidad, formato de día y hora).

## 2. Operación Pública e Implementación del Módulo

- Firma: `read-catalog-json : path-string? -> result?`
- Módulo público: `src/io/catalog.rkt`, con `provide/contract`.
- Devuelve `(result-ok catalog)` si el archivo es válido, o `(result-err mensaje)` en cualquier otro caso. No lanza excepciones al código que lo llama.

Flujo interno (cada paso se encadena con `bind`; el primer error corta el resto):

```
archivo .json
   │  read-json-file             (sintaxis JSON y lectura)
   ▼
validate-required-fields         (schemaVersion, carrera{codigo,nombre}, cursos)
   ▼
validate-schema-version          (schemaVersion = "2.0")
   ▼
validate-course-carrera          (carrera de cada curso)
   ▼
validate-course-credits          (créditos 0-12)
   ▼
validate-group-numbers           (números de grupo)
   ▼
validate-conflict-references     (choques apuntan a grupos existentes)
   ▼
json->catalog                    (JSON → structs)
   ▼
(result-ok catalog)
```

## 3. Reglas de Validación

| # | Validador | Regla |
|---|---|---|
| 1 | `validate-required-fields` | La raíz tiene `schemaVersion`, `carrera` (con `codigo` y `nombre`) y `cursos` (lista). |
| 2 | `validate-schema-version` | `schemaVersion` es exactamente `"2.0"`. |
| 3 | `validate-course-carrera` | Cada curso tiene `carrera` como string no vacío. |
| 4 | `validate-course-credits` | `creditos` es un entero entre 0 y 12. |
| 5 | `validate-group-numbers` | Cada `numero` de grupo es un entero positivo y no se repite dentro del curso. |
| 6 | `validate-conflict-references` | Cada `choque` (`curso`, `grupo`) apunta a un grupo que existe en el catálogo. |

### Decisiones sobre las reglas
- **Créditos desde 0:** los datos reales de C incluyen cursos de 0 créditos (actividades como `SE11xx`), así que rechazar el 0 invalidaría el JSON real.
- **Requisitos no se validan:** en los datos reales, un curso de Electrónica (`CI1230`) lista requisitos que no están en el catálogo. Racket no usa `requisitos` para decidir, solo `puedeMatricular`, que C ya calculó.
- **Rango de semestre no se valida:** lo restringe C al leer los TSV (1 a 6).

### Validaciones que NO se hacen (ya las hace C)
- Formato del día (LUN, MAR, MIE, JUE, VIE, SAB), formato `HH:MM` y que el inicio sea menor que el fin.
- Elegibilidad (`puedeMatricular`) y cálculo de choques (`tieneChoque`, `choques`).
- Formato de requisitos y correquisitos del TSV.

## 4. Invariantes y Restricciones
- `#lang racket`, sin Typed Racket.
- Sin mutación: nada de `set!`, `set-box!` ni structs mutables. Estado solo por recursión e inmutabilidad.
- `provide/contract` en la interfaz pública (`catalog.rkt`).
- Errores como valor (`Result`), sin excepciones en el flujo normal.
- La carrera de cada curso se lee del campo `carrera` del curso, que C escribe igual a `carrera.codigo`. Este contrato no verifica esa igualdad.

Estructuras de dominio utilizadas:

- `src/models/catalog.rkt`
  - `group-key (course-code group-number)`
  - `group-option (number conflicts)`
  - `course (code career credits can-enroll? pending-corequisites groups)`
  - `catalog (schema-version career-code courses)`

- `src/models/result.rkt`
  - `result-ok (val)`
  - `result-err (msg)`
  - `result?`

El lector procesa el JSON completo proveniente de C y aplica las validaciones
definidas en este contrato, pero transforma al modelo de dominio únicamente
la información requerida por las etapas posteriores.

Por esta razón, campos como `nombre`, `semestre`, `requisitos`,
`correquisitos`, `horarios` y `tieneChoque` no se almacenan en `Catalog`.
La elegibilidad se conserva mediante `can-enroll?`, los correquisitos que
deben matricularse simultáneamente mediante `pending-corequisites`, y los
conflictos mediante las referencias `group-key`.


## 5. Casos de Prueba Mínimos

Archivo: `tests/unit/test_json_reader.rkt`. Fixtures en `tests/fixtures/catalog/`.

| ID | Archivo | Criterio | Resultado |
|---|---|---|---|
| TC-01 | `valid.json` | Carga completa; `schema-version` es `"2.0"` y la carrera de cada curso coincide con `career-code` | `result-ok` |
| TC-02 | `valid_empty.json` | Catálogo sin cursos | `result-ok` con `courses = '()` |
| TC-03 | `valid_zero_credits.json` | Curso de 0 créditos | `result-ok` con `credits = 0` |
| TC-04 | `invalid_malformed.json` | JSON mal formado | `result-err` |
| TC-05 | `invalid_schema_version.json` | `schemaVersion` `"1.0"` | `result-err` |
| TC-06 | `invalid_missing_fields.json` | Falta `carrera` en la raíz | `result-err` |
| TC-07 | `invalid_course_carrera.json` | Curso con `carrera` vacía | `result-err` |
| TC-08 | `invalid_credits.json` | Créditos fuera de 0-12 | `result-err` |
| TC-09 | `invalid_duplicate_groups.json` | Número de grupo repetido en un curso | `result-err` |
| TC-10 | `invalid_conflict_ref.json` | Choque a un curso o grupo inexistente | `result-err` |
| TC-11 | `real_computadores.json` | JSON real generado por C | `result-ok`, cursos > 0 |
| TC-12 | `real_electronica.json` | JSON real generado por C | `result-ok`, cursos > 0 |
| TC-13 | `real_computadores.json` y `real_electronica.json` | `course-pending-corequisites` y `course-can-enroll` coinciden con el JSON crudo en todos los cursos | `check-equal?` en cada curso |

En todos los casos `result-err` el mensaje es un string no vacío y cada fixture inválido falla solo por el motivo que indica su nombre.

Verificación:
```
raco make src/io/catalog.rkt tests/unit/test_json_reader.rkt
raco test tests/unit/test_json_reader.rkt
```
Resultado esperado: 13 tests passed.

## 6. Manejo de Errores y Códigos de Estado

El módulo no usa códigos numéricos. Los estados de C se traducen al tipo `Result`:

| Situación | Resultado |
|---|---|
| Archivo válido | `(result-ok catalog)` |
| Archivo inexistente o JSON mal formado | `(result-err "Error de sintaxis JSON o de lectura: …")` |
| Falla cualquier validador | `(result-err mensaje)` describiendo el problema y el curso afectado |

## 7. Separación de Responsabilidades

### KANE 20 SÍ se encarga de:
- Leer el archivo y parsear el JSON.
- Validar la estructura y las referencias internas de choques descritas en la sección 3.
- Transformar el JSON en structs inmutables del dominio.
- Leer `puedeMatricular` y `correquisitosPendientes` tal como vienen de C, sin recalcularlos.

### KANE 20 NO se encarga de:
- Recalcular choques ni elegibilidad (lo hace C).
- Validar día, hora, semestre, requisitos ni correquisitos (lo hace C o no los usa).
- Generar combinaciones, filtrar por créditos o exportar (KANE posteriores).

## 8. Resultado esperado (archivos generados)
- `src/models/catalog.rkt`
- `src/models/result.rkt`
- `src/domain/validators.rkt`
- `src/io/json_reader.rkt`
- `src/io/catalog.rkt`
- `tests/unit/test_json_reader.rkt`
- `tests/fixtures/catalog/` con 3 JSON válidos sintéticos, 7 inválidos y los 2 reales de C
- `docs/contracts/ContratoKANE20LectorJSON.md`
