rm(list = ls())

ruta_base <- "datos/congelados/base_estudio_muerte_fetal_preanalisis_2026-08-10.csv"

base <- read.csv(
  ruta_base,
  fileEncoding = "UTF-8",
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "NULL")
)

analitica <- base

# Desenlace binario
analitica$MUERTE_FETAL_BINARIA <- ifelse(
  analitica$MUERTE_FETAL == "SI", 1,
  ifelse(analitica$MUERTE_FETAL == "NO", 0, NA)
)

# Edad materna limpia
analitica$EDAD_ANALITICA <- analitica$EDAD_NUM

analitica$EDAD_ANALITICA[
  !is.na(analitica$EDAD_ANALITICA) &
  (analitica$EDAD_ANALITICA < 10 |
   analitica$EDAD_ANALITICA > 60)
] <- NA

# Categoría de edad nueva
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

# Score MAMA limpio
analitica$SCORE_ANALITICO <- analitica$SCORE_NUM
analitica$SCORE_ANALITICO[
  !is.na(analitica$SCORE_ANALITICO) &
  analitica$SCORE_ANALITICO > 20
] <- NA

# Edad gestacional
analitica$EDAD_GESTACIONAL_ANALITICA <- analitica$SEMANAS_GESTACION_NUM

analitica$EDAD_GESTACIONAL_ANALITICA[
  !is.na(analitica$EDAD_GESTACIONAL_ANALITICA) &
  (analitica$EDAD_GESTACIONAL_ANALITICA < 20 |
   analitica$EDAD_GESTACIONAL_ANALITICA > 43)
] <- NA

cat("\n========================================\n")
cat("BASE ANALITICA FRECUENTISTA\n")
cat("========================================\n")

cat("\nFilas:", nrow(analitica), "\n")
cat("Columnas:", ncol(analitica), "\n")

cat("\nMUERTE_FETAL_BINARIA:\n")
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

ruta_salida <- "datos/procesados/base_analitica_frecuentista.csv"

write.csv(
  analitica,
  ruta_salida,
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("\nBase guardada en:\n")
cat(ruta_salida, "\n")

cat("\nLa base congelada NO fue modificada.\n")
