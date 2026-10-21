v1.0

# Contrato KANE 21: Lector y Contrato de Preferencias

## 1. Propósito
Leer el archivo de preferencias del estudiante (rango de créditos y cursos con los grupos que está dispuesto a explorar), validarlo contra el catálogo ya cargado y transformarlo en structs inmutables. El resultado limita el espacio de búsqueda del generador de combinaciones.

## 2. Operación Pública e Implementación del Módulo

- Firma: `read-preferences-json : path-string? catalog? -> result?`
- Módulo público: `src/io/preferences-reader.rkt`, con `provide/contract`.
- Devuelve `(result-ok preferences)` o `(result-err mensaje)`. No lanza excepciones al código que lo llama.
- Depende de KANE 20: recibe el `catalog` que produce `read-catalog-json` y reutiliza `Result`, `bind` y `read-json-file`.

Flujo interno (cada paso se encadena con `bind`; el primer error corta el resto):

```
archivo .json
   │  read-json-file                    (sintaxis JSON y lectura)
   ▼
validate-pref-schema-version            (schemaVersion = "2.0")
   ▼
validate-pref-credits                   (min y max enteros >= 0, min <= max)
   ▼
validate-pref-courses-exist             (cursosInteres: lista no vacía)
   ▼
validate-pref-course-structure          (curso string; grupos lista no vacía de enteros)
   ▼
validate-pref-unique-courses            (sin cursos repetidos)
   ▼
validate-pref-unique-groups             (sin grupos repetidos en una entrada)
   ▼
validate-pref-courses-in-catalog        (cada curso existe en el catálogo)
   ▼
validate-pref-groups-in-catalog         (cada grupo existe en su curso)
   ▼
json->preferences                       (JSON → structs)
   ▼
(result-ok preferences)
```

## 3. Reglas de Negocio / Especificación

### Formato del archivo
```json
{
  "schemaVersion": "2.0",
  "creditos": { "min": 8, "max": 16 },
  "cursosInteres": [
    { "curso": "CE1101", "grupos": [1, 2, 3] },
    { "curso": "CE1104", "grupos": [2, 3] }
  ]
}
```

### Semántica
Cada entrada de `cursosInteres` significa: si ese curso aparece en una combinación, solo puede usar uno de los grupos listados. No significa que todos los cursos deban aparecer en todas las combinaciones.

### Reglas de validación

| # | Validador | Regla |
|---|---|---|
| 1 | `validate-pref-schema-version` | La raíz es un objeto y `schemaVersion` es exactamente `"2.0"`. |
| 2 | `validate-pref-credits` | `creditos` es un objeto con `min` y `max` enteros no negativos, y `min <= max`. |
| 3 | `validate-pref-courses-exist` | `cursosInteres` es una lista no vacía. |
| 4 | `validate-pref-course-structure` | Cada entrada es un objeto con `curso` (string) y `grupos` (lista no vacía de enteros). |
| 5 | `validate-pref-unique-courses` | Un código de curso no se repite. |
| 6 | `validate-pref-unique-groups` | Un número de grupo no se repite dentro de la misma entrada. |
| 7 | `validate-pref-courses-in-catalog` | Cada curso existe en el catálogo. |
| 8 | `validate-pref-groups-in-catalog` | Cada grupo existe dentro del curso correspondiente. |

### Decisiones de diseño
- **Schema `"2.0"`:** el equipo acordó usar la misma versión que el catálogo. El contrato maestro (sección 7) decía `"1.0"` para las preferencias y debe actualizarse.
- **`puedeMatricular` no se valida aquí:** un curso no matriculable puede aparecer en las preferencias. Lo descarta `candidates.rkt` al construir candidatos. Así se separan la validación de la entrada y la elegibilidad académica, que calculó C.
- **Nombre `read-preferences-json`:** es el del contrato maestro, que fija la nomenclatura base para las historias siguientes. La historia KANE 21 lo nombra `read-preferences`.
- **Retorno `Result`:** igual que KANE 20, el rechazo es un valor y no una excepción.

