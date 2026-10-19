# Contrato KAN-18: Adaptación de la Salida de C al Contrato de Etapa 2

## 1. Propósito

Este documento define la especificación técnica para la actualización de la salida JSON producida por el programa en C (**CEmestre - Etapa 1**), garantizando el cumplimiento del contrato de datos de entrada requerido por el módulo en Racket (**CEmestre - Etapa 2**).

El objetivo de KAN-18 es asegurar la completa independencia del módulo funcional en Racket, de modo que no requiera re-evaluar datos ni acceder a fuentes originales de la Etapa 1 (archivos `.tsv` o `historial.txt`).

---

## 2. Alcance y Cambios Principales

1. **Evolución del Esquema (`schemaVersion: "2.0"`)**:
   - Se actualiza la versión del esquema del JSON producido de `"1.0"` a `"2.0"`.
2. **Identificación de Carrera por Curso**:
   - Cada objeto del arreglo `cursos` incluye de forma explícita la clave `"carrera"`, indicando la carrera de origen del curso (ej. `"IC"`, `"EL"`, `"Computadores"` o `"Electronica"`).
3. **Cobertura del Plan de Estudios**:
   - El dataset procesado y serializado por C se extiende para abarcar los primeros **seis semestres** de cada carrera.
4. **Preservación de Negocio**:
   - Se conservan intactas las reglas de detección de conflictos de horario a nivel de grupo (KAN-12) y la evaluación de elegibilidad académica por requisitos y correquisitos (KAN-13).

---

## 3. Especificación del Formato de Salida JSON (v2.0)

### 3.1 Estructura General

```json
{
  "schemaVersion": "2.0",
  "carrera": {
    "codigo": "IC",
    "nombre": "Ingeniería en Computadores"
  },
  "cursos": []
}
```

### 3.2 Campos Obligatorios por Objeto `Course`

| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `codigo` | `string` | Código oficial del curso (ej. `"CE2201"`). |
| `nombre` | `string` | Nombre descriptivo del curso. |
| `carrera` | `string` | **[NUEVO KAN-18]** Código o nombre de la carrera de origen. |
| `creditos` | `integer` | Número de créditos asignados al curso. |
| `semestre` | `integer` | Semestre del plan de estudios al que pertenece (entre 1 y 6). |
| `requisitos` | `array[string]` | Lista de códigos de asignaturas que constituyen prerrequisito. |
| `correquisitos` | `array[string]` | Lista de códigos de asignaturas que constituyen correquisito. |
| `correquisitosPendientes` | `array[string]` | Correquisitos no aprobados en el historial del alumno. |
| `grupos` | `array[object]` | Lista de objetos `Group` ofertados con sus horarios y choques. |
| `tieneChoque` | `boolean` | `true` si al menos un grupo del curso presenta choques. |
| `puedeMatricular` | `boolean` | Resultado de la evaluación académica (KAN-13). |

---

## 4. Ejemplo de Objeto Curso Serializado (v2.0)

```json
{
  "schemaVersion": "2.0",
  "carrera": {
    "codigo": "IC",
    "nombre": "Ingeniería en Computadores"
  },
  "cursos": [
    {
      "codigo": "CE2201",
      "nombre": "Estructuras de Datos",
      "carrera": "IC",
      "creditos": 4,
      "semestre": 2,

      "requisitos": [
        "CE1101"
      ],
      "correquisitos": [
        "MA1102"
      ],
      "correquisitosPendientes": [
        "MA1102"
      ],

      "grupos": [
        {
          "numero": 1,
          "horarios": [
            {
              "dia": "LUN",
              "inicio": "09:30",
              "fin": "11:20"
            }
          ],
          "tieneChoque": true,
          "choques": [
            {
              "curso": "MA1102",
              "grupo": 2
            }
          ]
        }
      ],

      "tieneChoque": true,
      "puedeMatricular": true
    }
  ]
}
```

---

## 5. Criterios de Aceptación y Verificación

1. **Ambas carreras contienen seis semestres**: El catálogo leído en TSV incluye asignaturas pertenecientes a los semestres 1 a 6.
2. **Carrera por curso**: Cada objeto dentro del arreglo `"cursos"` contiene la clave `"carrera"`.
3. **Versión de Esquema**: `schemaVersion` es exactamente `"2.0"`.
4. **Validez Sintáctica**: El JSON producido es válido y no presenta comas colgadas ni errores de formato.
5. **Generación Exclusiva por C**: El archivo es generado 100% por el ejecutable de C (`cemestre.exe`) sin intervención de Racket.
6. **Disponibilidad de Fixtures**: Existen archivos `.json` reales generados por C disponibles en `data/output/` para las pruebas autónomas de Racket.