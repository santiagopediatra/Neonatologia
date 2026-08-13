# ============================================================
# 02_auditoria_edad_score.R
# Auditoria especifica de EDAD y SCORE MAMA
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

cat("\n")
cat("============================================================\n")
cat("AUDITORIA DE EDAD Y SCORE MAMA\n")
cat("============================================================\n\n")

# ------------------------------------------------------------
# 1. EDAD
# ------------------------------------------------------------

cat("============================================================\n")
cat("1. EDAD ORIGINAL VS EDAD_NUM\n")
cat("============================================================\n\n")

edad_problema <- base[
  !is.na(base$EDAD_NUM) &
    (base$EDAD_NUM < 10 | base$EDAD_NUM > 60),
  c(
    "ID_REGISTRO",
    "NUMERO_FETO",
    "EDAD",
    "EDAD_NUM",
    "EDAD_MATERNA_CATEGORIA",
    "MUERTE_FETAL"
  ),
  drop = FALSE
]

cat("Numero de registros con edad improbable:",
    nrow(edad_problema), "\n\n")

cat("Frecuencia de EDAD_NUM improbable:\n")

print(
  sort(
    table(edad_problema$EDAD_NUM),
    decreasing = TRUE
  )
)

cat("\nPrimeros 100 registros problematicos:\n")

print(
  head(
    edad_problema,
    100
  ),
  row.names = FALSE
)

write.csv(
  edad_problema,
  "resultados/tablas/auditoria_edades_improbables.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 2. Comparacion EDAD original con EDAD_NUM
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("2. VALORES ORIGINALES DE EDAD\n")
cat("============================================================\n\n")

cat("Valores originales mas frecuentes asociados a errores:\n")

print(
  head(
    sort(
      table(
        edad_problema$EDAD,
        useNA = "ifany"
      ),
      decreasing = TRUE
    ),
    50
  )
)

# ------------------------------------------------------------
# 3. Edad aparentemente valida
# ------------------------------------------------------------

edad_valida <- base$EDAD_NUM[
  !is.na(base$EDAD_NUM) &
    base$EDAD_NUM >= 10 &
    base$EDAD_NUM <= 60
]

cat("\n")
cat("Resumen provisional de edades 10-60:\n")

print(
  summary(edad_valida)
)

cat("\nNumero provisional de edades 10-60:",
    length(edad_valida), "\n")

# ------------------------------------------------------------
# 4. SCORE MAMA
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("3. SCORE ORIGINAL VS SCORE_NUM\n")
cat("============================================================\n\n")

cat("Valores SCORE_NUM mayores de 20:\n")

score_problema <- base[
  !is.na(base$SCORE_NUM) &
    base$SCORE_NUM > 20,
  c(
    "ID_REGISTRO",
    "SCORE",
    "SCORE_NUM",
    "SCORE_1",
    "SCORE_1_NUM",
    "RIESGO_AL_INGRESO",
    "RIESGO",
    "MUERTE_FETAL"
  ),
  drop = FALSE
]

print(
  score_problema,
  row.names = FALSE
)

write.csv(
  score_problema,
  "resultados/tablas/auditoria_score_extremo.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 5. Edad gestacional
# ------------------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("4. EDAD GESTACIONAL CONTINUA\n")
cat("============================================================\n\n")

if ("SEMANAS_GESTACION_NUM" %in% names(base)) {

  print(
    summary(
      base$SEMANAS_GESTACION_NUM
    )
  )

  cat("\nValores menores de 20 o mayores de 43:\n")

  gestacion_extrema <- base[
    !is.na(base$SEMANAS_GESTACION_NUM) &
      (
        base$SEMANAS_GESTACION_NUM < 20 |
          base$SEMANAS_GESTACION_NUM > 43
      ),
    c(
      "ID_REGISTRO",
      "SEMANAS_GESTACION",
      "SEMANAS_GESTACION_NUM",
      "EDAD_GESTACIONAL_CATEGORIA",
      "MUERTE_FETAL"
    ),
    drop = FALSE
  ]

  print(
    gestacion_extrema,
    row.names = FALSE
  )

  cat(
    "\nNumero de edades gestacionales extremas:",
    nrow(gestacion_extrema),
    "\n"
  )
}

cat("\n")
cat("============================================================\n")
cat("AUDITORIA COMPLETADA\n")
cat("============================================================\n")