## 4. Invariantes y Restricciones
- `#lang racket`, sin Typed Racket.
- Sin mutación: nada de `set!`, `set-box!` ni structs mutables.
- `provide/contract` en la interfaz pública.
- No modifica el catálogo: los structs son inmutables y el test lo comprueba recargando el catálogo y comparándolo.
- Se conserva el orden de cursos y de grupos tal como aparecen en el archivo.
- Los validadores son puros; la única operación de I/O es la lectura del archivo.

Estructuras (`src/models/preferences.rkt`, ambas `#:transparent`):

| Struct | Campos |
|---|---|
| `course-preference` | `course-code allowed-groups` (lista de enteros) |
| `preferences` | `min-credits max-credits courses` (lista de `course-preference`) |

## 5. Casos de Prueba Mínimos

Archivo: `tests/unit/test_preferences_reader.rkt`. Fixtures en `tests/fixtures/preferences/`. Se prueban contra `tests/fixtures/catalog/real_computadores.json`, cargado una sola vez.

| ID | Archivo | Criterio | Resultado |
|---|---|---|---|
| TC-01 | `valid.json` | Créditos 8-16, tres cursos, varios grupos por curso; `allowed-groups` de `CE1101` igual a `'(1 2 3)` | `result-ok` |
| TC-02 | `valid_not_enrollable.json` | Incluye `MA1102`, con `puedeMatricular = false` | `result-ok` |
| TC-03 | `invalid_malformed.json` | JSON cortado | `result-err` |
| TC-04 | `invalid_schema_version.json` | `schemaVersion` `"1.0"` | `result-err` |
| TC-05 | `invalid_credits_order.json` | `min` mayor que `max` | `result-err` |
| TC-06 | `invalid_negative_credits.json` | `min` negativo | `result-err` |
| TC-07 | `invalid_empty_courses.json` | `cursosInteres` vacío | `result-err` |
| TC-08 | `invalid_empty_groups.json` | Una entrada con `grupos` vacío | `result-err` |
| TC-09 | `invalid_duplicate_course.json` | `CE1101` dos veces | `result-err` |
| TC-10 | `invalid_duplicate_group.json` | `CE1101` con `[1, 1]` | `result-err` |
| TC-11 | `invalid_unknown_course.json` | Curso `XX9999` | `result-err` |
| TC-12 | `invalid_unknown_group.json` | `CE1101` con el grupo 99 | `result-err` |
| TC-13 | `valid.json` | El catálogo es igual antes y después de leer preferencias | `check-equal?` |
| TC-14 | archivo inexistente | Ruta que no existe | `result-err`, sin excepción |

En todos los casos `result-err` el mensaje es un string no vacío y cada fixture inválido falla solo por el motivo que indica su nombre.

Verificación:
```
raco make src/io/preferences-reader.rkt tests/unit/test_preferences_reader.rkt
raco test tests/unit/test_preferences_reader.rkt
```
Resultado esperado: 14 tests passed.

## 6. Manejo de Errores y Códigos de Estado

| Situación | Resultado |
|---|---|
| Preferencias válidas | `(result-ok preferences)` |
| Archivo inexistente o JSON mal formado | `(result-err "Error de sintaxis JSON o de lectura: …")` |
| Falla cualquier validador | `(result-err mensaje)` con el curso o el dato problemático |

`main.rkt` traducirá cualquier `result-err` de este módulo al código de error `E2_PREFERENCES` del contrato maestro, con un mensaje comprensible para el usuario.

## 7. Separación de Responsabilidades

### KANE 21 SÍ se encarga de:
- Leer y parsear el archivo de preferencias.
- Validar su estructura y su coherencia con el catálogo (cursos y grupos existentes).
- Transformarlo en `preferences` con structs inmutables.

### KANE 21 NO se encarga de:
- Aplicar `puedeMatricular`, correquisitos ni choques (módulos posteriores y datos de C).
- Construir candidatos, generar combinaciones o filtrar por créditos de una combinación.
- Modificar el catálogo.

## 8. Resultado esperado (archivos generados)
- `src/models/preferences.rkt`
- `src/domain/preferences-validators.rkt`
- `src/io/preferences-reader.rkt`
- `src/io/json_reader.rkt` (modificado: ahora exporta `read-json-file`)
- `tests/unit/test_preferences_reader.rkt`
- `tests/fixtures/preferences/` con 2 JSON válidos y 10 inválidos
- `docs/contracts/ContratoKANE21LectorPreferencias.md`
