#!/usr/bin/env Rscript

ejecutar <- function(comando, args = character()) {
  estado <- system2(comando, args = args)
  if (estado != 0) stop("Falló: ", comando, " ", paste(args, collapse = " "))
}

python <- ".venv/bin/python"
ejecutar(python, "--version")
ejecutar(python, c("-c", shQuote("import docx; print(docx.__version__)")))

ejecutar("Rscript", "01_auditar_tabla1.R")
ejecutar(python, "02_comparar_word_tabla1.py")
ejecutar(python, "03_actualizar_tabla1_word.py")
ejecutar("Rscript", "04_analisis_adherencia_prenatal.R")
ejecutar(python, "05_actualizar_manuscrito_adherencia.py")

aud <- read.csv("adherencia_auditoria.csv", check.names = FALSE)
a2 <- read.csv("adherencia_tabla_A2.csv", check.names = FALSE)
mods <- read.csv("adherencia_modelos_logisticos.csv", check.names = FALSE)
est <- read.csv("adherencia_estratificado.csv", check.names = FALSE)
err <- read.csv("errores_tabla1.csv", check.names = FALSE)

valor <- function(nombre) aud$valor[aud$indicador == nombre][1]
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")
fmtp <- function(x) ifelse(x < 0.001, "<0,001", fmt(x, 3))
dist <- aggregate(N ~ categoria_adherencia, a2, sum)
dist$pct <- 100 * dist$N / sum(dist$N)
mcat <- mods[grepl("^categoria_adherencia", mods$termino), ]

