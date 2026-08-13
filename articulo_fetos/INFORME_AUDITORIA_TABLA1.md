# Informe de auditoría de porcentajes de la Tabla 1

## Población analítica

- Registros iniciales: 23.848.
- Registros con `MUERTE_FETAL_BINARIA` válido: 23.642.
- Registros analizados: 23.642.

## Tabla auditada

- Número de filas: 29, incluida la cabecera.
- Número de columnas: 4.
- Variables auditadas (11): Pareja estable; Instruccion; Acompanada; Riesgo al ingreso; Infeccion de vias urinarias (IVU); Ruptura prematura de membranas (RPM); Psicoprofilaxis (alguna); Hemorragia; Presentacion de vertice; Trastornos hipertensivos; Desprendimiento prematuro de placenta (DPP).

## Errores encontrados

- Porcentajes comparados: 56.
- Correctos: 22.
- Incorrectos: 34.
- Ambiguos: 0.

## Correcciones realizadas

| Variable | Categoría | Desenlace | Documento | Correcto | Diferencia (pp) |
|:--|:--|:--|:--|:--|--:|
| Pareja estable | SI | NO | 7008 (69.68%) | 7008 (30.32%) | 39.36 |
| Pareja estable | SI | SI | 136 (72.02%) | 136 (27.98%) | 44.04 |
| Instruccion | NINGUNA | NO | 622 (55.17%) | 622 (2.70%) | 52.47 |
| Instruccion | NINGUNA | SI | 13 (54.10%) | 13 (2.66%) | 51.44 |
| Instruccion | PRIMARIA | NO | 7617 (55.17%) | 7617 (33.08%) | 22.09 |
| Instruccion | PRIMARIA | SI | 170 (54.10%) | 170 (34.84%) | 19.26 |
| Instruccion | SUPERIOR | NO | 2084 (55.17%) | 2084 (9.05%) | 46.12 |
| Instruccion | SUPERIOR | SI | 41 (54.10%) | 41 (8.40%) | 45.70 |
| Acompanada | SI | NO | 17654 (23.53%) | 17654 (76.47%) | -52.94 |
| Acompanada | SI | SI | 334 (31.13%) | 334 (68.87%) | -37.74 |
| Riesgo al ingreso | RIESGO ALTO | NO | 10789 (36.72%) | 10789 (46.76%) | -10.04 |
| Riesgo al ingreso | RIESGO ALTO | SI | 253 (26.72%) | 253 (52.82%) | -26.10 |
| Riesgo al ingreso | RIESGO INMINENTE | NO | 3813 (36.72%) | 3813 (16.52%) | 20.20 |
| Riesgo al ingreso | RIESGO INMINENTE | SI | 98 (26.72%) | 98 (20.46%) | 6.26 |
| Infeccion de vias urinarias (IVU) | SI | NO | 304 (98.69%) | 304 (1.31%) | 97.38 |
| Infeccion de vias urinarias (IVU) | SI | SI | 2 (99.59%) | 2 (0.41%) | 99.18 |
| Ruptura prematura de membranas (RPM) | SI | NO | 2763 (88.07%) | 2763 (11.93%) | 76.14 |
| Ruptura prematura de membranas (RPM) | SI | SI | 30 (93.87%) | 30 (6.13%) | 87.74 |
| Psicoprofilaxis (alguna) | SI | NO | 19042 (17.37%) | 19042 (82.63%) | -65.26 |
| Psicoprofilaxis (alguna) | SI | SI | 314 (34.85%) | 314 (65.15%) | -30.30 |
| Hemorragia | SI | NO | 2635 (88.62%) | 2635 (11.38%) | 77.24 |
| Hemorragia | SI | SI | 50 (89.78%) | 50 (10.22%) | 79.56 |
| Presentacion de vertice | SI | NO | 22452 (3.03%) | 22452 (96.97%) | -93.94 |
| Presentacion de vertice | SI | SI | 473 (3.27%) | 473 (96.73%) | -93.46 |
| Trastornos hipertensivos | PREECLAMPSIA | NO | 2824 (84.06%) | 2824 (12.20%) | 71.86 |
| Trastornos hipertensivos | PREECLAMPSIA | SI | 63 (82.82%) | 63 (12.88%) | 69.94 |
| Trastornos hipertensivos | HTA INDUCIDA POR EL EMBARAZO | NO | 745 (84.06%) | 745 (3.22%) | 80.84 |
| Trastornos hipertensivos | HTA INDUCIDA POR EL EMBARAZO | SI | 15 (82.82%) | 15 (3.07%) | 79.75 |
| Trastornos hipertensivos | HTA PREEXISTENTE | NO | 62 (84.06%) | 62 (0.27%) | 83.79 |
| Trastornos hipertensivos | HTA PREEXISTENTE | SI | 1 (82.82%) | 1 (0.20%) | 82.62 |
| Trastornos hipertensivos | ECLAMPSIA | NO | 60 (84.06%) | 60 (0.26%) | 83.80 |
| Trastornos hipertensivos | ECLAMPSIA | SI | 5 (82.82%) | 5 (1.02%) | 81.80 |
| Desprendimiento prematuro de placenta (DPP) | SI | NO | 110 (99.52%) | 110 (0.48%) | 99.04 |
| Desprendimiento prematuro de placenta (DPP) | SI | SI | 15 (96.93%) | 15 (3.07%) | 93.86 |

## Validación

- Porcentajes recalculados desde base: OK.
- Suma por columnas: OK.
- Documento corregido generado: SÍ.
- Relectura del Word corregido: OK.
- Errores residuales: 0.

## Archivos generados

- `01_auditar_tabla1.R`
- `02_comparar_word_tabla1.py`
- `03_actualizar_documento.py`
- `04_ejecutar_auditoria_completa.R`
- `tabla1_auditoria_porcentajes.csv`
- `tabla1_corregida.csv`
- `errores_tabla1.csv`
- `validacion_final_tabla1.csv`
- `manuscrito/Articulo_fetos_BACKUP.docx`
- `manuscrito/Articulo_fetos_CORREGIDO.docx`
- `INFORME_AUDITORIA_TABLA1.md`

No se imputaron datos, no se modificó la base y no se realizaron modelos estadísticos.
