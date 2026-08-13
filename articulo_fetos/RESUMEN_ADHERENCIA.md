# Resumen del análisis de adherencia prenatal

## Población analítica

- N inicial: 23848.
- N con muerte fetal válida: 23642.
- N analítico final: 23442.
- Desenlace faltante: 206.
- Edad gestacional analítica faltante: 194.
- Controles faltantes: 56.
- Edad gestacional original implausible (<20 o >43): 0.
- Controles implausibles (<0): 0.

## Adherencia

- Buena: 10242 (43,69%).
- Parcial: 9524 (40,63%).
- Baja: 3676 (15,68%).
- Adherencia >100%: 3693 (15,75%).

## Mortalidad

| Categoría | N | Muertes | Mortalidad % | IC95% Wilson |
|:--|--:|--:|--:|:--|
| Buena | 10242 | 160 | 1,56 | 1,34–1,82 |
| Parcial | 9524 | 140 | 1,47 | 1,25–1,73 |
| Baja | 3676 | 123 | 3,35 | 2,81–3,98 |

## Regresión

La categoría de referencia fue Buena. El modelo ajustado por edad gestacional se consideró una sensibilidad.

| Modelo | Contraste | OR | IC95% | p |
|:--|:--|--:|:--|--:|
| Crudo | Parcial vs Buena | 0,94 | 0,75–1,18 | 0.596 |
| Crudo | Baja vs Buena | 2,18 | 1,72–2,77 | <0.001 |
| Ajustado_EG | Parcial vs Buena | 1,08 | 0,85–1,37 | 0.528 |
| Ajustado_EG | Baja vs Buena | 1,84 | 1,43–2,38 | <0.001 |

## Estratificación

Casos con EG <20 semanas excluidos del análisis estratificado: 0. Los resultados completos están en `adherencia_estratificado.csv`.

## Comparación con análisis previo

Los modelos previos expresaron la exposición como número continuo de controles (por unidad o por 1 DE). La nueva exposición es una categoría derivada de controles observados y edad gestacional; por ello, la comparación es conceptual y direccional, no una comparación numérica directa de OR.

## Lo que los datos muestran

Los datos describen diferencias de mortalidad y de odds entre categorías operacionales de adherencia. El cambio al incluir edad gestacional se interpreta como sensibilidad de especificación.

## Lo que los datos no pueden demostrar

No permiten separar causalmente edad gestacional, oportunidad acumulada de controles, acoplamiento matemático, selección, temporalidad, confusión residual y una posible asociación real. La regla 1/2/3/6/8 fue una especificación operacional solicitada y no se atribuyó como regla textual exacta de la OMS.