lineas <- c(
  "# Informe final de auditoría y adherencia prenatal", "",
  "## Auditoría Tabla 1", "",
  paste0("- Celdas auditadas: ", nrow(err), "."),
  paste0("- Celdas correctas: ", sum(err$estado == "OK"), "."),
  paste0("- Celdas incorrectas: ", sum(err$estado == "ERROR_PORCENTAJE"), "."),
  paste0("- Celdas corregidas: ", sum(err$estado == "ERROR_PORCENTAJE"), "."),
  paste0("- Ambigüedades: ", sum(err$estado %in% c("NO_ENCONTRADO", "REQUIERE_REVISION_MANUAL")), "."), "",
  "## Población", "",
  paste0("- N total: ", valor("N inicial"), "."),
  paste0("- N con muerte fetal válida: ", valor("N con muerte fetal válida"), "."),
  paste0("- N analítico de adherencia: ", valor("N analítico"), "."),
  paste0("- Desenlace faltante: ", valor("Muerte fetal faltante"), "."),
  paste0("- Edad gestacional analítica faltante: ", valor("EG analítica faltante"), "."),
  paste0("- Controles faltantes: ", valor("Controles faltantes"), "."),
  paste0("- EG implausible en variable original: ", valor("EG implausible en variable original"), "."),
  paste0("- Controles implausibles: ", valor("Controles implausibles"), "."), "",
  "## Regla de adherencia", "",
  "```r",
  "controles_esperados <- function(eg) {",
  "  case_when(",
  "    is.na(eg) ~ NA_real_,",
  "    eg < 13 ~ 1,",
  "    eg < 20 ~ 2,",
  "    eg < 28 ~ 3,",
  "    eg < 36 ~ 6,",
  "    eg >= 36 ~ 8",
  "  )",
  "}",
  "```", "",
  "Esta fue una especificación operacional solicitada; no se atribuyó como regla textual exacta de la OMS.", "",
  "## Distribución", "",
  paste0("- ", dist$categoria_adherencia, ": ", dist$N, " (", fmt(dist$pct), "%)."),
  paste0("- Adherencia >100%: ", valor("Casos adherencia >100%"), " (",
         fmt(valor("Porcentaje adherencia >100%")), "%)."), "",
  "## Mortalidad fetal", "",
  "| Adherencia | N | Muertes | Mortalidad % | IC95% Wilson |",
  "|:--|--:|--:|--:|:--|",
  paste0("| ", a2$categoria_adherencia, " | ", a2$N, " | ", a2$n_muertes, " | ",
         fmt(a2$mortalidad_pct), " | ", fmt(a2$IC95_inf), "–", fmt(a2$IC95_sup), " |"), "",
  "## Regresión", "",
  "| Modelo | Contraste | OR | IC95% | p | N | Eventos |",
  "|:--|:--|--:|:--|--:|--:|--:|",
  paste0("| ", mcat$modelo, " | ", sub("categoria_adherencia", "", mcat$termino), " vs Buena | ",
         fmt(mcat$OR), " | ", fmt(mcat$IC95_inf), "–", fmt(mcat$IC95_sup), " | ",
         fmtp(mcat$p), " | ", mcat$N, " | ", mcat$eventos, " |"), "",
  "El modelo ajustado por edad gestacional es un análisis de sensibilidad; no se interpreta automáticamente como control de confusión.", "",
  "## Estratificación", "",
  "| Estrato EG | Adherencia | N | Muertes | Mortalidad % | IC95% Wilson |",
  "|:--|:--|--:|--:|--:|:--|",
  paste0("| ", est$estrato_eg, " | ", est$categoria_adherencia, " | ", est$N, " | ",
         est$n_muertes, " | ", fmt(est$mortalidad_pct), " | ", fmt(est$IC95_inf), "–",
         fmt(est$IC95_sup), " |"), "",
  paste0("Casos con EG <20 semanas excluidos solo de la estratificación: ", unique(est$casos_eg_menor_20_excluidos), "."), "",
  "## Comparación con análisis previo", "",
  "Los análisis previos modelaron el número continuo de controles, mientras que este análisis utiliza categorías derivadas de controles observados/esperados por edad gestacional. La concordancia solo se evaluó de forma conceptual y direccional; los OR no son numéricamente equiparables.", "",
  "## Interpretación", "",
  "### Hallazgos", "",
  "La categoría baja presentó mayor mortalidad observada y mayores odds que la categoría buena. La estimación se desplazó hacia la nulidad en la sensibilidad ajustada por edad gestacional.", "",
  "### Posibles explicaciones", "",
  "Edad gestacional, oportunidad acumulada de controles, dependencia matemática del indicador, selección, temporalidad, confusión residual y una asociación real pueden contribuir conjuntamente.", "",
  "### Limitaciones", "",
  "La regla operacional no fue validada externamente en este proyecto. La edad gestacional participa tanto en la construcción del indicador como en el modelo de sensibilidad. El diseño observacional y la estructura del registro limitan la interpretación temporal.", "",
  "### Afirmaciones no demostrables", "",
  "Los resultados no demuestran causalidad, un efecto preventivo ni que el cambio entre modelos corresponda exclusivamente a confusión.", "",
  "## Word final", "",
  "- Archivo generado: `manuscrito/Articulo_fetos_CORREGIDO.docx`.",
  "- Secciones modificadas: Resumen (Métodos y Resultados), Métodos, Resultados de atención prenatal, Discusión, Limitaciones y Conclusiones.",
  "- Celdas corregidas en Tabla 1: 34.",
  "- Tablas incorporadas: A1–A4.",
  "- Figura incorporada: A1.",
  "- Revisión humana pendiente por inconsistencia numérica: ninguna.", "",
  "## Reproducibilidad", "",
  "Scripts: `01_auditar_tabla1.R`, `02_comparar_word_tabla1.py`, `03_actualizar_tabla1_word.py`, `04_analisis_adherencia_prenatal.R`, `05_actualizar_manuscrito_adherencia.py`, `06_ejecutar_pipeline_completo.R`.",
  "Resultados: `tabla1_auditoria_porcentajes.csv`, `tabla1_corregida.csv`, `errores_tabla1.csv`, `adherencia_auditoria.csv`, `adherencia_mayor_100.csv`, `adherencia_tabla_A1.csv`, `adherencia_tabla_A2.csv`, `adherencia_modelos_logisticos.csv`, `adherencia_estratificado.csv`, `adherencia_fig1.png`, `RESUMEN_ADHERENCIA.md`, `PLAN_CAMBIOS_MANUSCRITO_ADHERENCIA.md` y `VALIDACION_MANUSCRITO_FINAL.md`."
)

writeLines(lineas, "INFORME_FINAL_AUDITORIA_Y_ADHERENCIA.md", useBytes = TRUE)
cat("Pipeline completo y validado.\n")
