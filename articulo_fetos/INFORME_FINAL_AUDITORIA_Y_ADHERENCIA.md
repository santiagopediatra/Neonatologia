# Informe final de auditoría y adherencia prenatal

## Auditoría Tabla 1

- Celdas auditadas: 56.
- Celdas correctas: 22.
- Celdas incorrectas: 34.
- Celdas corregidas: 34.
- Ambigüedades: 0.

## Población

- N total: 23848.
- N con muerte fetal válida: 23642.
- N analítico de adherencia: 23442.
- Desenlace faltante: 206.
- Edad gestacional analítica faltante: 194.
- Controles faltantes: 56.
- EG implausible en variable original: 0.
- Controles implausibles: 0.

## Regla de adherencia

```r
controles_esperados <- function(eg) {
  case_when(
    is.na(eg) ~ NA_real_,
    eg < 13 ~ 1,
    eg < 20 ~ 2,
    eg < 28 ~ 3,
    eg < 36 ~ 6,
    eg >= 36 ~ 8
  )
}
```

Esta fue una especificación operacional solicitada; no se atribuyó como regla textual exacta de la OMS.

## Distribución

- Baja: 3676 (15,68%).
- Buena: 10242 (43,69%).
- Parcial: 9524 (40,63%).
- Adherencia >100%: 3693 (15,75%).

## Mortalidad fetal

| Adherencia | N | Muertes | Mortalidad % | IC95% Wilson |
|:--|--:|--:|--:|:--|
| Buena | 10242 | 160 | 1,56 | 1,34–1,82 |
| Parcial | 9524 | 140 | 1,47 | 1,25–1,73 |
| Baja | 3676 | 123 | 3,35 | 2,81–3,98 |

## Regresión

| Modelo | Contraste | OR | IC95% | p | N | Eventos |
|:--|:--|--:|:--|--:|--:|--:|
| Crudo | Parcial vs Buena | 0,94 | 0,75–1,18 | 0,596 | 23442 | 423 |
| Crudo | Baja vs Buena | 2,18 | 1,72–2,77 | <0,001 | 23442 | 423 |
| Ajustado_EG | Parcial vs Buena | 1,08 | 0,85–1,37 | 0,528 | 23442 | 423 |
| Ajustado_EG | Baja vs Buena | 1,84 | 1,43–2,38 | <0,001 | 23442 | 423 |

El modelo ajustado por edad gestacional es un análisis de sensibilidad; no se interpreta automáticamente como control de confusión.

## Estratificación

| Estrato EG | Adherencia | N | Muertes | Mortalidad % | IC95% Wilson |
|:--|:--|--:|--:|--:|:--|
| 20 a <28 semanas | Buena | 44 | 26 | 59,09 | 44,41–72,31 |
| 20 a <28 semanas | Parcial | 16 | 7 | 43,75 | 23,10–66,82 |
| 20 a <28 semanas | Baja | 42 | 26 | 61,90 | 46,81–75,00 |
| 28 a <36 semanas | Buena | 681 | 35 | 5,14 | 3,72–7,06 |
| 28 a <36 semanas | Parcial | 239 | 16 | 6,69 | 4,16–10,60 |
| 28 a <36 semanas | Baja | 202 | 24 | 11,88 | 8,12–17,07 |
| ≥36 semanas | Buena | 9517 | 99 | 1,04 | 0,86–1,26 |
| ≥36 semanas | Parcial | 9269 | 117 | 1,26 | 1,05–1,51 |
| ≥36 semanas | Baja | 3432 | 73 | 2,13 | 1,70–2,67 |

Casos con EG <20 semanas excluidos solo de la estratificación: 0.

## Comparación con análisis previo

Los análisis previos modelaron el número continuo de controles, mientras que este análisis utiliza categorías derivadas de controles observados/esperados por edad gestacional. La concordancia solo se evaluó de forma conceptual y direccional; los OR no son numéricamente equiparables.

## Interpretación

### Hallazgos

La categoría baja presentó mayor mortalidad observada y mayores odds que la categoría buena. La estimación se desplazó hacia la nulidad en la sensibilidad ajustada por edad gestacional.

### Posibles explicaciones

Edad gestacional, oportunidad acumulada de controles, dependencia matemática del indicador, selección, temporalidad, confusión residual y una asociación real pueden contribuir conjuntamente.

### Limitaciones

La regla operacional no fue validada externamente en este proyecto. La edad gestacional participa tanto en la construcción del indicador como en el modelo de sensibilidad. El diseño observacional y la estructura del registro limitan la interpretación temporal.

### Afirmaciones no demostrables

Los resultados no demuestran causalidad, un efecto preventivo ni que el cambio entre modelos corresponda exclusivamente a confusión.

## Word final

- Archivo generado: `manuscrito/Articulo_fetos_CORREGIDO.docx`.
- Secciones modificadas: Resumen (Métodos y Resultados), Métodos, Resultados de atención prenatal, Discusión, Limitaciones y Conclusiones.
- Celdas corregidas en Tabla 1: 34.
- Tablas incorporadas: A1–A4.
- Figura incorporada: A1.
- Revisión humana pendiente por inconsistencia numérica: ninguna.

## Reproducibilidad

Scripts: `01_auditar_tabla1.R`, `02_comparar_word_tabla1.py`, `03_actualizar_tabla1_word.py`, `04_analisis_adherencia_prenatal.R`, `05_actualizar_manuscrito_adherencia.py`, `06_ejecutar_pipeline_completo.R`.
Resultados: `tabla1_auditoria_porcentajes.csv`, `tabla1_corregida.csv`, `errores_tabla1.csv`, `adherencia_auditoria.csv`, `adherencia_mayor_100.csv`, `adherencia_tabla_A1.csv`, `adherencia_tabla_A2.csv`, `adherencia_modelos_logisticos.csv`, `adherencia_estratificado.csv`, `adherencia_fig1.png`, `RESUMEN_ADHERENCIA.md`, `PLAN_CAMBIOS_MANUSCRITO_ADHERENCIA.md` y `VALIDACION_MANUSCRITO_FINAL.md`.
