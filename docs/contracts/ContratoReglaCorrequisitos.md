v1.0

# Contrato KANE2-25: Regla Funcional de Correquisitos Pendientes

## 1. Propósito
Validar los correquisitos pendientes que informa C, de modo que una combinación final no contenga un curso sin sus acompañamientos obligatorios. Es un predicado puro sobre una combinación ya formada. No decide qué es un correquisito: solo comprueba que los pendientes de cada selección estén presentes.

## 2. Operación Pública e Implementación del Módulo

- Firma: `corequisites-satisfied? : combination? -> boolean?`
- Módulo: `src/domain/corequisites.rkt`, con `provide/contract`.
- Devuelve `#t` si todos los correquisitos pendientes de todas las selecciones aparecen en la combinación, y `#f` en caso contrario.
- Depende únicamente de `src/models/combination.rkt` (`combination`, `selection` y sus accessors).

Algoritmo:

```
combination
   │  combination-selections
   ▼
lista de selecciones ──► códigos presentes (selection-course-code de cada una)
   │
   ▼
para cada selección S:
   para cada código en (selection-pending-corequisites S):
      ¿está en los códigos presentes?
   ▼
todos presentes  →  #t        alguno ausente  →  #f
```

Posición en el flujo de la Etapa 2: se aplica sobre el stream de combinaciones ya generadas, como filtro mediante `stream-select`, antes del filtro de créditos (ver contrato maestro, sección 5). La composición con el stream corresponde a otro KANE.

## 3. Reglas de Negocio / Especificación

Para cada selección `A` con `A.pending-corequisites = [B, C]`, la combinación es válida solo si también contiene `B` y `C`.

| Situación | Resultado |
|---|---|
| `A.pending = [B]` y la combinación es `A + B` | válida |
| `A.pending = [B]` y la combinación es solo `A` | inválida |
| `A.pending = [B, C]` y están `B` y `C` | válida |
| `A.pending = [B, C]` y solo está `B` | inválida |
| `B` está con otro número de grupo | válida (solo importa el código de curso) |
| Hay un curso `Z` sin relación | válida (no se exige que todo curso esté relacionado) |
| Ciclo: `A.pending = [B]` y `B.pending = [A]` | válida con ambos, inválida con uno solo |
| Cadena: `A.pending = [B]` y `B.pending = [C]` | `A + B` inválida; `A + B + C` válida |
| Combinación vacía | válida (verdad vacía) |

### Decisiones de diseño
- **Se revisan los pendientes de todas las selecciones**, no solo los de las primeras. Por eso una cadena exige que cada curso incluido tenga también sus propios acompañamientos.
- **Un correquisito ausente invalida la combinación sin importar la razón**: que no sea candidato, que `puedeMatricular` sea falso o que no tenga ningún grupo permitido. La función no recibe candidatos ni catálogo; la ausencia en la combinación basta.
- **Solo se evalúa sobre combinaciones completas**, nunca para podar combinaciones parciales, porque un correquisito puede incorporarse más adelante en la generación.
- **La combinación vacía devuelve `#t`.** La regla de que una combinación final nunca sea vacía es responsabilidad del generador.
- **El grupo elegido es irrelevante** para esta regla; la compatibilidad entre grupos la resuelve la poda por choques.

## 4. Invariantes y Restricciones
- Función pura: sin I/O, sin lectura de archivos y sin importar nada de `io/`.
- Sin mutación: nada de `set!`, `set-box!` ni estructuras mutables. Se usa solo `map`, `andmap` y `member`.
- No modifica la combinación ni sus selecciones.
- No consulta requisitos ni correquisitos académicos; usa únicamente `pending-corequisites`, que C ya calculó y que se conserva en cada `selection`.
- No agrega automáticamente cursos que el estudiante no incluyó en sus preferencias.
- No define structs nuevos.
- `#lang racket` con `provide/contract`, sin Typed Racket.

## 5. Casos de Prueba Mínimos

Archivo: `tests/unit/corequisites-test.rkt`. Las selecciones y combinaciones se construyen con los constructores reales de `combination.rkt`, mediante dos helpers locales.

| ID | Caso | Resultado |
|---|---|---|
| TC-01 | Combinación sin ningún pendiente | `#t` |
| TC-02 | `CE1104` con pendiente `CE1101` y `CE1101` presente | `#t` |
| TC-03 | `CE1104` con pendiente `CE1101` y `CE1101` ausente | `#f` |
| TC-04 | `CE2103` con pendientes `CE1104` y `MA1403`, ambos presentes | `#t` |
| TC-05 | `CE2103` con pendientes `CE1104` y `MA1403`, solo uno presente | `#f` |
| TC-06 | El correquisito tiene otro número de grupo | `#t` |
| TC-07 | Correquisito presente más un curso sin relación | `#t` |
| TC-08 | Ciclo `QU1106` / `QU1102`: ambos presentes y solo uno | `#t` y `#f` |
| TC-09 | Cadena `A → B → C`: sin `C` y con `C` | `#f` y `#t` |
| TC-10 | Combinación vacía | `#t` |
| TC-11 | Datos reales (`CE1104` con pendiente `CE1101`): sola y en pareja | `#f` y `#t` |
| TC-12 | La combinación evaluada no cambia (se compara con otra construida igual) | `check-equal?` |

Verificación:
```
raco make src/domain/corequisites.rkt tests/unit/corequisites-test.rkt
raco test tests/unit/corequisites-test.rkt
```
Resultado esperado: 12 tests passed.

## 6. Manejo de Errores y Códigos de Estado
- La función devuelve un booleano, no un `Result`: no hay errores de datos que reportar, solo una condición de validez.
- Si se le pasa algo que no es una `combination`, el contrato de `provide/contract` lanza una violación de contrato. Eso es un error de programación, no una condición de negocio.

## 7. Separación de Responsabilidades

### KANE2-25 SÍ se encarga de:
- Comprobar que los pendientes de cada selección estén presentes en la combinación.
- Hacerlo como función pura reutilizable como predicado de filtro.

### KANE2-25 NO se encarga de:
- Determinar qué es un correquisito ni recalcular requisitos (lo hizo C).
- Generar combinaciones, podar choques o filtrar por créditos.
- Construir candidatos ni leer catálogo o preferencias.
- Garantizar que una combinación final no sea vacía (generador).
- Aplicar el predicado sobre el stream (el KANE que use `stream-select`).

## 8. Resultado esperado (archivos generados)
- `src/domain/corequisites.rkt`
- `tests/unit/corequisites-test.rkt`
- `docs/contracts/ContratoReglaCorrequisitos.md`
