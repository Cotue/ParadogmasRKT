# Contrato de modelos e interfaces — CEmestre Etapa 2

**Historia:** KANE2-19 — Modelos base de Etapa 2  
**Rama de desarrollo:** `feature/KANE2-19Models`  
**Versión del contrato:** 1.0  
**Lenguaje:** Racket 9.3 (`#lang racket`)  
**Estrategia de modelado:** `struct` inmutables + contratos de Racket  
**Rol del documento:** Fuente de verdad para los modelos de dominio compartidos por los módulos de Etapa 2.

---

## 1. Propósito

Esta historia define e implementa la capa base de modelos de la Etapa 2 de CEmestre.

Su objetivo es que todos los módulos posteriores trabajen con las mismas representaciones de dominio, evitando que cada módulo invente estructuras propias para cursos, grupos, preferencias o combinaciones.

Los modelos definidos aquí son deliberadamente independientes de:

- archivos JSON;
- lógica de requisitos académicos;
- cálculo de choques por horario;
- generación de combinaciones;
- filtrado por créditos;
- serialización hacia Prolog.

La historia produce una capa de datos estable, inmutable y protegida por contratos públicos.

---

## 2. Alcance de la historia

Esta historia implementa:

```text
src/models/contracts.rkt
src/models/catalog.rkt
src/models/preferences.rkt
src/models/combination.rkt

tests/unit/contracts-test.rkt
tests/unit/models-test.rkt

Makefile
```

La historia **no implementa**:

```text
catalog-reader.rkt
preferences-reader.rkt
candidates.rkt
conflicts.rkt
corequisites.rkt
credits.rkt
combinations.rkt
stream-utils.rkt
combination-writer.rkt
main.rkt
```

Estos módulos consumirán posteriormente los modelos definidos en esta historia.

---

## 3. Decisiones arquitectónicas bloqueadas

Esta historia adopta las siguientes decisiones:

```text
Se utiliza #lang racket.
No se utiliza Typed Racket.
El modelado explícito se realiza con contratos.
Los structs son inmutables.
No se permite #:mutable.
No se permite set!.
Los modelos no realizan I/O.
Los modelos no contienen lógica de negocio.
Las validaciones estructurales se expresan mediante contratos.
Las validaciones semánticas entre varios campos se realizan en módulos posteriores.
Los choques se representan mediante identidades de grupo ya calculadas por C.
Una selección conserva la información necesaria para evaluar una combinación sin regresar al JSON original.
```

---

## 4. Estructura de la capa de modelos

```text
src/
└── models/
    ├── contracts.rkt
    ├── catalog.rkt
    ├── preferences.rkt
    └── combination.rkt
```

Dependencias internas:

```text
                 contracts.rkt
                 /     |      \
                /      |       \
               ▼       ▼        ▼
       catalog.rkt preferences.rkt
               │
               │
               ▼
       combination.rkt
```

Interpretación:

- `contracts.rkt` no depende de ningún otro modelo.
- `catalog.rkt` depende de los contratos primitivos.
- `preferences.rkt` depende de los contratos primitivos.
- `combination.rkt` depende de los contratos primitivos y de `catalog.rkt` para reutilizar `group-key`.
- No existen dependencias circulares.

---

## 5. Flujo de datos de la historia

Los modelos ocupan la frontera entre los módulos de entrada y la lógica funcional.

```text
        FUTURA ETAPA DE I/O

 catalogo_procesado.json
          │
          ▼
 catalog-reader.rkt
          │
          ▼
       catalog
          │
          │
          ├────────────────────┐
          │                    │
          ▼                    ▼
 preferencias.json      preferences-reader.rkt
                               │
                               ▼
                          preferences
                               │
          ┌────────────────────┘
          ▼
      candidates.rkt
          │
          ▼
 List<candidate-course>
          │
          ▼
   combinations.rkt
          │
          ▼
 Stream<combination>
          │
          ▼
     filtros / writer
```

La capa `models/` no conoce los archivos externos.

Después de que los readers conviertan JSON a structs de dominio, el resto de la aplicación deberá trabajar con estos modelos y no con hashes JSON arbitrarios.

---

# 6. `contracts.rkt`

## 6.1 Responsabilidad

Define contratos primitivos reutilizables del dominio.

No define structs.

No valida existencia de cursos o grupos.

No conoce el catálogo.

No realiza normalización de datos.

---

## 6.2 Contratos públicos

```text
course-code/c
career-code/c
group-number/c
credits/c
```

### `course-code/c`

Representa estructuralmente un código de curso.

Acepta:

```text
"CE2201"
"MA2104"
```

Rechaza:

```text
""
"   "
2201
```

