rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999, width = 200)

# ============================================================
# 05_tablas_finales_articulo.R
# Cierre reproducible del analisis frecuentista
# - Reutiliza resultados 04_* ya existentes
# - Genera tablas finales publicables, figuras, Excel y trazabilidad
# - NO modifica datos/originales ni datos/congelados
# ============================================================

# -----------------------------
# Rutas
# -----------------------------
ruta_base <- "datos/procesados/base_analitica_frecuentista.csv"
ruta_tablas_04 <- "resultados/tablas"
ruta_modelos_04 <- "resultados/modelos"
ruta_script_04 <- "analisis_frecuentista/04_analisis_completo_asociaciones.R"
ruta_script_05 <- "analisis_frecuentista/05_tablas_finales_articulo.R"

ruta_corrida <- "resultados/corrida_2026-08-10"
ruta_tablas <- file.path(ruta_corrida, "tablas")
ruta_modelos <- file.path(ruta_corrida, "modelos")
ruta_figuras <- file.path(ruta_corrida, "figuras")
ruta_scripts <- file.path(ruta_corrida, "scripts")
ruta_doc <- file.path(ruta_corrida, "documentacion")

dir.create(ruta_corrida, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_tablas, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_modelos, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_figuras, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_scripts, recursive = TRUE, showWarnings = FALSE)
dir.create(ruta_doc, recursive = TRUE, showWarnings = FALSE)

# -----------------------------
# Utilidades de formato
# -----------------------------
fmt_num2 <- function(x) {
  ifelse(is.na(x), NA_character_, formatC(x, format = "f", digits = 2))
}

fmt_or_ic <- function(or, li, ls) {
  ifelse(
    is.na(or) | is.na(li) | is.na(ls),
    NA_character_,
    paste0(fmt_num2(or), " (", fmt_num2(li), "-", fmt_num2(ls), ")")
  )
}

fmt_ic <- function(li, ls) {
  ifelse(
    is.na(li) | is.na(ls),
    NA_character_,
    paste0(fmt_num2(li), "-", fmt_num2(ls))
  )
}

fmt_p <- function(p) {
  out <- rep(NA_character_, length(p))
  out[!is.na(p) & p < 0.001] <- "<0.001"
  out[!is.na(p) & p >= 0.001] <- formatC(p[!is.na(p) & p >= 0.001], format = "f", digits = 3)
  out
}

first_non_na <- function(x) {
  y <- x[!is.na(x)]
  if (length(y) == 0) NA else y[1]
}

safe_read <- function(path) {
  if (!file.exists(path)) stop(paste("No existe:", path))
  read.csv(path, check.names = FALSE, fileEncoding = "UTF-8")
}

stop_if_empty <- function(df, nombre) {
  if (is.null(df) || nrow(df) == 0) stop(paste("Tabla vacia:", nombre))
}

# -----------------------------
# Paquetes opcionales
# -----------------------------
pkg_msgs <- c()

ensure_pkg <- function(pkg) {
  if (requireNamespace(pkg, quietly = TRUE)) return(TRUE)
  ok <- FALSE
  try({
    install.packages(pkg, repos = "https://cloud.r-project.org")
    ok <- requireNamespace(pkg, quietly = TRUE)
  }, silent = TRUE)
  ok
}

tiene_ggplot2 <- ensure_pkg("ggplot2")
if (!tiene_ggplot2) pkg_msgs <- c(pkg_msgs, "No se pudo usar ggplot2; se generaron forest plots con R base.")

tiene_openxlsx <- ensure_pkg("openxlsx")
if (!tiene_openxlsx) pkg_msgs <- c(pkg_msgs, "No se pudo usar openxlsx; se conservaron solo CSV.")

# -----------------------------
# Huella inicial de archivos sensibles
# -----------------------------
archivos_originales <- list.files("datos/originales", recursive = TRUE, full.names = TRUE)
archivos_congelados <- list.files("datos/congelados", recursive = TRUE, full.names = TRUE)

hash_fun <- tools::md5sum
hash_originales_ini <- if (length(archivos_originales) > 0) hash_fun(archivos_originales) else character(0)
hash_congelados_ini <- if (length(archivos_congelados) > 0) hash_fun(archivos_congelados) else character(0)

# -----------------------------
# Validar insumos 04_*
# -----------------------------
insumos_tablas <- c(
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
  "04_diagnostico_modelos.csv"
)

insumos_modelos <- c(
  "04_modelo_A_social_atencion.rds",
  "04_modelo_B_materno_clinico.rds",
  "04_modelo_C_complicaciones_obstetricas.rds",
  "04_modelo_D_seguro_sensibilidad.rds",
  "04_modelo_controles_edad_gestacional.rds"
)

