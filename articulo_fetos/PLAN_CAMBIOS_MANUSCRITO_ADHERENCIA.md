# Plan de cambios del manuscrito: adherencia prenatal

| seccion | texto_actual | cambio_propuesto | resultado_que_lo_justifica | archivo_fuente |
|:--|:--|:--|:--|:--|
| Resumen — Métodos | No describe un indicador de adherencia prenatal. | Añadir la definición operacional controles observados/esperados y las categorías ≥80%, 50–<80% y <50%. | Nueva especificación operacional solicitada; N analítico 23.442. | `04_analisis_adherencia_prenatal.R`; `adherencia_auditoria.csv` |
| Resumen — Resultados | Solo informa el número continuo de controles. | Añadir mortalidad por adherencia y OR para baja frente a buena, distinguiendo el ajuste por EG como sensibilidad. | Baja: 123/3.676, 3,35%; OR 2,18; sensibilidad EG aOR 1,84. | `adherencia_tabla_A2.csv`; `adherencia_modelos_logisticos.csv` |
| Métodos — análisis frecuentista | No incluye la construcción del indicador de adherencia. | Incorporar regla operacional 1/2/3/6/8, categorías, casos completos, Wilson, modelos crudo y sensibilidad por EG. | Pipeline reproducible nuevo. | `04_analisis_adherencia_prenatal.R` |
| Resultados — atención prenatal | Describe asociaciones del número continuo de controles. | Añadir resultados categóricos de adherencia, sin sustituir los análisis previos. | Buena 10.242; parcial 9.524; baja 3.676; 423 eventos. | `adherencia_tabla_A1.csv`; `adherencia_tabla_A2.csv` |
| Resultados — tablas y figura | No presenta análisis categórico de adherencia. | Incorporar cuatro tablas auxiliares y la figura de mortalidad con IC95% Wilson. | Resultados reproducidos desde la base. | CSV de adherencia; `adherencia_fig1.png` |
| Discusión — atención prenatal | Discute número de controles y tiempo disponible. | Añadir que baja adherencia mostró asociación positiva, atenuada al considerar EG, sin atribución causal. | OR 2,18; sensibilidad aOR 1,84; exposición matemáticamente dependiente de EG. | `adherencia_modelos_logisticos.csv` |
| Limitaciones | No menciona el acoplamiento del indicador. | Añadir especificación operacional no validada externamente, oportunidad acumulada y acoplamiento matemático. | La EG construye el denominador y también integra la sensibilidad. | `04_analisis_adherencia_prenatal.R` |
| Conclusiones | Señala asociación negativa del número continuo de controles. | Añadir que la categoría baja presentó mayores odds, como resultado descriptivo dependiente de la especificación. | OR y sensibilidad reproducidos. | `adherencia_modelos_logisticos.csv` |

La interpretación científica se amplía, pero no se reemplazan los modelos principales ni se formula causalidad. Los OR del número continuo de controles y los de categorías de adherencia no se presentarán como numéricamente equivalentes.
