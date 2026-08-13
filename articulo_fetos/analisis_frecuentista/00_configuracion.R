# ============================================================
# 00_configuracion.R
# Configuracion inicial del analisis frecuentista
# Estudio de muerte fetal
# ============================================================

rm(list = ls())

options(
  stringsAsFactors = FALSE,
  scipen = 999
)

# ------------------------------------------------------------
# 1. Rutas del proyecto
# ------------------------------------------------------------

ruta_base <- "datos/congelados/base_estudio_muerte_fetal_preanalisis_2026-08-10.csv"

ruta_resultados <- "resultados"
ruta_tablas <- file.path(ruta_resultados, "tablas")
ruta_figuras <- file.path(ruta_resultados, "figuras")
ruta_modelos <- file.path(ruta_resultados, "modelos")

# ------------------------------------------------------------
# 2. Verificar que existan las rutas principales
# ------------------------------------------------------------

if (!file.exists(ruta_base)) {
  stop(
    paste0(
      "ERROR: no se encontro la base congelada en: ",
      ruta_base
    )
  )
}

dir.create(ruta_tablas, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_figuras, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_modelos, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 3. Cargar base
# ------------------------------------------------------------

base <- read.csv(
  ruta_base,
  fileEncoding = "UTF-8",
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "NULL")
)

# ------------------------------------------------------------
# 4. Comprobaciones estructurales
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("CONFIGURACION INICIAL DEL ANALISIS\n")
cat("============================================================\n\n")

cat("R version:\n")
cat(R.version.string, "\n\n")

cat("Directorio de trabajo:\n")
cat(getwd(), "\n\n")

cat("Base cargada:\n")
cat(ruta_base, "\n\n")

cat("Filas:", nrow(base), "\n")
cat("Columnas:", ncol(base), "\n\n")

# ------------------------------------------------------------
# 5. Verificar desenlace principal
# ------------------------------------------------------------

if (!"MUERTE_FETAL" %in% names(base)) {
  stop("ERROR: MUERTE_FETAL no existe en la base.")
}

cat("Distribucion de MUERTE_FETAL:\n")
print(
  table(
    base$MUERTE_FETAL,
    useNA = "ifany"
  )
)

cat("\n")

# ------------------------------------------------------------
# 6. Revisar nombres de variables
# ------------------------------------------------------------

cat("Primeras 20 variables:\n")
print(head(names(base), 20))

cat("\n")

# ------------------------------------------------------------
# 7. Revisar tipos de variables principales
# ------------------------------------------------------------

variables_clave <- c(
  "MUERTE_FETAL",
  "EDAD_NUM",
  "EDAD_MATERNA_CATEGORIA",
  "HIPERTENSION_BINARIA",
  "RPM",
  "EMBARAZO_MULTIPLE_BINARIO",
  "EDAD_GESTACIONAL",
  "EDAD_GESTACIONAL_CATEGORIA",
  "CUALQUIER_INFECCION_MATERNA",
  "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA"
)

variables_presentes <- variables_clave[
  variables_clave %in% names(base)
]

cat("Estructura de variables clave:\n")
str(base[variables_presentes])

cat("\n")

# ------------------------------------------------------------
# 8. Conteo general de faltantes
# ------------------------------------------------------------

faltantes <- sort(
  colSums(is.na(base)),
  decreasing = TRUE
)

cat("10 variables con mas NA reales:\n")
print(head(faltantes, 10))

cat("\n")

cat("============================================================\n")
cat("CONFIGURACION COMPLETADA\n")
cat("============================================================\n")