# Validación final de documentos

Fecha de validación: 2026-08-10.

## Artefactos

- `ARTICULO_MAESTRO.md`: OK, 46.825 bytes.
- `ARTICULO_MAESTRO.docx`: OK, 532.885 bytes.
- `SECCION_RESULTADOS_COMPLETA.docx`: OK, 523.949 bytes.
- `SUPLEMENTO_METODOS_Y_DIAGNOSTICOS.docx`: OK, 1.088.108 bytes.
- Trazabilidad de resultados: OK.
- STROBE pendientes: OK.
- Referencias pendientes: OK.

## Contenido interno de los DOCX

| Documento | Tablas editables | Imágenes embebidas | Pie de página |
|---|---:|---:|---:|
| Artículo maestro | 11 | 5 | Sí |
| Sección de resultados | 11 | 5 | Sí |
| Suplemento | 7 | 7 | Sí |

La inspección del XML interno confirmó Times New Roman de 12 puntos como fuente predeterminada, interlineado 1,5 (`w:line=360`), márgenes de 1.417 twips (aproximadamente 2,5 cm) y un campo de numeración en el pie de página.

## Controles editoriales y numéricos

- No se encontraron cadenas `NaN`.
- No se encontraron p-valores impresos con largas secuencias de ceros.
- Los intervalos frecuentistas se identificaron como IC95%.
- Los intervalos bayesianos se identificaron como CrI95%.
- Las probabilidades posteriores no se describieron como p-valores.
- Las expresiones relacionadas con causalidad se mantuvieron únicamente para negar o limitar una interpretación causal.
- Se verificaron en el texto DOCX: 23.848 registros totales, 23.642 con desenlace conocido, 489 muertes fetales, 23.153 sin muerte fetal y 206 desenlaces faltantes.
- Las figuras están embebidas en los DOCX; no dependen de rutas externas para visualizarse.
- Cada cifra narrativa de Resultados se vinculó con su fuente en `TRAZABILIDAD_RESULTADOS.csv`.

## Integridad

- Hashes de `datos/originales/` antes y después: coinciden.
- Hashes de `datos/congelados/` antes y después: coinciden.
- SHA256 de `datos/procesados/base_analitica_frecuentista.csv`: coincide.
- No se recalcularon modelos ni se modificaron resultados numéricos cerrados.

## Observación de renderizado

La estructura DOCX fue validada mediante extracción con Pandoc y revisión de su contenido OpenXML. La conversión adicional con LibreOffice no produjo salida en el entorno aislado por una restricción de `dconf`; esto no afectó la generación ni la integridad de los DOCX.
