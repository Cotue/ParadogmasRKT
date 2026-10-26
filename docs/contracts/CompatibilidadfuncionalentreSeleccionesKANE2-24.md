
# Contrato KANE2-24: Compatibilidad Funcional entre Selecciones

## 1. Propósito

Determinar si una nueva `selection` puede agregarse a una combinación parcial sin introducir choques con las selecciones que ya contiene.

La función utiliza exclusivamente las referencias de conflicto calculadas previamente por C y conservadas dentro de cada `selection`.

Flujo conceptual:

```text
selection candidata
        +
lista de selections existentes
        ↓
selection-compatible?
        ↓
   #t / #f
```

Esta historia no genera combinaciones. Únicamente proporciona el predicado que el generador podrá utilizar posteriormente para podar ramas incompatibles.

---

## 2. Operación Pública e Implementación del Módulo

Firma conceptual:

```text
selection-compatible? :
selection?
× (listof selection?)
→ boolean?
```

Módulo:

```text
src/domain/conflicts.rkt
```

Interfaz pública esperada:

```racket
(provide
 (contract-out
  [selection-compatible?
   (-> selection?
       (listof selection?)
       boolean?)]))
```

Dependencias:

```text
src/models/combination.rkt
src/models/catalog.rkt
```

`combination.rkt` proporciona `selection` y sus accessors.

`catalog.rkt` proporciona `group-key` y sus accessors, necesarios para interpretar las identidades almacenadas en `selection-conflicts`.

La función no recibe `Catalog` porque toda la información necesaria para comprobar compatibilidad ya está embebida en las selecciones.

---

## 3. Modelo de Conflictos Utilizado

Cada `selection` contiene:

```text
course-code
group-number
career
credits
pending-corequisites
conflicts
```

El campo:

```text
conflicts
```

es una lista de:

```racket
(group-key course-code group-number)
```

Cada `group-key` identifica un grupo incompatible mediante el par:

```text
(código de curso, número de grupo)
```

El número de grupo por sí solo no constituye una identidad suficiente.

Ejemplo:

```text
CE1101-G1
MA1403-G1
```

son grupos diferentes aunque ambos tengan número `1`.

---

## 4. Regla de Compatibilidad

Una nueva selección `candidate` es compatible con una lista de selecciones existentes cuando no existe ningún conflicto entre ella y cualquiera de esas selecciones.

Conceptualmente:

```text
candidate
   │
   ├── comparar con selection 1
   ├── comparar con selection 2
   ├── comparar con selection 3
   └── ...
```

Si ninguna comparación encuentra un choque:

```text
#t
```

Si al menos una encuentra un choque:

```text
#f
```

---

## 5. Identificación de un Choque

Sea:

```text
candidate = A-G1
existing  = B-G2
```

existe un choque cuando la identidad:

```text
(B, 2)
```

aparece dentro de:

```text
candidate.conflicts
```

La implementación puede además comprobar defensivamente el sentido inverso:

```text
(A, 1)
```

dentro de:

```text
existing.conflicts
```

La razón es que el contrato de entrada espera que las relaciones producidas por C sean simétricas.

La comprobación defensiva no recalcula el choque: continúa utilizando exclusivamente las referencias de conflicto producidas por C.

Por tanto, dos selecciones se consideran incompatibles si cualquiera de las dos declara explícitamente a la otra dentro de sus conflictos.

---

## 6. Combinación Parcial Vacía

Toda selección es compatible con una lista vacía de selecciones:

```racket
(selection-compatible? candidate '())
→ #t
```

No existe ninguna selección previa contra la cual pueda existir un conflicto.

---

## 7. Varios Grupos Existentes

La selección candidata debe ser compatible con **todas** las selecciones existentes.

Ejemplo:

```text
candidate = A-G1

partial =
[
  B-G1
  C-G2
  D-G3
]
```

Si:

```text
A-G1 no choca con B-G1
A-G1 no choca con C-G2
A-G1 choca con D-G3
```

el resultado completo es:

```text
#f
```

Un solo choque basta para rechazar la selección.

---

## 8. Información que NO se utiliza

La compatibilidad no depende de:

```text
career
credits
pending-corequisites
```

Estos campos pertenecen a otras reglas del sistema.

La función tampoco utiliza:

```text
día
hora de inicio
hora de fin
```

ni cualquier otra representación de horarios.

Los choques ya fueron calculados por C.

---

## 9. Invariantes y Restricciones

