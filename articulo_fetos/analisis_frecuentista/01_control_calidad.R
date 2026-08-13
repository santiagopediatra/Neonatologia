# ============================================================
# 01_control_calidad.R
# Control de calidad previo al analisis estadistico
# Estudio de muerte fetal
# ============================================================

rm(list = ls())

options(
  stringsAsFactors = FALSE,
  scipen = 999
)

# ------------------------------------------------------------
# 1. Cargar base congelada
# ------------------------------------------------------------

ruta_base <- paste0(
  "datos/congelados/",
  "base_estudio_muerte_fetal_preanalisis_2026-08-10.csv"
)

if (!file.exists(ruta_base)) {
  stop("No se encontro la base congelada.")
}

base <- read.csv(
  ruta_base,
  fileEncoding = "UTF-8",
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "NULL")
)

cat("\n")
cat("============================================================\n")
cat("CONTROL DE CALIDAD PREANALITICO\n")
cat("============================================================\n\n")

cat("Filas:", nrow(base), "\n")
cat("Columnas:", ncol(base), "\n\n")

# ------------------------------------------------------------
# 2. Desenlace principal
# ------------------------------------------------------------

cat("============================================================\n")
cat("1. DESENLACE MUERTE_FETAL\n")
cat("============================================================\n\n")

print(
  table(
    base$MUERTE_FETAL,
    useNA = "always"
  )
)

cat("\nPorcentajes sobre la base completa:\n")

print(
  round(
    prop.table(
      table(
        base$MUERTE_FETAL,
        useNA = "always"
      )
    ) * 100,
    2
  )
)

cat("\n")

# Valores inesperados
valores_muerte <- unique(base$MUERTE_FETAL)

cat("Valores unicos encontrados:\n")
print(valores_muerte)

cat("\n")

# ------------------------------------------------------------
# 3. Buscar variables relacionadas con edad gestacional
# ------------------------------------------------------------

cat("============================================================\n")
cat("2. VARIABLES DE EDAD GESTACIONAL\n")
cat("============================================================\n\n")

vars_gestacional <- grep(
  "GEST",
  names(base),
  value = TRUE,
  ignore.case = TRUE
)

print(vars_gestacional)

cat("\n")

# ------------------------------------------------------------
# 4. Edad materna
# ------------------------------------------------------------

cat("============================================================\n")
cat("3. EDAD MATERNA\n")
cat("============================================================\n\n")

if ("EDAD_NUM" %in% names(base)) {

  print(summary(base$EDAD_NUM))

  cat("\nEdades menores de 10 o mayores de 60:\n")

  edades_extremas <- base[
    !is.na(base$EDAD_NUM) &
      (base$EDAD_NUM < 10 | base$EDAD_NUM > 60),
    c("ID_REGISTRO", "EDAD_NUM"),
    drop = FALSE
  ]

  print(edades_extremas)

  cat("\nNumero de edades extremas/improbables:",
      nrow(edades_extremas), "\n")
}

cat("\n")

# ------------------------------------------------------------
# 5. Score MAMA
# ------------------------------------------------------------

cat("============================================================\n")
cat("4. SCORE MAMA\n")
cat("============================================================\n\n")

vars_score <- grep(
  "SCORE",
  names(base),
  value = TRUE,
  ignore.case = TRUE
)

print(vars_score)

cat("\n")

if ("SCORE_NUM" %in% names(base)) {

  print(summary(base$SCORE_NUM))

  cat("\nValores SCORE_NUM mayores de 20:\n")

  score_extremo <- base[
    !is.na(base$SCORE_NUM) &
      base$SCORE_NUM > 20,
    c("ID_REGISTRO", "SCORE_NUM"),
    drop = FALSE
  ]

  print(score_extremo)
}

cat("\n")

# ------------------------------------------------------------
# 6. Identificador y embarazos multiples
# ------------------------------------------------------------

cat("============================================================\n")
cat("5. ESTRUCTURA EMBARAZO-FETO\n")
cat("============================================================\n\n")

cat("ID_REGISTRO disponible:",
    "ID_REGISTRO" %in% names(base), "\n")

cat("NUMERO_FETO disponible:",
    "NUMERO_FETO" %in% names(base), "\n")

cat("NUM_FETOS_EMBARAZO disponible:",
    "NUM_FETOS_EMBARAZO" %in% names(base), "\n\n")

if ("ID_REGISTRO" %in% names(base)) {

  cat("Registros totales:", nrow(base), "\n")

  cat(
    "ID_REGISTRO unicos:",
    length(unique(base$ID_REGISTRO)),
    "\n"
  )

  cat(
    "ID_REGISTRO faltantes:",
    sum(is.na(base$ID_REGISTRO)),
    "\n"
  )

  tabla_ids <- table(base$ID_REGISTRO)

  cat(
    "IDs que aparecen mas de una vez:",
    sum(tabla_ids > 1),
    "\n"
  )

  cat(
    "Maximo numero de filas por ID_REGISTRO:",
    max(tabla_ids),
    "\n\n"
  )

  cat("Distribucion de numero de filas por ID:\n")
  print(table(tabla_ids))
}