for (f in insumos_tablas) {
  p <- file.path(ruta_tablas_04, f)
  if (!file.exists(p) || file.info(p)$size <= 0) stop(paste("Insumo faltante/vacio:", p))
}

for (f in insumos_modelos) {
  p <- file.path(ruta_modelos_04, f)
  if (!file.exists(p) || file.info(p)$size <= 0) stop(paste("Modelo faltante/vacio:", p))
}

if (!file.exists(ruta_script_04) || file.info(ruta_script_04)$size <= 0) {
  stop("No existe el script 04_analisis_completo_asociaciones.R")
}

# -----------------------------
# Copias de corrida (sin borrar originales)
# -----------------------------
file.copy(ruta_script_04, file.path(ruta_scripts, basename(ruta_script_04)), overwrite = TRUE)

for (f in list.files(ruta_tablas_04, pattern = "^04_", full.names = TRUE)) {
  file.copy(f, file.path(ruta_tablas, basename(f)), overwrite = TRUE)
}

for (f in list.files(ruta_modelos_04, pattern = "^04_", full.names = TRUE)) {
  file.copy(f, file.path(ruta_modelos, basename(f)), overwrite = TRUE)
}

# -----------------------------
# Lectura de insumos
# -----------------------------
or_crudos <- safe_read(file.path(ruta_tablas_04, "04_OR_crudos_categoricos.csv"))
freq <- safe_read(file.path(ruta_tablas_04, "04_frecuencias_por_desenlace.csv"))
fisher <- safe_read(file.path(ruta_tablas_04, "04_fisher_variables_escasas.csv"))
fisher_e <- safe_read(file.path(ruta_tablas_04, "04_eclampsia_fisher_exacto.csv"))
cont <- safe_read(file.path(ruta_tablas_04, "04_OR_crudos_variables_continuas.csv"))
cont_aj <- safe_read(file.path(ruta_tablas_04, "04_controles_ajustados_edad_gestacional.csv"))

modA <- safe_read(file.path(ruta_tablas_04, "04_modelo_A_social_atencion.csv"))
modB <- safe_read(file.path(ruta_tablas_04, "04_modelo_B_materno_clinico.csv"))
modC <- safe_read(file.path(ruta_tablas_04, "04_modelo_C_complicaciones_obstetricas.csv"))
modD <- safe_read(file.path(ruta_tablas_04, "04_modelo_D_seguro_sensibilidad.csv"))

b <- safe_read(ruta_base)
d <- b[!is.na(b$MUERTE_FETAL_BINARIA), ]

# -----------------------------
# Mapeos de etiquetas legibles
# -----------------------------
map_var <- c(
  EDAD_CAT = "Edad materna",
  PAREJA_ESTABLE_A = "Pareja estable",
  INSTRUCCION_A = "Instruccion",
  ACOMPANADA_BIN = "Acompanada",
  ACOMPANADA_DETALLE = "Acompanamiento (detalle)",
  RIESGO_INGRESO_A = "Riesgo al ingreso",
  IVU_A = "Infeccion de vias urinarias (IVU)",
  RPM_A = "Ruptura prematura de membranas (RPM)",
  PSICOPROFILAXIS_ALGUNA = "Psicoprofilaxis (alguna)",
  HEMORRAGIA_A = "Hemorragia",
  VERTICE = "Presentacion de vertice",
  HIPERTENSIVOS_A = "Trastornos hipertensivos",
  DPP = "Desprendimiento prematuro de placenta (DPP)"
)

label_comp_from_coef <- function(coef_name) {
  x <- gsub("^X", "", coef_name)
  x <- trimws(x)
  x
}

label_model_var <- function(v) {
  v <- trimws(v)
  if (v == "EDAD_CAT<20") return("Edad materna <20 vs 20-34")
  if (v == "EDAD_CAT>=35") return("Edad materna >=35 vs 20-34")
  if (v == "PAREJA_ESTABLE_ASI") return("Pareja estable si vs no")
  if (v == "INSTRUCCION_ANINGUNA") return("Sin instruccion vs secundaria")
  if (v == "INSTRUCCION_APRIMARIA") return("Primaria vs secundaria")
  if (v == "INSTRUCCION_ASUPERIOR") return("Superior vs secundaria")
  if (v == "ACOMPANADA_BINSI") return("Acompanada vs sola")
  if (v == "CONTROLES_NUM") return("Numero de controles prenatales, por cada control adicional")
  if (v == "SESIONES_A") return("Numero de sesiones de psicoprofilaxis, por cada sesion adicional")
  if (v == "IVU_ASI") return("IVU si vs no")
  if (v == "HIPERTENSIVOS_APREECLAMPSIA") return("Preeclampsia vs ningun trastorno hipertensivo")
  if (v == "HIPERTENSIVOS_AHTA INDUCIDA POR EL EMBARAZO") return("HTA inducida por embarazo vs ninguno")
  if (v == "HIPERTENSIVOS_AHTA PREEXISTENTE") return("HTA preexistente vs ninguno")
  if (v == "HIPERTENSIVOS_AECLAMPSIA") return("Eclampsia vs ningun trastorno hipertensivo")
  if (v == "RIESGO_INGRESO_ARIESGO ALTO") return("Riesgo alto vs riesgo bajo")
  if (v == "RIESGO_INGRESO_ARIESGO INMINENTE") return("Riesgo inminente vs riesgo bajo")
  if (v == "RPM_ASI") return("RPM si vs no")
  if (v == "DPPSI") return("DPP si vs no")
  if (v == "HEMORRAGIA_ASI") return("Hemorragia si vs no")
  if (v == "VERTICESI") return("Presentacion de vertice vs no vertice")
  if (v == "SEGURO_ASI") return("Seguro si vs no")
  v
}