- Función pura.
- Sin I/O.
- No lee JSON.
- No consulta archivos.
- No recibe `Catalog`.
- No modifica la selección candidata.
- No modifica la lista de selecciones existentes.
- No utiliza mutación.
- No crea estructuras nuevas.
- No recalcula conflictos.
- No compara horarios.
- Utiliza únicamente `selection-conflicts`.
- Utiliza `(course-code, group-number)` como identidad de grupo.
- No valida correquisitos.
- No calcula créditos.
- No genera combinaciones.
- `#lang racket` con contrato público explícito.

---

## 10. Casos de Prueba Mínimos

Archivo:

```text
tests/unit/conflicts-test.rkt
```

### TC-01 — Combinación parcial vacía

Una selección candidata comparada con:

```racket
'()
```

devuelve:

```text
#t
```

---

### TC-02 — Sin choque

La selección candidata no referencia a ninguna selección existente y ninguna selección existente referencia a la candidata.

Resultado:

```text
#t
```

---

### TC-03 — Choque directo

La selección candidata contiene dentro de `conflicts` la identidad de una selección existente.

Resultado:

```text
#f
```

---

### TC-04 — Choque declarado en sentido inverso

Una selección existente contiene dentro de sus `conflicts` la identidad de la candidata.

Resultado:

```text
#f
```

Este caso comprueba la validación defensiva en ambos sentidos sin recalcular horarios.

---

### TC-05 — Varias selecciones sin choque

La combinación parcial contiene varias selecciones y ninguna entra en conflicto con la candidata.

Resultado:

```text
#t
```

---

### TC-06 — Varias selecciones con un choque

La candidata es compatible con algunas selecciones, pero entra en conflicto con al menos una.

Resultado:

```text
#f
```

---

### TC-07 — Mismo número de grupo, distinto curso

Ejemplo:

```text
candidate = A-G1
existing  = B-G1
```

Si no existe referencia explícita de conflicto entre ellos:

```text
#t
```

Esto comprueba que el número de grupo por sí solo no determina incompatibilidad.

---

### TC-08 — Mismo curso, distinto grupo sin conflicto explícito

La función únicamente evalúa conflictos embebidos.

Si recibe:

```text
A-G1
A-G2
```

sin referencias de conflicto entre ellas, esta función devuelve:

```text
#t
```

La regla de "un único grupo por curso" pertenece al generador y no debe incorporarse dentro de KANE2-24.

---

### TC-09 — Conservación de la selección candidata

Después de ejecutar `selection-compatible?`, la selección candidata permanece estructuralmente igual.

---

### TC-10 — Conservación de la lista parcial

Después de ejecutar `selection-compatible?`, las selecciones existentes permanecen estructuralmente iguales.

---

## 11. Manejo de Errores

`selection-compatible?` no utiliza `Result`.

Su resultado representa únicamente una condición lógica:

```text
compatible   → #t
incompatible → #f
```

Los argumentos inválidos se consideran errores de programación y son detectados mediante el contrato público.

Una lista parcial vacía es válida y produce `#t`.

---

## 12. Separación de Responsabilidades

### KANE2-24 SÍ se encarga de:

- determinar compatibilidad entre una selección candidata y una combinación parcial;
- utilizar las referencias de conflictos embebidas;
- identificar grupos mediante `(course-code, group-number)`;
- rechazar una selección si existe al menos un choque;
- funcionar como predicado puro reutilizable por el generador.

### KANE2-24 NO se encarga de:

- leer catálogo;
- leer preferencias;
- construir candidatos;
- crear `selection`;
- generar combinaciones;
- verificar que un curso aparezca solo una vez;
- validar correquisitos;
- sumar o filtrar créditos;
- comparar horarios;
- recalcular conflictos;
- modificar datos.

---

## 13. Posición en el Flujo

La función será utilizada posteriormente durante la generación:

```text
combinación parcial
        +
nueva selección
        ↓
selection-compatible?
        │
   ┌────┴────┐
   │         │
  #f        #t
   │         │
descartar   continuar
 rama       generación
```

La poda debe ocurrir antes de continuar construyendo una rama incompatible.

La integración de este predicado dentro del generador pertenece a la historia correspondiente de generación de combinaciones.

---

## 14. Resultado Esperado

Archivos nuevos:

```text
src/domain/conflicts.rkt
tests/unit/conflicts-test.rkt
docs/contracts/ContratoKANE2-24CompatibilidadConflictos.md
```

No requiere modificar:

```text
src/models/catalog.rkt
src/models/combination.rkt
src/models/preferences.rkt
src/domain/candidates.rkt
src/domain/corequisites.rkt
```
