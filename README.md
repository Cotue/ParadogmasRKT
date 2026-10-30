# CEmestre — Etapa 2

Implementación de la Etapa 2 de CEmestre utilizando Racket y paradigma funcional.

## Responsabilidad de esta etapa

La Etapa 2 recibe:

- el catálogo procesado generado por la Etapa 1 en C;
- las preferencias de matrícula del estudiante.

Genera combinaciones válidas de cursos y grupos utilizando streams y las filtra de acuerdo con las reglas definidas para la etapa.

## Tecnologías

- Racket 9.3
- `#lang racket`
- `racket/stream`
- `racket/contract`
- `racket/contract/parametric`
- `json`
- `rackunit`
- Git / GitHub
- Visual Studio Code + Magic Racket

## Arquitectura

El contrato maestro se encuentra en:

`docs/contracts/Contrato_Arquitectura_Etapa2.md`

## Ejecución prevista

```bash
racket src/main.rkt <catalogo.json> <preferencias.json> <salida.json>