Garantía:

```text
String no vacío después de ignorar espacios externos para la comprobación.
```

El contrato no garantiza que el curso exista en un catálogo concreto.

### `career-code/c`

Representa estructuralmente un código de carrera.

Acepta, por ejemplo:

```text
"IC"
"IE"
```

Garantiza únicamente:

```text
String no vacío.
```

La restricción a carreras específicas pertenece al lector del catálogo.

### `group-number/c`

Representa el número de un grupo.

Garantiza:

```text
exact-integer?
AND
positive?
```

Ejemplos:

```text
1   válido
2   válido
10  válido

0    inválido
-1   inválido
1.5  inválido
"1"  inválido
```

### `credits/c`

Representa una cantidad de créditos.

Garantiza:

```text
exact-nonnegative-integer?
```

Ejemplos:

```text
0  válido estructuralmente
4  válido

-1   inválido
3.5  inválido
"4"  inválido
```

---

# 7. `catalog.rkt`

## 7.1 Responsabilidad

Representa la información del catálogo que necesita Etapa 2.

No lee JSON.

No determina elegibilidad.

No calcula choques.

No compara horarios.

## 7.2 `group-key`

```text
group-key
├── course-code
└── group-number
```

Representa la identidad completa de un grupo.

Ejemplo conceptual:

```text
CE2201-G2
```

equivale a:

```racket
(group-key "CE2201" 2)
```

Contrato:

```text
course-code  -> course-code/c
group-number -> group-number/c
```

## 7.3 `group-option`

```text
group-option
├── number
└── conflicts
```

Representa un grupo disponible dentro del contexto de un curso.

`conflicts` contiene una lista de `group-key`.

Ejemplo:

```text
CE2201-G1
└── conflicts
    ├── MA2104-G2
    └── FI1202-G3
```

Contrato:

```text
number    -> group-number/c
conflicts -> List<group-key>
```

Los horarios no forman parte de este modelo porque los choques ya fueron calculados por C.

## 7.4 `course`

```text
course
├── code
├── career
├── credits
├── can-enroll?
├── pending-corequisites
└── groups
```

Contrato:

```text
code                 -> course-code/c
career               -> career-code/c
credits              -> credits/c
can-enroll?          -> boolean?
pending-corequisites -> List<course-code>
groups               -> List<group-option>
```

Semántica:

- `can-enroll?` se consume tal como fue producido por C.
- `pending-corequisites` se consume tal como fue producido por C.
- `groups` conserva las relaciones de choque necesarias para la Etapa 2.

No se conservan en el modelo de dominio:

```text
nombre
requisitos completos
horarios
```

porque la lógica funcional de Etapa 2 no los necesita actualmente.

## 7.5 `catalog`

```text
catalog
├── schema-version
├── career-code
└── courses
```

Contrato:

```text
schema-version -> string?
career-code    -> career-code/c
courses        -> List<course>
```

El struct acepta estructuralmente cualquier `String` como versión.

La regla:

```text
schemaVersion = "2.0"
```

será validada posteriormente por `catalog-reader.rkt`.

## 7.6 `candidate-course`

```text
candidate-course
├── code
├── career
├── credits
├── pending-corequisites
└── groups
```

Representa un curso después de cruzar catálogo y preferencias.

Semántica:

```text
course
+
puedeMatricular = true
+
grupos permitidos por preferencias
        ↓
candidate-course
```

No contiene `can-enroll?` porque la existencia de un `candidate-course` implica que esa condición ya fue aplicada.

Contrato:

```text
code                 -> course-code/c
career               -> career-code/c
credits              -> credits/c
pending-corequisites -> List<course-code>
groups               -> List<group-option>
```

---

# 8. `preferences.rkt`

## 8.1 Responsabilidad

Representa las preferencias de una ejecución.

No lee `preferencias.json`.

No valida existencia de cursos o grupos.

No aplica elegibilidad académica.

## 8.2 `course-preference`

```text
course-preference
├── course-code
└── allowed-groups
```

Ejemplo conceptual:

```json
{
  "curso": "CE2201",
  "grupos": [1, 2]
}
```

se representa como:

```text
course-preference
├── CE2201
└── (1 2)
```

Contrato:

```text
course-code    -> course-code/c
allowed-groups -> List<group-number>
```

## 8.3 `preferences`

```text
preferences
├── min-credits
├── max-credits
└── courses
```

Contrato:

```text
min-credits -> credits/c
max-credits -> credits/c
courses     -> List<course-preference>
```

El modelo no garantiza:

```text
min-credits <= max-credits
```

porque esa es una relación semántica entre campos.

La validación pertenecerá a `preferences-reader.rkt`.

