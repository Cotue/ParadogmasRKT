
# Contrato KANE2-23: Construcción Funcional de Cursos Candidatos
### Decisión sobre cursos y grupos inexistentes

`build-candidates` opera sobre modelos de dominio que ya fueron validados por
los readers de catálogo y preferencias.

Por esta razón, durante el flujo normal se asume que:

- cada curso presente en `Preferences` existe en `Catalog`;
- cada número de grupo presente en `allowed-groups` existe dentro del curso
  correspondiente.

`build-candidates` no repite estas validaciones.

Los helpers internos pueden realizar búsquedas defensivas, pero la función no
utiliza `Result` ni convierte inconsistencias de entrada en una nueva regla de
negocio. La validación de estas referencias pertenece al lector de
preferencias.

Esta separación evita duplicar responsabilidades entre módulos.q

## 1. Propósito

Convertir un `catalog` y unas `preferences` ya válidas en una lista de `candidate-course` que contenga únicamente las opciones que pueden participar en la generación posterior de combinaciones.

Esta historia constituye la frontera entre los datos de entrada ya validados y el espacio efectivo de búsqueda.

Flujo:

```text
catalog + preferences
        ↓
 build-candidates
        ↓
(listof candidate-course?)
```

La función no genera combinaciones, no valida correquisitos y no recalcula información académica proveniente de C.

---

## 2. Operación Pública e Implementación del Módulo

- Firma conceptual:

```text
build-candidates :
catalog? × preferences?
→ (listof candidate-course?)
```

- Módulo:

```text
src/domain/candidates.rkt
```

- Interfaz pública mediante `contract-out`.

Contrato esperado:

```racket
[build-candidates
 (-> catalog?
     preferences?
     (listof candidate-course?))]
```

- Depende únicamente de los modelos canónicos necesarios:

```text
src/models/catalog.rkt
src/models/preferences.rkt
```

No utiliza `Result`, porque recibe valores de dominio que ya fueron construidos y validados por los readers.

---

## 3. Reglas de Negocio / Especificación

### 3.1 Cursos de interés

Solo se consideran los cursos presentes en:

```text
preferences-courses
```

Un curso del catálogo que no aparezca en las preferencias no debe producir un `candidate-course`.

---

### 3.2 Elegibilidad

Para cada curso de interés:

```text
course-can-enroll? = #t
```

permite construir un candidato.

Si:

```text
course-can-enroll? = #f
```

el curso se excluye completamente de la lista de candidatos.

La función no intenta determinar por qué el curso no puede matricularse.

La elegibilidad ya fue calculada por C.

---

### 3.3 Grupos permitidos

Para cada curso candidato solo se conservan los grupos cuyo número aparece en:

```text
course-preference-allowed-groups
```

Si la preferencia contiene:

```text
CE1101 → [3, 1]
```

el candidato debe conservar esos grupos en ese mismo orden:

```text
grupo 3
grupo 1
```

aunque el catálogo almacene originalmente los grupos en otro orden.

Los grupos conservados son los objetos `group-option` originales del catálogo y mantienen sus referencias de conflictos.

---

### 3.4 Información conservada

Cada `candidate-course` conserva del `course` original:

```text
code
career
credits
pending-corequisites
```

y una lista de:

```text
group-option
```

restringida por las preferencias.

Los conflictos contenidos dentro de cada `group-option` se conservan sin modificaciones.

---

### 3.5 `can-enroll?` no se copia

`candidate-course` no posee un campo `can-enroll?`.

Esto es intencional.

La existencia de un valor dentro del resultado de `build-candidates` implica:

```text
can-enroll? = #t
```

en el curso original.

---

### 3.6 Orden determinista

La lista final de candidatos conserva:

1. el orden de cursos indicado por `preferences-courses`;
2. dentro de cada candidato, el orden de grupos indicado por `allowed-groups`.

No se utiliza el orden del catálogo para determinar el orden final cuando las preferencias expresan uno distinto.

---

## 4. Precondiciones de Dominio

`build-candidates` recibe estructuras de dominio ya producidas por los readers.

Por tanto, asume que:

- cada curso indicado en preferencias existe en el catálogo;
- cada grupo permitido existe dentro del curso correspondiente;
- las preferencias no contienen cursos duplicados;
- los grupos permitidos de una preferencia no están duplicados;
- `allowed-groups` no está vacío.

Estas condiciones pertenecen al lector de preferencias y no deben volver a validarse dentro de `build-candidates`.

La función no devuelve `Result`.

Una violación de estas precondiciones representa uso incorrecto de la función o un valor de dominio construido fuera del flujo normal.

---

## 5. Invariantes y Restricciones

