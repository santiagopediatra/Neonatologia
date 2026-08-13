# ============================================================
# 04_analisis_completo_asociaciones.R
# Analisis frecuentista completo de factores asociados
# a muerte fetal
#
# Diseño: transversal analitico
# Medida principal: Odds Ratio (OR) con IC95%
#
# IMPORTANTE:
# - No modifica la base congelada.
# - No interpreta OR como riesgo ni causalidad.
# - Variables posteriores/clinicas se modelan separadamente.
# ============================================================

rm(list = ls())

options(
  stringsAsFactors = FALSE,
  scipen = 999,
  width = 180
)

# ============================================================
# 0. RUTAS
# ============================================================

ruta_base <- "datos/procesados/base_analitica_frecuentista.csv"
ruta_tablas <- "resultados/tablas"
ruta_modelos <- "resultados/modelos"

dir.create(ruta_tablas, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_modelos, recursive = TRUE, showWarnings = FALSE)

archivo_log <- file.path(
  ruta_tablas,
  "04_analisis_completo_asociaciones_log.txt"
)

sink(archivo_log, split = TRUE)

cat("\n============================================================\n")
cat("ANALISIS FRECUENTISTA COMPLETO DE ASOCIACIONES\n")
cat("============================================================\n\n")

# ============================================================
# 1. CARGA
# ============================================================

b <- read.csv(
  ruta_base,
  check.names = FALSE,
  fileEncoding = "UTF-8",
  na.strings = c("", "NA", "N/A", "NULL")
)

# Solo desenlace conocido
d <- b[
  !is.na(b$MUERTE_FETAL_BINARIA),
]

cat("Base original analitica:", nrow(b), "registros\n")
cat("Desenlace conocido:", nrow(d), "registros\n")
cat("Muerte fetal SI:",
    sum(d$MUERTE_FETAL_BINARIA == 1), "\n")
cat("Muerte fetal NO:",
    sum(d$MUERTE_FETAL_BINARIA == 0), "\n\n")

# ============================================================
# 2. RECODIFICACIONES ANALITICAS
# ============================================================

# ------------------------------------------------------------
# Edad materna
# ------------------------------------------------------------

d$EDAD_CAT <- factor(
  d$EDAD_CATEGORIA_ANALITICA,
  levels = c("20-34", "<20", ">=35")
)

# ------------------------------------------------------------
# Pareja estable
# ------------------------------------------------------------