---

# 9. `combination.rkt`

## 9.1 Responsabilidad

Representa selecciones concretas y combinaciones construidas por la lógica funcional.

No genera combinaciones.

No filtra créditos.

No evalúa correquisitos por sí mismo.

No escribe JSON.

## 9.2 `selection`

```text
selection
├── course-code
├── group-number
├── career
├── credits
├── pending-corequisites
└── conflicts
```

Representa la decisión:

```text
incluir curso X con exactamente el grupo Y
```

Contrato:

```text
course-code          -> course-code/c
group-number         -> group-number/c
career               -> career-code/c
credits              -> credits/c
pending-corequisites -> List<course-code>
conflicts            -> List<group-key>
```

La selección conserva deliberadamente más información que solo `(curso, grupo)`.

Esto permite que una combinación pueda ser evaluada posteriormente sin volver a consultar el JSON original.

## 9.3 Razón de autosuficiencia

Si `selection` solo almacenara:

```text
curso
grupo
```

los módulos posteriores tendrían que volver al catálogo para obtener:

```text
créditos
carrera
correquisitos pendientes
choques
```

En cambio:

```text
candidate-course
+
group-option
      ↓
selection autosuficiente
```

reduce el acoplamiento entre el generador y el catálogo original.

## 9.4 `combination`

```text
combination
├── selections
└── total-credits
```

Contrato:

```text
selections    -> List<selection>
total-credits -> credits/c
```

Semántica:

```text
total-credits =
suma de selection.credits
```

El contrato estructural garantiza que `total-credits` sea un entero no negativo.

La consistencia de la suma será responsabilidad del generador y de sus pruebas.

---

# 10. Inmutabilidad

Todos los structs se crean mediante:

```racket
(struct nombre
  (...)
  #:transparent)
```

Ninguno utiliza:

```racket
#:mutable
```

El proyecto tampoco utiliza:

```racket
set!
```

Por tanto el flujo esperado es:

```text
valor anterior
     │
     ▼
función pura
     │
     ▼
valor nuevo
```

`#:transparent` permite inspección, comparación estructural y pruebas, pero no introduce mutabilidad.

---

# 11. Contratos públicos

Los modelos utilizan:

```racket
provide
contract-out
```

en lugar de Typed Racket.

Ejemplo conceptual:

```racket
(provide
 (contract-out
  [struct group-key
    ([course-code course-code/c]
     [group-number group-number/c])]))
```

Esto protege la frontera pública del módulo.

Ejemplo válido:

```racket
(group-key "CE2201" 1)
```

Ejemplo inválido:

```racket
(group-key "CE2201" 0)
```

El segundo caso produce una violación de contrato.

---

# 12. División entre validación estructural y semántica

| Regla | Responsable |
|---|---|
| código no vacío | contrato |
| carrera no vacía | contrato |
| grupo positivo | contrato |
| créditos no negativos | contrato |
| `can-enroll?` booleano | contrato |
| elementos de `groups` son `group-option` | contrato |
| elementos de `conflicts` son `group-key` | contrato |
| `schemaVersion = "2.0"` | `catalog-reader.rkt` |
| curso existe | reader |
| grupo existe | reader |
| no hay cursos duplicados | reader |
| no hay grupos duplicados | reader |
| choque referencia grupo existente | reader |
| choques son simétricos | reader |
| `min <= max` | `preferences-reader.rkt` |
| curso de preferencias existe | `preferences-reader.rkt` |
| grupo preferido existe | `preferences-reader.rkt` |

Esta separación evita mezclar representación del dominio con validación de archivos externos.

---

# 13. Pruebas implementadas

La historia contiene:

```text
tests/unit/contracts-test.rkt
tests/unit/models-test.rkt
```

## 13.1 `contracts-test.rkt`

Valida los contratos primitivos.

La suite existente contiene 15 comprobaciones.

## 13.2 `models-test.rkt`

Valida construcción y acceso básico de:

```text
group-key
group-option
course
catalog
candidate-course
course-preference
preferences
selection
combination
```

También prueba violaciones de contrato como:

```text
grupo 0
conflicto que no es group-key
can-enroll? no booleano
créditos negativos
grupo preferido inválido
selection con conflicto inválido
combination con elemento que no es selection
```

---

# 14. Compilación de modelos

Desde la raíz del repositorio:

```powershell
raco make .\src\models\contracts.rkt
raco make .\src\models\catalog.rkt
raco make .\src\models\preferences.rkt
raco make .\src\models\combination.rkt
```

Una compilación correcta normalmente no imprime errores.

Los directorios `compiled/` deben permanecer ignorados por Git.

---

# 15. Ejecución de pruebas