# -----------------------------
# TABLA 1: frecuencias por desenlace
# -----------------------------
vars_tabla1 <- c(
  "EDAD_CAT", "PAREJA_ESTABLE_A", "INSTRUCCION_A", "ACOMPANADA_BIN",
  "RIESGO_INGRESO_A", "IVU_A", "RPM_A", "PSICOPROFILAXIS_ALGUNA",
  "HEMORRAGIA_A", "VERTICE", "HIPERTENSIVOS_A", "DPP"
)

freq$NO_MUERTE <- as.numeric(freq$NO_MUERTE)
freq$MUERTE <- as.numeric(freq$MUERTE)

tabla1_list <- lapply(vars_tabla1, function(v) {
  x <- freq[freq$VARIABLE == v, c("VARIABLE", "CATEGORIA_ORIGINAL", "NO_MUERTE", "MUERTE")]
  if (nrow(x) == 0) return(NULL)
  t_no <- sum(x$NO_MUERTE, na.rm = TRUE)
  t_si <- sum(x$MUERTE, na.rm = TRUE)
  x$PORC_NO <- ifelse(t_no > 0, 100 * x$NO_MUERTE / t_no, NA)
  x$PORC_SI <- ifelse(t_si > 0, 100 * x$MUERTE / t_si, NA)
  x$MUERTE_FETAL_NO <- paste0(x$NO_MUERTE, " (", fmt_num2(x$PORC_NO), "%)")
  x$MUERTE_FETAL_SI <- paste0(x$MUERTE, " (", fmt_num2(x$PORC_SI), "%)")
  data.frame(
    Variable = map_var[v],
    Categoria = x$CATEGORIA_ORIGINAL,
    MUERTE_FETAL_NO = x$MUERTE_FETAL_NO,
    MUERTE_FETAL_SI = x$MUERTE_FETAL_SI,
    stringsAsFactors = FALSE
  )
})
tabla1 <- do.call(rbind, tabla1_list)
stop_if_empty(tabla1, "TABLA_1_FRECUENCIAS_POR_DESENLACE")
write.csv(tabla1, file.path(ruta_tablas, "TABLA_1_FRECUENCIAS_POR_DESENLACE.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# -----------------------------
# TABLA 2: asociaciones crudas
# -----------------------------
or_crudos$Comparacion <- vapply(or_crudos$CATEGORIA, label_comp_from_coef, character(1))
or_crudos$Variable_legible <- ifelse(
  or_crudos$VARIABLE %in% names(map_var),
  unname(map_var[or_crudos$VARIABLE]),
  or_crudos$VARIABLE
)

fisher_vars <- unique(fisher$VARIABLE)

tabla2 <- data.frame(
  Variable = or_crudos$Variable_legible,
  Comparacion = or_crudos$Comparacion,
  Referencia = or_crudos$REFERENCIA,
  OR_crudo = fmt_num2(or_crudos$OR_CRUDO),
  IC95 = fmt_ic(or_crudos$IC95_INF, or_crudos$IC95_SUP),
  p = fmt_p(or_crudos$P_WALD),
  Metodo = ifelse(or_crudos$VARIABLE %in% fisher_vars, "Fisher", "Logistica"),
  N_analizado = or_crudos$N_ANALIZADO,
  stringsAsFactors = FALSE
)

# Ajustar metodo para variables no escasas con p global disponible
tabla2$Metodo[!(or_crudos$VARIABLE %in% fisher_vars)] <- "Logistica"

stop_if_empty(tabla2, "TABLA_2_ASOCIACIONES_CRUDAS")
write.csv(tabla2, file.path(ruta_tablas, "TABLA_2_ASOCIACIONES_CRUDAS.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# -----------------------------
# Funciones tablas de modelos
# -----------------------------
prep_modelo_tabla <- function(df) {
  x <- df[df$VARIABLE != "(Intercept)", ]
  data.frame(
    Variable = vapply(x$VARIABLE, label_model_var, character(1)),
    aOR = fmt_num2(x$OR_AJUSTADO),
    IC95 = fmt_ic(x$IC95_INF, x$IC95_SUP),
    p = fmt_p(x$P_VALOR),
    N_modelo = x$N_MODELO,
    stringsAsFactors = FALSE
  )
}

# -----------------------------
# TABLAS 3-6
# -----------------------------
tabla3 <- prep_modelo_tabla(modA)
stop_if_empty(tabla3, "TABLA_3_MODELO_A_SOCIAL_ATENCION")
write.csv(tabla3, file.path(ruta_tablas, "TABLA_3_MODELO_A_SOCIAL_ATENCION.csv"), row.names = FALSE, fileEncoding = "UTF-8")

tabla4 <- prep_modelo_tabla(modB)
stop_if_empty(tabla4, "TABLA_4_MODELO_B_MATERNO_CLINICO")
write.csv(tabla4, file.path(ruta_tablas, "TABLA_4_MODELO_B_MATERNO_CLINICO.csv"), row.names = FALSE, fileEncoding = "UTF-8")

tabla5 <- prep_modelo_tabla(modC)
stop_if_empty(tabla5, "TABLA_5_MODELO_C_OBSTETRICO")
write.csv(tabla5, file.path(ruta_tablas, "TABLA_5_MODELO_C_OBSTETRICO.csv"), row.names = FALSE, fileEncoding = "UTF-8")

tabla6 <- prep_modelo_tabla(modD)
tabla6$Nota <- "Analisis de sensibilidad; ~31% de datos faltantes en seguro."
stop_if_empty(tabla6, "TABLA_6_SEGURO_SENSIBILIDAD")
write.csv(tabla6, file.path(ruta_tablas, "TABLA_6_SEGURO_SENSIBILIDAD.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# -----------------------------
# TABLA 7: Fisher exacto
# -----------------------------
f7a <- data.frame(
  Variable_comparacion = c(
    ifelse(fisher$VARIABLE == "IVU_A", "IVU si vs no", fisher$VARIABLE),
    ifelse(fisher$VARIABLE == "HEMORRAGIA_A", "Hemorragia si vs no", fisher$VARIABLE),
    ifelse(fisher$VARIABLE == "DPP", "DPP si vs no", fisher$VARIABLE)
  ),
  OR_exacto = fmt_num2(fisher$OR_FISHER),
  IC95_exacto = fmt_ic(fisher$IC95_INF_EXACTO, fisher$IC95_SUP_EXACTO),
  p_Fisher = fmt_p(fisher$P_FISHER),
  stringsAsFactors = FALSE
)

# Limpieza del armado anterior para evitar duplicidades por vectorizacion
f7a <- data.frame(
  Variable_comparacion = c("IVU si vs no", "Hemorragia si vs no", "DPP si vs no"),
  OR_exacto = fmt_num2(fisher$OR_FISHER[match(c("IVU_A", "HEMORRAGIA_A", "DPP"), fisher$VARIABLE)]),
  IC95_exacto = fmt_ic(
    fisher$IC95_INF_EXACTO[match(c("IVU_A", "HEMORRAGIA_A", "DPP"), fisher$VARIABLE)],
    fisher$IC95_SUP_EXACTO[match(c("IVU_A", "HEMORRAGIA_A", "DPP"), fisher$VARIABLE)]
  ),
  p_Fisher = fmt_p(fisher$P_FISHER[match(c("IVU_A", "HEMORRAGIA_A", "DPP"), fisher$VARIABLE)]),
  stringsAsFactors = FALSE
)

f7b <- data.frame(
  Variable_comparacion = "Eclampsia vs ningun trastorno hipertensivo",
  OR_exacto = fmt_num2(fisher_e$OR_FISHER),
  IC95_exacto = fmt_ic(fisher_e$IC95_INF_EXACTO, fisher_e$IC95_SUP_EXACTO),
  p_Fisher = fmt_p(fisher_e$P_FISHER),
  stringsAsFactors = FALSE
)

tabla7 <- rbind(f7a, f7b)
stop_if_empty(tabla7, "TABLA_7_FISHER_EXACTO")
write.csv(tabla7, file.path(ruta_tablas, "TABLA_7_FISHER_EXACTO.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# -----------------------------
# TABLA 8: controles y psicoprofilaxis
# -----------------------------
cont1 <- cont[1, ]
cont2 <- cont[2, ]
cont_aj_c <- cont_aj[cont_aj$VARIABLE == "CONTROLES_NUM", ]

tabla8 <- data.frame(
  Analisis = c(
    "Numero de controles prenatales, por cada control adicional (crudo)",
    "Numero de sesiones de psicoprofilaxis, por cada sesion adicional (crudo)",
    "Numero de controles prenatales ajustado por edad gestacional"
  ),
  OR_aOR = c(
    fmt_num2(cont1$OR_POR_UNIDAD),
    fmt_num2(cont2$OR_POR_UNIDAD),
    fmt_num2(cont_aj_c$OR_AJUSTADO)
  ),
  IC95 = c(
    fmt_ic(cont1$IC95_INF, cont1$IC95_SUP),
    fmt_ic(cont2$IC95_INF, cont2$IC95_SUP),
    fmt_ic(cont_aj_c$IC95_INF, cont_aj_c$IC95_SUP)
  ),
  p = c(
    fmt_p(cont1$P_VALOR),
    fmt_p(cont2$P_VALOR),
    fmt_p(cont_aj_c$P_VALOR)
  ),
  N = c(
    cont1$N,
    cont2$N,
    cont_aj_c$N
  ),
  stringsAsFactors = FALSE
)
stop_if_empty(tabla8, "TABLA_8_CONTROLES_Y_PSICOPROFILAXIS")
write.csv(tabla8, file.path(ruta_tablas, "TABLA_8_CONTROLES_Y_PSICOPROFILAXIS.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# -----------------------------
# TABLA 9: resumen de hallazgos
# -----------------------------
get_row <- function(df, var) {
  z <- df[df$VARIABLE == var, ]
  if (nrow(z) == 0) return(NULL)
  z[1, ]
}

r_dpp <- get_row(modC, "DPPSI")
r_ecl <- get_row(modC, "HIPERTENSIVOS_AECLAMPSIA")
r_ralto <- get_row(modB, "RIESGO_INGRESO_ARIESGO ALTO")
r_rinm <- get_row(modB, "RIESGO_INGRESO_ARIESGO INMINENTE")
r_ctrl <- get_row(modA, "CONTROLES_NUM")
r_acom <- get_row(modA, "ACOMPANADA_BINSI")
r_ses <- get_row(modA, "SESIONES_A")
r_rpm <- get_row(modC, "RPM_ASI")

armar_hallazgo <- function(dominio, factor, row, modelo, comentario) {
  if (is.null(row)) return(NULL)
  medida <- fmt_or_ic(row$OR_AJUSTADO, row$IC95_INF, row$IC95_SUP)
  dir <- ifelse(row$OR_AJUSTADO > 1, "Positiva", "Negativa")
  data.frame(
    Dominio = dominio,
    Factor = factor,
    Medida = medida,
    IC95 = fmt_ic(row$IC95_INF, row$IC95_SUP),
    p = fmt_p(row$P_VALOR),
    Direccion = dir,
    Modelo = modelo,
    Comentario_metodologico = comentario,
    stringsAsFactors = FALSE
  )
}

tabla9 <- do.call(rbind, list(
  armar_hallazgo(
    "Complicaciones obstetricas",
    "DPP si vs no",
    r_dpp,
    "Modelo C",
    "Asociacion en estudio transversal; no implica causalidad."
  ),
  armar_hallazgo(
    "Trastornos hipertensivos",
    "Eclampsia vs ningun trastorno hipertensivo",
    r_ecl,
    "Modelo C",
    "Frecuencia baja; interpretar junto con IC95 y Fisher exacta."
  ),
  armar_hallazgo(
    "Estado clinico al ingreso",
    "Riesgo alto vs riesgo bajo",
    r_ralto,
    "Modelo B",
    "Marcador clinico de gravedad; no necesariamente exposicion causal."
  ),
  armar_hallazgo(
    "Estado clinico al ingreso",
    "Riesgo inminente vs riesgo bajo",
    r_rinm,
    "Modelo B",
    "Marcador clinico de gravedad; no necesariamente exposicion causal."
  ),
  armar_hallazgo(
    "Atencion prenatal",
    "Numero de controles prenatales, por cada control adicional",
    r_ctrl,
    "Modelo A",
    "Puede reflejar continuidad/acceso a atencion; asociacion no equivale a causalidad."
  ),
  armar_hallazgo(
    "Acompanamiento",
    "Acompanada vs sola",
    r_acom,
    "Modelo A",
    "Asociacion observacional; posible confusion residual."
  ),
  armar_hallazgo(
    "Psicoprofilaxis",
    "Numero de sesiones de psicoprofilaxis, por cada sesion adicional",
    r_ses,
    "Modelo A",
    "Puede reflejar continuidad/acceso a atencion; asociacion no equivale a causalidad."
  ),
  armar_hallazgo(
    "Complicaciones obstetricas",
    "RPM si vs no",
    r_rpm,
    "Modelo C",
    "Asociacion negativa; no interpretar como efecto protector debido a posible temporalidad/causalidad inversa."
  )
))

stop_if_empty(tabla9, "TABLA_9_RESUMEN_HALLAZGOS")
write.csv(tabla9, file.path(ruta_tablas, "TABLA_9_RESUMEN_HALLAZGOS.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# -----------------------------
# Forest plots
# -----------------------------
make_forest_df <- function(df, modelo_txt) {
  x <- df[df$VARIABLE != "(Intercept)", c("VARIABLE", "OR_AJUSTADO", "IC95_INF", "IC95_SUP")]
  x$Etiqueta <- vapply(x$VARIABLE, label_model_var, character(1))
  x$Modelo <- modelo_txt
  x
}

fa <- make_forest_df(modA, "Modelo A")
fb <- make_forest_df(modB, "Modelo B")
fc <- make_forest_df(modC, "Modelo C")

fh <- data.frame(
  Etiqueta = c(
    "DPP si vs no",
    "Eclampsia vs ningun trastorno hipertensivo",
    "Riesgo alto vs riesgo bajo",
    "Riesgo inminente vs riesgo bajo",
    "Controles prenatales (por control adicional)",
    "Acompanada vs sola",
    "Sesiones de psicoprofilaxis (por sesion adicional)",
    "RPM si vs no"
  ),
  OR = c(r_dpp$OR_AJUSTADO, r_ecl$OR_AJUSTADO, r_ralto$OR_AJUSTADO, r_rinm$OR_AJUSTADO,
         r_ctrl$OR_AJUSTADO, r_acom$OR_AJUSTADO, r_ses$OR_AJUSTADO, r_rpm$OR_AJUSTADO),
  LI = c(r_dpp$IC95_INF, r_ecl$IC95_INF, r_ralto$IC95_INF, r_rinm$IC95_INF,
         r_ctrl$IC95_INF, r_acom$IC95_INF, r_ses$IC95_INF, r_rpm$IC95_INF),
  LS = c(r_dpp$IC95_SUP, r_ecl$IC95_SUP, r_ralto$IC95_SUP, r_rinm$IC95_SUP,
         r_ctrl$IC95_SUP, r_acom$IC95_SUP, r_ses$IC95_SUP, r_rpm$IC95_SUP),
  stringsAsFactors = FALSE
)

forest_gg <- function(df, out_png, titulo, col_or = "OR_AJUSTADO", col_li = "IC95_INF", col_ls = "IC95_SUP", col_y = "Etiqueta") {
  gg <- getNamespace("ggplot2")
  dfx <- df
  dfx[[col_y]] <- factor(dfx[[col_y]], levels = rev(dfx[[col_y]]))
  p <- gg$ggplot(dfx, gg$aes(x = .data[[col_or]], y = .data[[col_y]])) +
    gg$geom_vline(xintercept = 1, linetype = "dashed", color = "gray40") +
    gg$geom_errorbarh(gg$aes(xmin = .data[[col_li]], xmax = .data[[col_ls]]), height = 0.20, color = "gray30") +
    gg$geom_point(size = 2.6, color = "#0072B2") +
    gg$scale_x_log10() +
    gg$labs(
      title = titulo,
      x = "Odds ratio (escala logaritmica)",
      y = NULL
    ) +
    gg$theme_minimal(base_size = 11)
  gg$ggsave(out_png, p, width = 9, height = 6, dpi = 300)
}

forest_base <- function(df, out_png, titulo, col_or = "OR_AJUSTADO", col_li = "IC95_INF", col_ls = "IC95_SUP", col_y = "Etiqueta") {
  png(out_png, width = 2800, height = 1900, res = 300)
  par(mar = c(5, 13, 4, 2))
  n <- nrow(df)
  y <- seq_len(n)
  labs <- rev(df[[col_y]])
  or <- rev(df[[col_or]])
  li <- rev(df[[col_li]])
  ls <- rev(df[[col_ls]])
  xlim <- range(c(li, ls), na.rm = TRUE)
  plot(or, y,
       log = "x",
       xlim = xlim,
       ylim = c(0.5, n + 0.5),
       yaxt = "n",
       ylab = "",
       xlab = "Odds ratio (escala logaritmica)",
       pch = 19,
       main = titulo)
  segments(li, y, ls, y, lwd = 2, col = "gray40")
  abline(v = 1, lty = 2, col = "gray40")
  axis(2, at = y, labels = labs, las = 2, cex.axis = 0.8)
  text(or, y, labels = paste0(fmt_num2(or), " (", fmt_num2(li), "-", fmt_num2(ls), ")"), pos = 4, cex = 0.7)
  dev.off()
}

if (tiene_ggplot2) {
  forest_gg(fa, file.path(ruta_figuras, "FOREST_MODELO_A.png"), "Forest plot - Modelo A")
  forest_gg(fb, file.path(ruta_figuras, "FOREST_MODELO_B.png"), "Forest plot - Modelo B")
  forest_gg(fc, file.path(ruta_figuras, "FOREST_MODELO_C.png"), "Forest plot - Modelo C")
  forest_gg(fh, file.path(ruta_figuras, "FOREST_HALLAZGOS_PRINCIPALES.png"), "Forest plot - Hallazgos principales", col_or = "OR", col_li = "LI", col_ls = "LS")
} else {
  forest_base(fa, file.path(ruta_figuras, "FOREST_MODELO_A.png"), "Forest plot - Modelo A")
  forest_base(fb, file.path(ruta_figuras, "FOREST_MODELO_B.png"), "Forest plot - Modelo B")
  forest_base(fc, file.path(ruta_figuras, "FOREST_MODELO_C.png"), "Forest plot - Modelo C")
  forest_base(fh, file.path(ruta_figuras, "FOREST_HALLAZGOS_PRINCIPALES.png"), "Forest plot - Hallazgos principales", col_or = "OR", col_li = "LI", col_ls = "LS")
}

# -----------------------------
# Excel (si openxlsx disponible)
# -----------------------------
excel_path <- file.path(ruta_tablas, "RESULTADOS_FRECUENTISTAS.xlsx")
excel_ok <- FALSE

if (tiene_openxlsx) {
  ox <- getNamespace("openxlsx")
  wb <- ox$createWorkbook()

  tablas <- list(
    Tabla_1 = tabla1,
    Tabla_2 = tabla2,
    Tabla_3 = tabla3,
    Tabla_4 = tabla4,
    Tabla_5 = tabla5,
    Tabla_6 = tabla6,
    Tabla_7 = tabla7,
    Tabla_8 = tabla8,
    Tabla_9 = tabla9
  )

  estilo_header <- ox$createStyle(textDecoration = "bold")

  for (nm in names(tablas)) {
    ox$addWorksheet(wb, nm)
    ox$writeData(wb, nm, tablas[[nm]], withFilter = TRUE)
    ox$addStyle(wb, nm, style = estilo_header, rows = 1, cols = seq_len(ncol(tablas[[nm]])), gridExpand = TRUE)
    ox$setColWidths(wb, nm, cols = seq_len(ncol(tablas[[nm]])), widths = "auto")
    ox$freezePane(wb, nm, firstRow = TRUE)
  }

  try({
    ox$saveWorkbook(wb, excel_path, overwrite = TRUE)
    excel_ok <- file.exists(excel_path) && file.info(excel_path)$size > 0
  }, silent = TRUE)
}

# -----------------------------
# Copiar scripts finales a corrida
# -----------------------------
file.copy(ruta_script_05, file.path(ruta_scripts, basename(ruta_script_05)), overwrite = TRUE)

# -----------------------------
# Documentacion y trazabilidad
# -----------------------------
writeLines(capture.output(sessionInfo()), file.path(ruta_doc, "sessionInfo_R.txt"))

sha <- tools::sha256sum(ruta_base)
sha_line <- paste0(names(sha), "  ", unname(sha))
writeLines(sha_line, file.path(ruta_doc, "SHA256_base_analitica.txt"))

# Manifiesto de archivos de la corrida
files_corrida <- list.files(ruta_corrida, recursive = TRUE, full.names = FALSE)
writeLines(sort(files_corrida), file.path(ruta_doc, "MANIFIESTO_ARCHIVOS.txt"))

# -----------------------------
# Validaciones finales
# -----------------------------
csv_generados <- c(
  "TABLA_1_FRECUENCIAS_POR_DESENLACE.csv",
  "TABLA_2_ASOCIACIONES_CRUDAS.csv",
  "TABLA_3_MODELO_A_SOCIAL_ATENCION.csv",
  "TABLA_4_MODELO_B_MATERNO_CLINICO.csv",
  "TABLA_5_MODELO_C_OBSTETRICO.csv",
  "TABLA_6_SEGURO_SENSIBILIDAD.csv",
  "TABLA_7_FISHER_EXACTO.csv",
  "TABLA_8_CONTROLES_Y_PSICOPROFILAXIS.csv",
  "TABLA_9_RESUMEN_HALLAZGOS.csv"
)

csv_ok <- TRUE
for (f in csv_generados) {
  p <- file.path(ruta_tablas, f)
  if (!file.exists(p) || file.info(p)$size <= 0) csv_ok <- FALSE
  if (file.exists(p)) {
    tmp <- try(read.csv(p, check.names = FALSE), silent = TRUE)
    if (inherits(tmp, "try-error") || nrow(tmp) < 1) csv_ok <- FALSE
  }
}

figs <- c(
  "FOREST_MODELO_A.png",
  "FOREST_MODELO_B.png",
  "FOREST_MODELO_C.png",
  "FOREST_HALLAZGOS_PRINCIPALES.png"
)

fig_ok <- TRUE
for (f in figs) {
  p <- file.path(ruta_figuras, f)
  if (!file.exists(p) || file.info(p)$size <= 0) fig_ok <- FALSE
}

rds_ok <- TRUE
for (f in insumos_modelos) {
  p <- file.path(ruta_modelos_04, f)
  if (!file.exists(p) || file.info(p)$size <= 0) rds_ok <- FALSE
}

hash_originales_fin <- if (length(archivos_originales) > 0) hash_fun(archivos_originales) else character(0)
hash_congelados_fin <- if (length(archivos_congelados) > 0) hash_fun(archivos_congelados) else character(0)

orig_mod <- !identical(hash_originales_ini, hash_originales_fin)
cong_mod <- !identical(hash_congelados_ini, hash_congelados_fin)

doc_files <- c(
  "sessionInfo_R.txt",
  "SHA256_base_analitica.txt",
  "MANIFIESTO_ARCHIVOS.txt"
)
doc_ok <- all(file.exists(file.path(ruta_doc, doc_files)))

resumen_path <- file.path(ruta_doc, "RESUMEN_EJECUCION.txt")

modelos_txt <- c(
  "Modelo A (social y atencion prenatal)",
  "Modelo B (materno-clinico al ingreso)",
  "Modelo C (complicaciones obstetricas)",
  "Modelo D (sensibilidad para seguro)",
  "Controles ajustado por edad gestacional"
)

warn_metodo <- c(
  "Estudio transversal analitico: no inferir causalidad.",
  "OR es medida de asociacion; no interpretar OR<1 automaticamente como efecto protector.",
  "Riesgo al ingreso puede actuar como marcador de gravedad.",
  "SEGURO analizado por separado debido a faltantes (~31%).",
  "Embarazo multiple no se uso para estimar OR por desenlace faltante en ese subgrupo.",
  "APGAR no se incluyo como predictor etiologico."
)

errores_txt <- if (length(pkg_msgs) == 0) "Sin errores criticos reportados." else paste(pkg_msgs, collapse = " | ")

lineas_resumen <- c(
  paste("Fecha de corrida:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste("Base utilizada:", ruta_base),
  paste("Numero total de registros:", nrow(b)),
  paste("Numero con desenlace conocido:", nrow(d)),
  paste("Numero de muertes fetales:", sum(d$MUERTE_FETAL_BINARIA == 1, na.rm = TRUE)),
  "Modelos ejecutados:",
  paste("-", modelos_txt),
  "Archivos generados:",
  paste("-", sort(list.files(ruta_corrida, recursive = TRUE, full.names = FALSE))),
  "Advertencias metodologicas:",
  paste("-", warn_metodo),
  paste("Errores/paquetes no disponibles:", errores_txt)
)

writeLines(lineas_resumen, resumen_path)
doc_ok <- doc_ok && file.exists(resumen_path) && file.info(resumen_path)$size > 0

# Actualizar manifiesto para incluir archivos creados al final
files_corrida2 <- list.files(ruta_corrida, recursive = TRUE, full.names = FALSE)
writeLines(sort(files_corrida2), file.path(ruta_doc, "MANIFIESTO_ARCHIVOS.txt"))

# -----------------------------
# Resumen final en consola
# -----------------------------
cat("========================================\n")
cat("CIERRE DEL ANALISIS FRECUENTISTA\n")
cat("========================================\n")
cat("Base analitica:", ifelse(file.exists(ruta_base) && file.info(ruta_base)$size > 0, "OK", "NO"), "\n")
cat("Tablas CSV:", ifelse(csv_ok, "OK", "NO DISPONIBLE"), "\n")
cat("Excel:", ifelse(excel_ok, "OK", "NO DISPONIBLE"), "\n")
cat("Forest plots:", ifelse(fig_ok, "OK", "NO DISPONIBLE"), "\n")
cat("Modelos RDS:", ifelse(rds_ok, "OK", "NO"), "\n")
cat("Documentacion:", ifelse(doc_ok, "OK", "NO"), "\n")
cat("Originales modificados:", ifelse(orig_mod, "SI", "NO"), "\n")
cat("Base congelada modificada:", ifelse(cong_mod, "SI", "NO"), "\n\n")
cat("Carpeta final:\n")
cat(ruta_corrida, "\n\n")
cat("Rutas generadas:\n")
cat(paste0("- ", sort(files_corrida2)), sep = "\n")
cat("\n")

# Falla explicita si se detecta modificacion de carpetas protegidas
if (orig_mod || cong_mod) {
  stop("Se detectaron cambios en datos/originales o datos/congelados.")
}
