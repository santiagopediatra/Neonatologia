# Validación final de la auditoría crítica

## Documento y preservación

- Maestro de origen: `manuscrito/Articulo_fetos_MAESTRO.docx`.
- Copia de seguridad: `manuscrito/Articulo_fetos_MAESTRO_BACKUP.docx`.
- Documento final: `manuscrito/Articulo_fetos_MAESTRO_FINAL.docx`.
- Se preservaron exactamente 15 tablas y 5 figuras. La comparación de todos los textos de celda entre el maestro y el final fue idéntica.

## Verificación numérica

- **Tabla 1:** todos los valores formateados de `tabla1_corregida.csv` están presentes; no se modificó ninguna celda. La auditoría previa confirma porcentajes por columna y ausencia de errores residuales.
- **Adherencia:** permanecieron sin cambios N total 23.848, N con desenlace 23.642, N analítico 23.442 y 423 eventos; distribución 10.242/9.524/3.676; mortalidad 1,56%/1,47%/3,35%; OR y sensibilidades coinciden con los CSV reproducibles.
- **Tabla 10:** no se alteró. Eclampsia permanece separada de preeclampsia, con aOR frecuentista 3,37 (IC95% 1,32–8,61) y OR posterior obstétrico 2,16 (CrI95% 0,87–4,89; P[OR>1]=0,952). Las notas de escala se preservaron.
- **Paradigmas:** IC95% y valores p se usan para estimaciones frecuentistas; CrI95% y probabilidades posteriores para las bayesianas.
- Errores numéricos residuales detectados: **0**.

## Datos faltantes

- `SEGURO_A` presenta 7.336/23.642 faltantes (31,03%) entre registros con desenlace conocido.
- La variable de origen `SEGURO` presenta 7.386/23.848 faltantes (30,97%) en la base total.
- No se asumió MCAR, MAR o MNAR y no se realizó imputación múltiple.
- Se creó `AUDITORIA_DATOS_FALTANTES.csv` para todas las variables de la base y se añadieron las variables analíticas modeladas con su población de referencia.

## Diagnósticos bayesianos

- R-hat máximo: 1,0012802418 (redondeado en el manuscrito a 1,0013).
- ESS bulk mínimo: 8.663,55; ESS tail mínimo: 7.153,09.
- Divergencias: 0; excedencias de treedepth: 0 en los diez modelos.
- E-BFMI: no disponible en los archivos reproducibles; no fue inventado ni declarado como evaluado.
- PPC (eventos observados; intervalo predictivo 2,5%–97,5%): principal 468 (409–529), clínico 471 (413–532), obstétrico 480 (422–541), seguro 324 (277–374). Las medianas predictivas fueron 468, 470, 480 y 324, respectivamente.
- Conclusión: no se identificaron problemas relevantes de convergencia o muestreo según los diagnósticos evaluados.

## Marcadores y referencias

- `[CITA]`, `[CITAR]`, `[REFERENCIA]`, `TODO`, `XXX`, `REQUIERE_DATO`: 0.
- Permanecen 9 marcadores `[COMPLETAR]` o variantes, todos dependientes de información que debe proporcionar el autor: autores, afiliaciones, correspondencia, institución/periodo y ética.
- Se incorporaron cuatro fuentes verificadas; no se dejaron sustitutos de bibliografía vacía.

## Interpretación

- Edad gestacional permanece solo como análisis de sensibilidad; no se presenta como control causal de confusión.
- Riesgo al ingreso se describe como evaluación clínica al momento de atención y marcador de gravedad, no como exposición etiológica ni estimación causal.
- Las asociaciones negativas no se describen como efectos protectores.
- No se añadieron modelos, imputaciones, priors ni análisis estadísticos.

## Validación visual

El DOCX se convirtió temporalmente a PDF (27 páginas, tamaño carta) y se revisaron tablas, figura de adherencia, títulos, pies, referencias, caracteres especiales, intervalos y símbolos. Las 15 tablas y 5 figuras son visibles; no se observaron cortes que oculten contenido, pérdida de numeración ni caracteres corruptos. El PDF fue solo un artefacto temporal de inspección y no reemplaza el DOCX.