Prueba de contratos:

```powershell
raco test .\tests\unit\contracts-test.rkt
```

Prueba de modelos:

```powershell
raco test .\tests\unit\models-test.rkt
```

Todas las pruebas:

```powershell
raco test .\tests
```

Este último es el mecanismo común y portable del proyecto.

---

# 16. Makefile

El `Makefile` debe existir en la raíz del repositorio.

Contenido esperado:

```makefile
.PHONY: test models

test:
	raco test tests

models:
	raco make src/models/contracts.rkt
	raco make src/models/catalog.rkt
	raco make src/models/preferences.rkt
	raco make src/models/combination.rkt
```

Si el sistema posee `make`:

```bash
make models
make test
```

`make` no es una dependencia obligatoria. Los comandos oficiales siguen siendo `raco make` y `raco test`.

---

# 17. Verificación de inmutabilidad

Antes de integrar la historia:

```powershell
git grep "set!" -- src
git grep "#:mutable" -- src
```

Ambos comandos deben terminar sin coincidencias.

---

# 18. Interfaces públicas producidas

## `contracts.rkt`

```text
course-code/c
career-code/c
group-number/c
credits/c
```

## `catalog.rkt`

```text
group-key
group-key?
group-key-course-code
group-key-group-number

group-option
group-option?
group-option-number
group-option-conflicts

course
course?
course-code
course-career
course-credits
course-can-enroll?
course-pending-corequisites
course-groups

catalog
catalog?
catalog-schema-version
catalog-career-code
catalog-courses

candidate-course
candidate-course?
candidate-course-code
candidate-course-career
candidate-course-credits
candidate-course-pending-corequisites
candidate-course-groups
```

## `preferences.rkt`

```text
course-preference
course-preference?
course-preference-course-code
course-preference-allowed-groups

preferences
preferences?
preferences-min-credits
preferences-max-credits
preferences-courses
```

## `combination.rkt`

```text
selection
selection?
selection-course-code
selection-group-number
selection-career
selection-credits
selection-pending-corequisites
selection-conflicts

combination
combination?
combination-selections
combination-total-credits
```

---

# 19. Criterios de aceptación adaptados

La historia se considera técnicamente terminada cuando:

- [ ] existe `src/models/contracts.rkt`;
- [ ] existe `src/models/catalog.rkt`;
- [ ] existe `src/models/preferences.rkt`;
- [ ] existe `src/models/combination.rkt`;
- [ ] todos los módulos utilizan `#lang racket`;
- [ ] las interfaces públicas utilizan contratos;
- [ ] existen modelos para catálogo, grupo, conflicto, preferencias, selección y combinación;
- [ ] existe `candidate-course`;
- [ ] todos los structs son inmutables;
- [ ] no existe `#:mutable`;
- [ ] no existe `set!`;
- [ ] existe `contracts-test.rkt`;
- [ ] existe `models-test.rkt`;
- [ ] todos los modelos compilan mediante `raco make`;
- [ ] todas las pruebas pasan mediante `raco test tests`;
- [ ] existe `Makefile` en la raíz como mecanismo opcional;
- [ ] `compiled/` no se versiona;
- [ ] las responsabilidades e interfaces públicas están documentadas.

---

# 20. Comandos de validación final

Antes del commit:

```powershell
raco make .\src\models\contracts.rkt
raco make .\src\models\catalog.rkt
raco make .\src\models\preferences.rkt
raco make .\src\models\combination.rkt

raco test .\tests

git grep "set!" -- src
git grep "#:mutable" -- src

git status
git diff --cached
```

Resultado esperado:

```text
todos los modelos compilan
todas las pruebas pasan
no aparece set!
no aparece #:mutable
solo están staged los archivos de esta historia
```

---

# 21. Relación con historias posteriores

Esta historia define las representaciones que deberán reutilizar:

```text
catalog-reader.rkt
preferences-reader.rkt
candidates.rkt
conflicts.rkt
corequisites.rkt
credits.rkt
combinations.rkt
combination-writer.rkt
```

Si una historia posterior necesita cambiar campos, nombres o semántica de un modelo público, el cambio debe revisarse primero contra este contrato y contra el contrato maestro de Etapa 2.

---

# 22. Resultado de la historia

Al completar esta historia, Etapa 2 dispone de una capa de dominio común:

```text
valores primitivos
        ↓
contracts.rkt
        ↓
modelos estructurados
        ↓
catalog / preferences / combination
        ↓
interfaces públicas protegidas
        ↓
historias funcionales posteriores
```

A partir de este punto, los módulos futuros pueden desarrollarse de forma paralela sobre representaciones estables, inmutables y verificables.
