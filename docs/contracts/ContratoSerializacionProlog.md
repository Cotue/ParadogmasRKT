v1.0

# Contrato KANE2-28: Serialización Lazy hacia Prolog

## 1. Propósito
Escribir en un archivo JSON todas las combinaciones válidas que produce la Etapa 2, en un formato estable que la etapa de Prolog pueda leer sin conocer la implementación de Racket. El stream de combinaciones se consume progresivamente: nunca se convierte a lista completa.

## 2. Operación Pública e Implementación del Módulo

- Módulo: `src/io/combination-writer.rkt`, con `provide/contract`.
- Firmas:
  - `write-combinations-json : path-string? (stream-of/c combination?) -> void?`
  - `write-combinations-to-port : output-port? (stream-of/c combination?) -> void?`
- `write-combinations-json` abre el archivo (sobrescribe si existe) y delega en `write-combinations-to-port`, que escribe en cualquier puerto. La segunda función se exporta para poder probar la pereza con un puerto de cadena.
- Dependencias: librería `json`, `models/combination.rkt` y `functional/stream-utils.rkt` (para `stream-of/c`). No depende de los lectores ni del dominio.
- Se usa `stream-of/c` y no `stream/c` de `racket/stream`, porque este último falla con `impersonate-vector` en este proyecto. `stream-of/c` es perezoso: verifica cada elemento solo al consumirlo.

Flujo de escritura (recursión de cola sobre el stream):

```
{"schemaVersion":"2.0","combinaciones":[        ← sobre (se escribe a mano)
   salto de línea                                ← antes de la primera combinación
   combinación 1  (write-json)
   ,salto de línea  combinación 2  (write-json)  ← separador antes de cada una, salvo la primera
   ...
]}                                               ← cierre cuando el stream se agota
```
El separador se escribe antes de cada combinación, no después, así no hace falta mirar el siguiente elemento ni queda coma final.

## 3. Reglas de Negocio / Especificación

### Formato de salida (schema `"2.0"`)
```json
{
  "schemaVersion": "2.0",
  "combinaciones": [
    {
      "selecciones": [
        { "curso": "CE1101", "grupo": 1, "carrera": "Computadores" },
        { "curso": "CE1104", "grupo": 2, "carrera": "Computadores" }
      ],
      "creditosTotales": 6
    }
  ]
}
```

| Campo | Origen |
|---|---|
| `schemaVersion` | Constante del módulo, `"2.0"` por decisión del equipo |
| `curso` | `selection-course-code` |
| `grupo` | `selection-group-number` |
| `carrera` | `selection-career` (carrera de origen de cada curso) |
| `creditosTotales` | `combination-total-credits`, tal como viene (el writer no lo recalcula) |

Cada selección se escribe con exactamente tres claves y cada combinación con exactamente dos. No se exportan los correquisitos pendientes ni los conflictos, porque Prolog no los necesita.

### Decisiones de diseño
- **JSON como formato:** cumple la exigencia de formato justificable de la Etapa 2, lo lee cualquier parser estándar y permite que Prolog procese las combinaciones sin conocer Racket. El esquema lleva versión para poder evolucionar.
- **Escritura por piezas:** solo el sobre se escribe a mano; cada combinación se serializa con `write-json`, que escapa correctamente los textos. Nunca se construye un `jsexpr` con todas las combinaciones, lo que permite escribir salidas muy grandes con memoria casi constante.
- **Una combinación por línea:** facilita revisar el archivo y procesarlo por líneas si hiciera falta.
- **Orden:** se conserva el de entrada, que ya es determinista (misma entrada, mismo archivo).
- **Stream vacío:** es una ejecución válida. Produce un JSON válido con `"combinaciones"` vacío.
- **Errores de archivo:** el writer no los captura. Si la ruta es inválida o no hay permisos, la excepción `exn:fail:filesystem` se propaga. La traducción al código `E2_OUTPUT_IO` corresponde a `main.rkt`.
- **Sobrescritura:** si el archivo existe, se trunca. No se crean carpetas que falten.