d$PAREJA_ESTABLE_A <- factor(
  d$PAREJA_ESTABLE,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# Seguro
# ------------------------------------------------------------

d$SEGURO_A <- factor(
  d$SEGURO,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# Instruccion
# ------------------------------------------------------------

d$INSTRUCCION_A <- factor(d$INSTRUCCION)

if ("SECUNDARIA" %in% levels(d$INSTRUCCION_A)) {
  d$INSTRUCCION_A <- relevel(
    d$INSTRUCCION_A,
    ref = "SECUNDARIA"
  )
}

# ------------------------------------------------------------
# Acompañamiento
#
# "0" se considera dato no interpretable.
# SOLA = NO
# PAREJA/FAMILIAR/OTRO = SI
# ------------------------------------------------------------

d$ACOMPANADA_BIN <- NA_character_

d$ACOMPANADA_BIN[
  d$ACOMPANADA == "SOLA"
] <- "NO"

d$ACOMPANADA_BIN[
  d$ACOMPANADA %in% c(
    "PAREJA",
    "FAMILIAR",
    "OTRO"
  )
] <- "SI"

d$ACOMPANADA_BIN <- factor(
  d$ACOMPANADA_BIN,
  levels = c("NO", "SI")
)

# Variable detallada, pero "0" pasa a NA
d$ACOMPANADA_DETALLE <- as.character(d$ACOMPANADA)

d$ACOMPANADA_DETALLE[
  d$ACOMPANADA_DETALLE == "0"
] <- NA

d$ACOMPANADA_DETALLE <- factor(
  d$ACOMPANADA_DETALLE
)

if ("PAREJA" %in% levels(d$ACOMPANADA_DETALLE)) {
  d$ACOMPANADA_DETALLE <- relevel(
    d$ACOMPANADA_DETALLE,
    ref = "PAREJA"
  )
}

# ------------------------------------------------------------
# Riesgo al ingreso
# ------------------------------------------------------------

d$RIESGO_INGRESO_A <- factor(
  d$RIESGO_AL_INGRESO
)

if ("RIESGO BAJO" %in% levels(d$RIESGO_INGRESO_A)) {
  d$RIESGO_INGRESO_A <- relevel(
    d$RIESGO_INGRESO_A,
    ref = "RIESGO BAJO"
  )
}

# ------------------------------------------------------------
# Controles prenatales
# ------------------------------------------------------------

d$CONTROLES_NUM <- suppressWarnings(
  as.numeric(d$NO_CONTROLES_NUM)
)

# respaldo si NO_CONTROLES_NUM estuviera vacío
if (sum(!is.na(d$CONTROLES_NUM)) == 0) {
  d$CONTROLES_NUM <- suppressWarnings(
    as.numeric(d$NO_CONTROLES)
  )
}

# No inventamos un corte de adecuado/inadecuado.
# Se mantiene como continuo.
d$CONTROLES_NUM[
  d$CONTROLES_NUM < 0
] <- NA

# ------------------------------------------------------------
# IVU
# ------------------------------------------------------------

d$IVU_A <- factor(
  d$IVU,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# RPM
# ------------------------------------------------------------

d$RPM_A <- factor(
  d$RPM,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# Psicoprofilaxis / sesiones
# ------------------------------------------------------------

d$SESIONES_A <- suppressWarnings(
  as.numeric(d$SESIONES_NUM)
)

if (sum(!is.na(d$SESIONES_A)) == 0) {
  d$SESIONES_A <- suppressWarnings(
    as.numeric(d$SESIONES)
  )
}

d$SESIONES_A[
  d$SESIONES_A < 0
] <- NA

d$PSICOPROFILAXIS_ALGUNA <- ifelse(
  is.na(d$SESIONES_A),
  NA,
  ifelse(
    d$SESIONES_A > 0,
    "SI",
    "NO"
  )
)

d$PSICOPROFILAXIS_ALGUNA <- factor(
  d$PSICOPROFILAXIS_ALGUNA,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# Hemorragia
# ------------------------------------------------------------

d$HEMORRAGIA_A <- factor(
  d$HEMORRAGIA,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# Presentacion fetal: vertice vs no vertice
# ------------------------------------------------------------

d$VERTICE <- ifelse(
  is.na(d$PRESENTACION_FETAL),
  NA,
  ifelse(
    toupper(trimws(d$PRESENTACION_FETAL)) %in%
      c("VÉRTICE", "VERTICE"),
    "SI",
    "NO"
  )
)

d$VERTICE <- factor(
  d$VERTICE,
  levels = c("NO", "SI")
)

# ------------------------------------------------------------
# Trastornos hipertensivos
# ------------------------------------------------------------

d$HIPERTENSIVOS_A <- factor(
  d$HIPERTENSIVOS,
  levels = c(
    "NINGUNO",
    "PREECLAMPSIA",
    "HTA INDUCIDA POR EL EMBARAZO",
    "HTA PREEXISTENTE",
    "ECLAMPSIA"
  )
)

# ------------------------------------------------------------
# DPP
# ------------------------------------------------------------

d$DPP <- factor(
  d$DESPRENDIMIENTO_PREMATURO_DE_PLACENTA,
  levels = c("NO", "SI")
)

# ============================================================
# 3. TABLA DE FRECUENCIAS Y FALTANTES
# ============================================================

variables_resumen <- c(
  "EDAD_CAT",
  "PAREJA_ESTABLE_A",
  "SEGURO_A",
  "INSTRUCCION_A",
  "ACOMPANADA_BIN",
  "ACOMPANADA_DETALLE",
  "RIESGO_INGRESO_A",
  "CONTROLES_NUM",
  "IVU_A",
  "RPM_A",
  "SESIONES_A",
  "PSICOPROFILAXIS_ALGUNA",
  "HEMORRAGIA_A",
  "VERTICE",
  "HIPERTENSIVOS_A",
  "DPP"
)

resumen_faltantes <- data.frame(
  VARIABLE = variables_resumen,
  N_VALIDO = sapply(
    variables_resumen,
    function(v) sum(!is.na(d[[v]]))
  ),
  N_FALTANTE = sapply(
    variables_resumen,
    function(v) sum(is.na(d[[v]]))
  ),
  PCT_FALTANTE = sapply(
    variables_resumen,
    function(v) round(mean(is.na(d[[v]])) * 100, 2)
  ),
  row.names = NULL
)

write.csv(
  resumen_faltantes,
  file.path(ruta_tablas, "04_faltantes_variables_modeladas.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("============================================================\n")
cat("FALTANTES DE VARIABLES ANALIZADAS\n")
cat("============================================================\n")
print(resumen_faltantes, row.names = FALSE)

# ============================================================
# 4. FUNCION: TABLA CATEGORICA + OR CRUDO
# ============================================================

analizar_factor <- function(data, variable) {

  dd <- data[
    !is.na(data[[variable]]) &
      !is.na(data$MUERTE_FETAL_BINARIA),
    c(variable, "MUERTE_FETAL_BINARIA")
  ]

  names(dd)[1] <- "X"

  dd$X <- droplevels(factor(dd$X))

  if (nlevels(dd$X) < 2) {
    return(NULL)
  }

  tab <- table(
    EXPOSICION = dd$X,
    MUERTE_FETAL = dd$MUERTE_FETAL_BINARIA
  )

  modelo <- glm(
    MUERTE_FETAL_BINARIA ~ X,
    data = dd,
    family = binomial()
  )

  cf <- summary(modelo)$coefficients
  ci <- confint.default(modelo)

  rr <- data.frame(
    VARIABLE = variable,
    REFERENCIA = levels(dd$X)[1],
    CATEGORIA = rownames(cf),
    OR_CRUDO = exp(coef(modelo)),
    IC95_INF = exp(ci[, 1]),
    IC95_SUP = exp(ci[, 2]),
    P_WALD = cf[, 4],
    N_ANALIZADO = nrow(dd),
    stringsAsFactors = FALSE,
    row.names = NULL
  )

  rr <- rr[
    rr$CATEGORIA != "(Intercept)",
  ]

  # Prueba global de razon de verosimilitudes
  modelo0 <- glm(
    MUERTE_FETAL_BINARIA ~ 1,
    data = dd,
    family = binomial()
  )

  lrt <- anova(
    modelo0,
    modelo,
    test = "LRT"
  )

  p_global <- lrt$`Pr(>Chi)`[2]

  rr$P_GLOBAL <- p_global

  # Datos por categoria
  conteos <- data.frame(
    VARIABLE = variable,
    CATEGORIA_ORIGINAL = rownames(tab),
    NO_MUERTE = as.numeric(tab[, "0"]),
    MUERTE = as.numeric(tab[, "1"]),
    TOTAL = rowSums(tab),
    row.names = NULL
  )

  list(
    resultado = rr,
    conteos = conteos,
    tabla = tab
  )
}

# ============================================================
# 5. ANALISIS BIVARIADO CATEGORICO
# ============================================================

factores_bivariados <- c(
  "PAREJA_ESTABLE_A",
  "SEGURO_A",
  "INSTRUCCION_A",
  "ACOMPANADA_BIN",
  "ACOMPANADA_DETALLE",
  "RIESGO_INGRESO_A",
  "IVU_A",
  "RPM_A",
  "PSICOPROFILAXIS_ALGUNA",
  "HEMORRAGIA_A",
  "VERTICE",
  "HIPERTENSIVOS_A",
  "DPP"
)

resultados_biv <- list()
conteos_biv <- list()

for (v in factores_bivariados) {

  obj <- analizar_factor(d, v)

  if (!is.null(obj)) {

    resultados_biv[[v]] <- obj$resultado
    conteos_biv[[v]] <- obj$conteos

    cat("\n------------------------------------------------------------\n")
    cat("VARIABLE:", v, "\n")
    cat("------------------------------------------------------------\n")
    print(obj$tabla)
    print(obj$resultado, row.names = FALSE)
  }
}

tabla_bivariada <- do.call(
  rbind,
  resultados_biv
)

rownames(tabla_bivariada) <- NULL

tabla_conteos <- do.call(
  rbind,
  conteos_biv
)

rownames(tabla_conteos) <- NULL

write.csv(
  tabla_bivariada,
  file.path(ruta_tablas, "04_OR_crudos_categoricos.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  tabla_conteos,
  file.path(ruta_tablas, "04_frecuencias_por_desenlace.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ============================================================
# 6. FISHER PARA EXPOSICIONES BINARIAS ESCASAS
# ============================================================

factores_fisher <- c(
  "IVU_A",
  "HEMORRAGIA_A",
  "DPP"
)

res_fisher <- list()

for (v in factores_fisher) {

  dd <- d[
    !is.na(d[[v]]) &
      !is.na(d$MUERTE_FETAL_BINARIA),
  ]

  tt <- table(
    dd[[v]],
    dd$MUERTE_FETAL_BINARIA
  )

  if (all(dim(tt) == c(2, 2))) {

    ft <- fisher.test(tt)

    res_fisher[[v]] <- data.frame(
      VARIABLE = v,
      OR_FISHER = unname(ft$estimate),
      IC95_INF_EXACTO = ft$conf.int[1],
      IC95_SUP_EXACTO = ft$conf.int[2],
      P_FISHER = ft$p.value,
      row.names = NULL
    )
  }
}

tabla_fisher <- do.call(
  rbind,
  res_fisher
)

write.csv(
  tabla_fisher,
  file.path(ruta_tablas, "04_fisher_variables_escasas.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Eclampsia vs ninguno - Fisher exacto
ee <- d[
  d$HIPERTENSIVOS_A %in%
    c("NINGUNO", "ECLAMPSIA") &
    !is.na(d$HIPERTENSIVOS_A),
]

ee$HIPERTENSIVOS_A <- droplevels(
  ee$HIPERTENSIVOS_A
)

tt_eclampsia <- table(
  ee$HIPERTENSIVOS_A,
  ee$MUERTE_FETAL_BINARIA
)

f_eclampsia <- fisher.test(tt_eclampsia)

resultado_eclampsia_fisher <- data.frame(
  COMPARACION = "ECLAMPSIA vs NINGUNO",
  OR_FISHER = unname(f_eclampsia$estimate),
  IC95_INF_EXACTO = f_eclampsia$conf.int[1],
  IC95_SUP_EXACTO = f_eclampsia$conf.int[2],
  P_FISHER = f_eclampsia$p.value
)

write.csv(
  resultado_eclampsia_fisher,
  file.path(ruta_tablas, "04_eclampsia_fisher_exacto.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ============================================================
# 7. VARIABLES CONTINUAS
# ============================================================

analizar_continua <- function(data, variable, etiqueta) {

  dd <- data[
    !is.na(data[[variable]]) &
      !is.na(data$MUERTE_FETAL_BINARIA),
  ]

  modelo <- glm(
    as.formula(
      paste(
        "MUERTE_FETAL_BINARIA ~",
        variable
      )
    ),
    data = dd,
    family = binomial()
  )

  cf <- summary(modelo)$coefficients
  ci <- confint.default(modelo)

  data.frame(
    VARIABLE = etiqueta,
    N = nrow(dd),
    OR_POR_UNIDAD = exp(coef(modelo)[2]),
    IC95_INF = exp(ci[2, 1]),
    IC95_SUP = exp(ci[2, 2]),
    P_VALOR = cf[2, 4],
    row.names = NULL
  )
}

continuas <- rbind(
  analizar_continua(
    d,
    "CONTROLES_NUM",
    "Numero de controles prenatales: OR por control adicional"
  ),
  analizar_continua(
    d,
    "SESIONES_A",
    "Psicoprofilaxis: OR por sesion adicional"
  )
)

write.csv(
  continuas,
  file.path(ruta_tablas, "04_OR_crudos_variables_continuas.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("\n============================================================\n")
cat("VARIABLES CONTINUAS\n")
cat("============================================================\n")
print(continuas, row.names = FALSE)

# ============================================================
# 8. CONTROLES PRENATALES AJUSTADOS POR EDAD GESTACIONAL
# ============================================================

dc <- d[
  !is.na(d$CONTROLES_NUM) &
  !is.na(d$EDAD_GESTACIONAL_ANALITICA),
]

m_controles_eg <- glm(
  MUERTE_FETAL_BINARIA ~
    CONTROLES_NUM +
    EDAD_GESTACIONAL_ANALITICA,
  data = dc,
  family = binomial()
)

cf <- summary(m_controles_eg)$coefficients
ci <- confint.default(m_controles_eg)

resultado_controles_eg <- data.frame(
  VARIABLE = rownames(cf),
  OR_AJUSTADO = exp(coef(m_controles_eg)),
  IC95_INF = exp(ci[, 1]),
  IC95_SUP = exp(ci[, 2]),
  P_VALOR = cf[, 4],
  N = nobs(m_controles_eg),
  row.names = NULL
)

write.csv(
  resultado_controles_eg,
  file.path(
    ruta_tablas,
    "04_controles_ajustados_edad_gestacional.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

saveRDS(
  m_controles_eg,
  file.path(
    ruta_modelos,
    "04_modelo_controles_edad_gestacional.rds"
  )
)

# ============================================================
# 9. MODELO A:
# FACTORES SOCIALES Y DE ATENCION PRENATAL
#
# No incluye seguro por 31% faltante.
# No incluye riesgo al ingreso por ser marcador de gravedad.
# No incluye RPM/DPP por ser complicaciones obstetricas.
# ============================================================

modelo_A <- glm(
  MUERTE_FETAL_BINARIA ~
    EDAD_CAT +
    PAREJA_ESTABLE_A +
    INSTRUCCION_A +
    ACOMPANADA_BIN +
    CONTROLES_NUM +
    SESIONES_A +
    IVU_A,
  data = d,
  family = binomial()
)

extraer_modelo <- function(modelo, nombre_modelo) {

  cf <- summary(modelo)$coefficients
  ci <- confint.default(modelo)

  data.frame(
    MODELO = nombre_modelo,
    VARIABLE = rownames(cf),
    OR_AJUSTADO = exp(coef(modelo)),
    IC95_INF = exp(ci[, 1]),
    IC95_SUP = exp(ci[, 2]),
    P_VALOR = cf[, 4],
    N_MODELO = nobs(modelo),
    AIC = AIC(modelo),
    row.names = NULL
  )
}

res_A <- extraer_modelo(
  modelo_A,
  "A_SOCIAL_ATENCION_PRENATAL"
)

write.csv(
  res_A,
  file.path(
    ruta_tablas,
    "04_modelo_A_social_atencion.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

saveRDS(
  modelo_A,
  file.path(
    ruta_modelos,
    "04_modelo_A_social_atencion.rds"
  )
)

# ============================================================
# 10. MODELO B:
# FACTORES MATERNOS / CLINICOS AL INGRESO
#
# Riesgo al ingreso se interpreta como marcador clinico
# de gravedad, no necesariamente como causa.
# ============================================================

modelo_B <- glm(
  MUERTE_FETAL_BINARIA ~
    EDAD_CAT +
    HIPERTENSIVOS_A +
    IVU_A +
    RIESGO_INGRESO_A +
    CONTROLES_NUM,
  data = d,
  family = binomial()
)

res_B <- extraer_modelo(
  modelo_B,
  "B_MATERNO_CLINICO_INGRESO"
)

write.csv(
  res_B,
  file.path(
    ruta_tablas,
    "04_modelo_B_materno_clinico.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

saveRDS(
  modelo_B,
  file.path(
    ruta_modelos,
    "04_modelo_B_materno_clinico.rds"
  )
)

# ============================================================
# 11. MODELO C:
# COMPLICACIONES OBSTETRICAS
#
# Modelo asociativo, NO causal.
# No se usa para afirmar proteccion o causalidad.
# ============================================================

modelo_C <- glm(
  MUERTE_FETAL_BINARIA ~
    EDAD_CAT +
    HIPERTENSIVOS_A +
    RPM_A +
    DPP +
    HEMORRAGIA_A +
    VERTICE,
  data = d,
  family = binomial()
)

res_C <- extraer_modelo(
  modelo_C,
  "C_COMPLICACIONES_OBSTETRICAS"
)

write.csv(
  res_C,
  file.path(
    ruta_tablas,
    "04_modelo_C_complicaciones_obstetricas.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

saveRDS(
  modelo_C,
  file.path(
    ruta_modelos,
    "04_modelo_C_complicaciones_obstetricas.rds"
  )
)

# ============================================================
# 12. MODELO D:
# SENSIBILIDAD PARA SEGURO
#
# Se hace por separado por ~31% de faltantes.
# ============================================================

modelo_D <- glm(
  MUERTE_FETAL_BINARIA ~
    EDAD_CAT +
    SEGURO_A +
    INSTRUCCION_A +
    PAREJA_ESTABLE_A,
  data = d,
  family = binomial()
)

res_D <- extraer_modelo(
  modelo_D,
  "D_SENSIBILIDAD_SEGURO"
)

write.csv(
  res_D,
  file.path(
    ruta_tablas,
    "04_modelo_D_seguro_sensibilidad.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

saveRDS(
  modelo_D,
  file.path(
    ruta_modelos,
    "04_modelo_D_seguro_sensibilidad.rds"
  )
)

# ============================================================
# 13. DIAGNOSTICO DE EVENTOS POR PARAMETRO
# ============================================================

eventos_modelo <- function(modelo, nombre) {

  mf <- model.frame(modelo)

  n <- nrow(mf)
  eventos <- sum(mf[[1]] == 1)
  parametros <- length(coef(modelo)) - 1

  data.frame(
    MODELO = nombre,
    N = n,
    EVENTOS = eventos,
    PARAMETROS_SIN_INTERCEPTO = parametros,
    EVENTOS_POR_PARAMETRO =
      ifelse(
        parametros > 0,
        eventos / parametros,
        NA
      )
  )
}

diagnostico_modelos <- rbind(
  eventos_modelo(modelo_A, "A_SOCIAL_ATENCION"),
  eventos_modelo(modelo_B, "B_MATERNO_CLINICO"),
  eventos_modelo(modelo_C, "C_OBSTETRICO"),
  eventos_modelo(modelo_D, "D_SEGURO")
)

write.csv(
  diagnostico_modelos,
  file.path(
    ruta_tablas,
    "04_diagnostico_modelos.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ============================================================
# 14. RESULTADOS EN CONSOLA
# ============================================================

cat("\n\n============================================================\n")
cat("MODELO A - SOCIAL / ATENCION PRENATAL\n")
cat("============================================================\n")
print(res_A, row.names = FALSE)

cat("\n============================================================\n")
cat("MODELO B - MATERNO / CLINICO AL INGRESO\n")
cat("============================================================\n")
print(res_B, row.names = FALSE)

cat("\n============================================================\n")
cat("MODELO C - COMPLICACIONES OBSTETRICAS\n")
cat("============================================================\n")
print(res_C, row.names = FALSE)

cat("\n============================================================\n")
cat("MODELO D - SEGURO, ANALISIS DE SENSIBILIDAD\n")
cat("============================================================\n")
print(res_D, row.names = FALSE)

cat("\n============================================================\n")
cat("FISHER - VARIABLES ESCASAS\n")
cat("============================================================\n")
print(tabla_fisher, row.names = FALSE)

cat("\nECLAMPSIA - FISHER EXACTO\n")
print(resultado_eclampsia_fisher, row.names = FALSE)

cat("\n============================================================\n")
cat("DIAGNOSTICO DE MODELOS\n")
cat("============================================================\n")
print(diagnostico_modelos, row.names = FALSE)

# ============================================================
# 15. MANIFIESTO DE ARCHIVOS
# ============================================================

archivos_generados <- c(
  "04_faltantes_variables_modeladas.csv",
  "04_OR_crudos_categoricos.csv",
  "04_frecuencias_por_desenlace.csv",
  "04_fisher_variables_escasas.csv",
  "04_eclampsia_fisher_exacto.csv",
  "04_OR_crudos_variables_continuas.csv",
  "04_controles_ajustados_edad_gestacional.csv",
  "04_modelo_A_social_atencion.csv",
  "04_modelo_B_materno_clinico.csv",
  "04_modelo_C_complicaciones_obstetricas.csv",
  "04_modelo_D_seguro_sensibilidad.csv",
  "04_diagnostico_modelos.csv",
  "04_analisis_completo_asociaciones_log.txt"
)

writeLines(
  archivos_generados,
  file.path(
    ruta_tablas,
    "04_MANIFIESTO_RESULTADOS.txt"
  )
)

cat("\n============================================================\n")
cat("ANALISIS TERMINADO CORRECTAMENTE\n")
cat("============================================================\n")

cat("\nResultados guardados en:\n")
cat("  resultados/tablas/\n")
cat("  resultados/modelos/\n")

cat("\nNO se modifico la base congelada.\n")

sink()
