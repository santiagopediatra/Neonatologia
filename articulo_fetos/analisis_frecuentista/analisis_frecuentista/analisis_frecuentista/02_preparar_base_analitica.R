# ============================================================
# 02_preparar_base_analitica.R
# Preparacion de base analitica
# ============================================================

rm(list = ls())

options(
  stringsAsFactors = FALSE,
  scipen = 999
)

ruta_base <- paste0(
  "datos/congelados/",
  "base_estudio_muerte_fetal_preanalisis_2026-08-10.csv"
)

base <- read.csv(
  ruta_base,
  fileEncoding = "UTF-8",
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "NULL")
)

# ------------------------------------------------------------
# 1. Crear copia analitica
# ------------------------------------------------------------

analitica <- base

# ------------------------------------------------------------
# 2. Desenlace binario
# ------------------------------------------------------------

analitica$MUERTE_FETAL_BINARIA <- ifelse(
  analitica$MUERTE_FETAL == "SI", 1,
  ifelse(analitica$MUERTE_FETAL == "NO", 0, NA)
)

# ------------------------------------------------------------
# 3. Edad materna analitica
#    Se conservan solo valores plausibles
# ------------------------------------------------------------

analitica$EDAD_ANALITICA <- analitica$EDAD_NUM

analitica$EDAD_ANALITICA[
  analitica$EDAD_ANALITICA < 10 |
  analitica$EDAD_ANALITICA > 60
] <- NA

# Categoria analitica
analitica$EDAD_CATEGORIA_ANALITICA <- NA_character_

analitica$EDAD_CATEGORIA_ANALITICA[
  !is.na(analitica$EDAD_ANALITICA) &
  analitica$EDAD_ANALITICA < 20
] <- "<20"

analitica$EDAD_CATEGORIA_ANALITICA[
  !is.na(analitica$EDAD_ANALITICA) &
  analitica$EDAD_ANALITICA >= 20 &
  analitica$EDAD_ANALITICA < 35
] <- "20-34"

analitica$EDAD_CATEGORIA_ANALITICA[
  !is.na(analitica$EDAD_ANALITICA) &
  analitica$EDAD_ANALITICA >= 35
] <- ">=35"

analitica$EDAD_CATEGORIA_ANALITICA <- factor(
  analitica$EDAD_CATEGORIA_ANALITICA,
  levels = c("20-34", "<20", ">=35")
)

# ------------------------------------------------------------
# 4. Score MAMA analitico
# ------------------------------------------------------------

analitica$SCORE_ANALITICO <- analitica$SCORE_NUM

analitica$SCORE_ANALITICO[
  analitica$SCORE_ANALITICO > 20
] <- NA

# ------------------------------------------------------------
# 5. Edad gestacional continua
# ------------------------------------------------------------

analitica$EDAD_GESTACIONAL_ANALITICA <- analitica$SEMANAS_GESTACION_NUM

analitica$EDAD_GESTACIONAL_ANALITICA[
  analitica$EDAD_GESTACIONAL_ANALITICA < 20 |
  analitica$EDAD_GESTACIONAL_ANALITICA > 43
] <- NA

# ------------------------------------------------------------
# 6. Resumen de cambios
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("BASE ANALITICA PREPARADA\n")
cat("============================================================\n\n")

cat("Filas:", nrow(analitica), "\n")
cat("Columnas:", ncol(analitica), "\n\n")

cat("MUERTE_FETAL_BINARIA:\n")
print(table(analitica$MUERTE_FETAL_BINARIA, useNA = "always"))

cat("\nEDAD_ANALITICA:\n")
print(summary(analitica$EDAD_ANALITICA))

cat("\nEDAD_CATEGORIA_ANALITICA:\n")
print(table(
  analitica$EDAD_CATEGORIA_ANALITICA,
  useNA = "always"
))

cat("\nSCORE_ANALITICO:\n")
print(summary(analitica$SCORE_ANALITICO))

cat("\nEDAD_GESTACIONAL_ANALITICA:\n")
print(summary(analitica$EDAD_GESTACIONAL_ANALITICA))

# ------------------------------------------------------------
# 7. Guardar nueva base analitica
# ------------------------------------------------------------

ruta_salida <- "datos/procesados/base_analitica_frecuentista.csv"

write.csv(
  analitica,
  ruta_salida,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("\nBase guardada en:\n")
cat(ruta_salida, "\n")

cat("\nLa base congelada original NO fue modificada.\n")