### Caso límite conocido
Si el generador falla a la mitad (por ejemplo, un error al forzar un elemento del stream), el archivo queda con el contenido escrito hasta ese punto y sin cerrar el sobre, por lo que no es JSON válido. Es consecuencia directa de escribir de forma progresiva. El fallo se propaga a quien llama, que debe tratar el archivo como incompleto.

## 4. Invariantes y Restricciones
- Prohibido `stream->list`, `stream-length`, `stream-count` o cualquier función que materialice el stream completo.
- Sin mutación: la iteración usa recursión de cola con un parámetro booleano (`is-first?`), sin `set!` ni contadores mutables.
- `#lang racket` con `provide/contract`, sin Typed Racket.
- No recalcula choques, créditos, correquisitos ni elegibilidad; escribe lo que recibe.
- No define structs nuevos.

## 5. Casos de Prueba Mínimos

Archivo: `tests/unit/combination-writer-test.rkt`. Se parsea la salida con el parser estándar de `json` y se compara la estructura, no el texto.

| ID | Caso | Resultado |
|---|---|---|
| TC-01 | Dos combinaciones: `schemaVersion` `"2.0"`, 2 combinaciones, con 2 y 1 selecciones en ese orden | JSON válido y contenido exacto |
| TC-02 | Cada selección tiene exactamente `curso`, `grupo` y `carrera` con los valores correctos | 3 claves |
| TC-03 | `creditosTotales` coincide y cada combinación tiene exactamente 2 claves | `7` y 2 claves |
| TC-04 | Una sola combinación (borde de las comas) | 1 elemento |
| TC-05 | Stream vacío | `schemaVersion` presente y `combinaciones` vacío |
| TC-06 | 300 combinaciones generadas de forma perezosa | 300 elementos |
| TC-07 | Pereza: el tercer elemento del stream lanza un error | el error se propaga y el puerto ya contiene las dos primeras combinaciones |
| TC-08 | Escritura a disco y lectura posterior | `schemaVersion` y 1 combinación |
| TC-09 | Sobrescribir un archivo existente | queda solo el contenido de la segunda escritura |
| TC-10 | Ruta en una carpeta inexistente | `exn:fail:filesystem` |
| TC-11 | Integración con datos reales: catálogo `real_computadores.json` y preferencias `valid.json` → candidatos → generador → filtro de correquisitos → escritura | al menos una combinación; cursos y grupos dentro de lo permitido; toda combinación con `CE1104` contiene `CE1101`; carrera `"Computadores"` |

Verificación:
```
raco make src/io/combination-writer.rkt tests/unit/combination-writer-test.rkt
raco test tests/unit/combination-writer-test.rkt
```
Resultado esperado: 11 tests passed.

## 6. Manejo de Errores y Códigos de Estado

| Situación | Comportamiento |
|---|---|
| Stream vacío | Archivo válido con `"combinaciones": []` |
| Ruta inválida, carpeta inexistente o sin permisos | Se propaga `exn:fail:filesystem`; `main.rkt` la traducirá a `E2_OUTPUT_IO` |
| Falla al forzar un elemento del stream | Se propaga el error; el archivo queda incompleto |
| Argumento que no es un stream de combinaciones | Violación de contrato de `provide/contract` (error de programación) |

## 7. Separación de Responsabilidades

### KANE2-28 SÍ se encarga de:
- Serializar el stream de combinaciones a JSON de forma progresiva.
- Garantizar un formato estable y versionado hacia Prolog.
- Propagar los errores de escritura.

### KANE2-28 NO se encarga de:
- Generar, filtrar ni ordenar combinaciones.
- Filtrar por créditos o correquisitos (se aplican antes, con `stream-select`).
- Leer catálogo o preferencias.
- Traducir errores a códigos de salida (`main.rkt`).

## 8. Resultado esperado (archivos generados)
- `src/io/combination-writer.rkt`
- `tests/unit/combination-writer-test.rkt`
- `docs/contracts/ContratoSerializacionProlog.md`
