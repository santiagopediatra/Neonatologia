# Evaluación de imputación múltiple

Clasificación global: **CONSIDERAR_COMO_SENSIBILIDAD**.

La variable de seguro es la única variable modelada con una proporción alta de faltantes: 7.336 de 23.642 registros con desenlace conocido (31,03%) en la variable analítica `SEGURO_A`. En la base total, la variable de origen presenta 7.386 de 23.848 faltantes (30,97%). Esta magnitud podría justificar evaluar imputación múltiple en un trabajo posterior de sensibilidad, pero no permite recomendarla automáticamente.

No existe evidencia directa suficiente para clasificar el mecanismo como MCAR, MAR o MNAR ni para especificar de forma defendible un modelo de imputación. Además, seguro se utilizó en un análisis de sensibilidad de casos completos y no en el modelo principal. Por ello no se ejecutó imputación múltiple.

Para las demás variables modeladas, la ausencia fue nula o baja (máximo 1,03% en `EDAD_CAT` dentro de la tabla analítica disponible), por lo que la clasificación es **NO_NECESARIA** con la evidencia actual. Ninguna variable se clasifica como **RECOMENDABLE** sin análisis adicional del mecanismo de ausencia y del modelo de imputación.