cat("\n")

if ("NUM_FETOS_EMBARAZO" %in% names(base)) {

  cat("Distribucion NUM_FETOS_EMBARAZO:\n")

  print(
    table(
      base$NUM_FETOS_EMBARAZO,
      useNA = "always"
    )
  )
}

cat("\n")

if ("NUMERO_FETO" %in% names(base)) {

  cat("Distribucion NUMERO_FETO:\n")

  print(
    table(
      base$NUMERO_FETO,
      useNA = "always"
    )
  )
}

cat("\n")

# ------------------------------------------------------------
# 7. Variables binarias principales
# ------------------------------------------------------------

cat("============================================================\n")
cat("6. VARIABLES BINARIAS PRINCIPALES\n")
cat("============================================================\n\n")

variables_binarias <- c(
  "HIPERTENSION_BINARIA",
  "RPM",
  "EMBARAZO_MULTIPLE_BINARIO",
  "CUALQUIER_INFECCION_MATERNA",
  "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
  "PRESENTACION_CEFALICA",
  "ETNIA_MINORITARIA",
  "PAREJA_ESTABLE",
  "SEGURO"
)

for (v in variables_binarias) {

  if (v %in% names(base)) {

    cat("\n---", v, "---\n")

    print(
      table(
        base[[v]],
        useNA = "always"
      )
    )
  }
}

cat("\n")

# ------------------------------------------------------------
# 8. Buscar variables relevantes por nombre
# ------------------------------------------------------------

cat("============================================================\n")
cat("7. BUSQUEDA DE VARIABLES RELEVANTES\n")
cat("============================================================\n\n")

patrones <- c(
  "GEST",
  "PESO",
  "HIPER",
  "PREECL",
  "PLACENTA",
  "INFE",
  "TORCH",
  "SIFIL",
  "IVU",
  "RPM",
  "RIESGO",
  "SCORE",
  "APGAR"
)

for (patron in patrones) {

  cat("\nPatron:", patron, "\n")

  encontrados <- grep(
    patron,
    names(base),
    value = TRUE,
    ignore.case = TRUE
  )

  print(encontrados)
}

cat("\n")

# ------------------------------------------------------------
# 9. Faltantes por variable
# ------------------------------------------------------------

cat("============================================================\n")
cat("8. DATOS FALTANTES\n")
cat("============================================================\n\n")

n_na <- colSums(is.na(base))

pct_na <- round(
  n_na / nrow(base) * 100,
  2
)

faltantes <- data.frame(
  VARIABLE = names(base),
  N_FALTANTE = n_na,
  PORCENTAJE_FALTANTE = pct_na,
  row.names = NULL
)

faltantes <- faltantes[
  order(
    faltantes$PORCENTAJE_FALTANTE,
    decreasing = TRUE
  ),
]

print(head(faltantes, 30))

write.csv(
  faltantes,
  "resultados/tablas/control_calidad_faltantes.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("\n")

# ------------------------------------------------------------
# 10. Faltantes segun desenlace
# ------------------------------------------------------------

cat("============================================================\n")
cat("9. FALTANTES SEGUN MUERTE FETAL\n")
cat("============================================================\n\n")

vars_interes <- c(
  "EDAD_NUM",
  "SEGURO",
  "HIPERTENSION_BINARIA",
  "RPM",
  "EMBARAZO_MULTIPLE_BINARIO",
  "CUALQUIER_INFECCION_MATERNA",
  "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
  "EDAD_GESTACIONAL_CATEGORIA"
)

vars_interes <- vars_interes[
  vars_interes %in% names(base)
]

for (v in vars_interes) {

  cat("\nVariable:", v, "\n")

  faltante_variable <- ifelse(
    is.na(base[[v]]),
    "FALTANTE",
    "DISPONIBLE"
  )

  print(
    table(
      MUERTE_FETAL = base$MUERTE_FETAL,
      ESTADO_DATO = faltante_variable,
      useNA = "ifany"
    )
  )
}

cat("\n")

# ------------------------------------------------------------
# 11. No modificar la base congelada
# ------------------------------------------------------------

cat("============================================================\n")
cat("CONTROL DE CALIDAD COMPLETADO\n")
cat("============================================================\n")

cat(
  "\nLa base congelada NO fue modificada.\n"
)

cat(
  "Reporte creado:\n",
  "resultados/tablas/control_calidad_faltantes.csv\n"
)