- Función pura.
- Sin I/O.
- No lee JSON.
- No importa módulos de `src/io/`.
- No modifica `catalog`.
- No modifica `preferences`.
- No modifica los cursos ni grupos originales.
- No utiliza mutación.
- No crea structs nuevos.
- Utiliza únicamente los modelos canónicos.
- No recalcula requisitos académicos.
- No recalcula `can-enroll?`.
- No compara horarios.
- No recalcula conflictos.
- No valida correquisitos pendientes.
- No genera combinaciones.
- `#lang racket` con contratos explícitos.

---

## 6. Comportamiento esperado

Ejemplo conceptual:

### Catálogo

```text
A
  can-enroll? = #t
  credits = 4
  groups = [G1, G2, G3]

B
  can-enroll? = #f
  credits = 3
  groups = [G1]

C
  can-enroll? = #t
  credits = 2
  groups = [G1]
```

### Preferencias

```text
B → [1]
A → [3, 1]
```

### Resultado

```text
[
  candidate-course A
    credits = 4
    groups = [G3, G1]
]
```

`B` desaparece por no ser matriculable.

`C` desaparece porque no es un curso de interés.

`A-G2` desaparece porque no fue permitido por las preferencias.

---

## 7. Casos de Prueba Mínimos

Archivo propuesto:

```text
tests/unit/candidates-test.rkt
```

### TC-01 — Curso elegible de interés

Un curso presente en preferencias con `can-enroll? = #t` produce un candidato.

Debe conservar:

```text
code
career
credits
pending-corequisites
```

---

### TC-02 — Curso no matriculable

Un curso de interés con:

```text
can-enroll? = #f
```

no aparece en el resultado.

---

### TC-03 — Curso fuera de preferencias

Un curso existente en el catálogo pero ausente de `preferences-courses` no aparece en candidatos.

---

### TC-04 — Filtrado de grupos

Un curso con grupos:

```text
[1, 2, 3]
```

y preferencia:

```text
[1, 3]
```

produce un candidato únicamente con:

```text
[1, 3]
```

---

### TC-05 — Orden de grupos según preferencias

Catálogo:

```text
[1, 2, 3]
```

Preferencia:

```text
[3, 1]
```

Resultado:

```text
[3, 1]
```

---

### TC-06 — Orden de cursos según preferencias

Si el catálogo contiene:

```text
[A, B, C]
```

pero las preferencias indican:

```text
[C, A]
```

el resultado debe conservar:

```text
[C, A]
```

si ambos son elegibles.

---

### TC-07 — Conservación de conflictos

Un `group-option` con referencias de conflicto debe aparecer en el candidato con esas mismas referencias.

`build-candidates` no elimina ni recalcula conflictos.

---

### TC-08 — Conservación de correquisitos pendientes

Un curso con:

```text
pending-corequisites = [B, C]
```

produce un candidato con exactamente:

```text
[B, C]
```

---

### TC-09 — Varios cursos, uno no elegible

Con varios cursos de interés, el curso no matriculable se elimina sin afectar el orden relativo de los candidatos restantes.

---

### TC-10 — Preferencias sin candidatos elegibles

Si todos los cursos de interés tienen:

```text
can-enroll? = #f
```

el resultado es:

```racket
'()
```

Esto no constituye un error.

---

### TC-11 — No modifica el catálogo

Después de ejecutar `build-candidates`, el `catalog` debe continuar siendo igual a una copia estructural equivalente construida antes de la llamada.

---

### TC-12 — No modifica las preferencias

Después de ejecutar `build-candidates`, las `preferences` deben continuar siendo iguales a una copia estructural equivalente construida antes de la llamada.

---

## 8. Manejo de Errores

`build-candidates` no utiliza `Result`.

La función recibe modelos de dominio válidos y produce una lista de candidatos.

Resultado válido sin candidatos:

```racket
'()
```

No encontrar candidatos elegibles no es un error.

Los contratos públicos detectan usos incorrectos de la interfaz, por ejemplo recibir un valor que no sea `catalog?` o `preferences?`.

---

## 9. Separación de Responsabilidades

### KANE2-23 SÍ se encarga de:

- cruzar catálogo y preferencias;
- considerar únicamente cursos de interés;
- aplicar `course-can-enroll?`;
- restringir grupos según `allowed-groups`;
- preservar el orden de preferencias;
- construir `candidate-course`;
- conservar carrera;
- conservar créditos;
- conservar correquisitos pendientes;
- conservar referencias de conflicto.

### KANE2-23 NO se encarga de:

- leer archivos;
- parsear JSON;
- validar la estructura del catálogo;
- validar la estructura de preferencias;
- recalcular requisitos;
- recalcular elegibilidad;
- recalcular choques;
- comparar horarios;
- validar correquisitos de una combinación;
- filtrar por rango total de créditos;
- generar combinaciones;
- utilizar streams.

---

## 10. Resultado esperado

Archivos nuevos:

```text
src/domain/candidates.rkt
tests/unit/candidates-test.rkt
docs/contracts/ContratoConstruccionCandidatos.md
```

No requiere modificar:

```text
src/models/catalog.rkt
src/models/preferences.rkt
src/models/combination.rkt
```
