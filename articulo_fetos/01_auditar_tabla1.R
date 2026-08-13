#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(tidyverse))

ruta_base <- "datos/procesados/base_analitica_frecuentista.csv"
ruta_word <- "manuscrito/Articulo_fetos.docx"

if (!file.exists(ruta_base)) stop("No existe la base analítica: ", ruta_base)
if (!file.exists(ruta_word)) stop("No existe el Word confirmado: ", ruta_word)

datos <- read.csv(
  ruta_base,
  check.names = FALSE,
  fileEncoding = "UTF-8",
  na.strings = c("", "NA", "N/A", "NULL")
)

cat("nrow(datos):", nrow(datos), "\n")
cat("Desenlace válido:", sum(!is.na(datos$MUERTE_FETAL_BINARIA)), "\n")
print(table(datos$MUERTE_FETAL_BINARIA, useNA = "always"))

if (sum(!is.na(datos$MUERTE_FETAL_BINARIA)) != 23642) {
  stop("La población con desenlace válido no es 23.642; auditoría detenida.")
}

datos_tabla1 <- datos |>
  filter(!is.na(MUERTE_FETAL_BINARIA)) |>
  mutate(
    PAREJA_ESTABLE_A = factor(PAREJA_ESTABLE, levels = c("NO", "SI")),
    INSTRUCCION_A = factor(INSTRUCCION, levels = c("SECUNDARIA", "NINGUNA", "PRIMARIA", "SUPERIOR")),
    ACOMPANADA_BIN = factor(case_when(
      ACOMPANADA == "SOLA" ~ "NO",
      ACOMPANADA %in% c("PAREJA", "FAMILIAR", "OTRO") ~ "SI",
      TRUE ~ NA_character_
    ), levels = c("NO", "SI")),
    RIESGO_INGRESO_A = factor(RIESGO_AL_INGRESO, levels = c("RIESGO BAJO", "RIESGO ALTO", "RIESGO INMINENTE")),
    IVU_A = factor(IVU, levels = c("NO", "SI")),
    RPM_A = factor(RPM, levels = c("NO", "SI")),
    SESIONES_A = suppressWarnings(as.numeric(SESIONES_NUM)),
    SESIONES_A = if_else(SESIONES_A < 0, NA_real_, SESIONES_A),
    PSICOPROFILAXIS_ALGUNA = factor(case_when(
      is.na(SESIONES_A) ~ NA_character_,
      SESIONES_A > 0 ~ "SI",
      TRUE ~ "NO"
    ), levels = c("NO", "SI")),
    HEMORRAGIA_A = factor(HEMORRAGIA, levels = c("NO", "SI")),
    VERTICE = factor(case_when(
      is.na(PRESENTACION_FETAL) ~ NA_character_,
      toupper(trimws(PRESENTACION_FETAL)) %in% c("VÉRTICE", "VERTICE") ~ "SI",
      TRUE ~ "NO"
    ), levels = c("NO", "SI")),
    HIPERTENSIVOS_A = factor(HIPERTENSIVOS, levels = c(
      "NINGUNO", "PREECLAMPSIA", "HTA INDUCIDA POR EL EMBARAZO",
      "HTA PREEXISTENTE", "ECLAMPSIA"
    )),
    DPP = factor(DESPRENDIMIENTO_PREMATURO_DE_PLACENTA, levels = c("NO", "SI"))
  )

if (nrow(datos_tabla1) != 23642) stop("datos_tabla1 no contiene 23.642 registros.")

mapa <- tribble(
  ~variable, ~etiqueta,
  "PAREJA_ESTABLE_A", "Pareja estable",
  "INSTRUCCION_A", "Instruccion",
  "ACOMPANADA_BIN", "Acompanada",
  "RIESGO_INGRESO_A", "Riesgo al ingreso",
  "IVU_A", "Infeccion de vias urinarias (IVU)",
  "RPM_A", "Ruptura prematura de membranas (RPM)",
  "PSICOPROFILAXIS_ALGUNA", "Psicoprofilaxis (alguna)",
  "HEMORRAGIA_A", "Hemorragia",
  "VERTICE", "Presentacion de vertice",
  "HIPERTENSIVOS_A", "Trastornos hipertensivos",
  "DPP", "Desprendimiento prematuro de placenta (DPP)"
)

auditar_variable <- function(variable, etiqueta, orden_variable) {
  variable_codigo <- variable
  niveles <- levels(datos_tabla1[[variable_codigo]])
  expand_grid(
    categoria = niveles,
    desenlace = c("NO", "SI")
  ) |>
    mutate(
      variable = variable_codigo,
      etiqueta = etiqueta,
      orden_variable = orden_variable,
      orden_categoria = match(categoria, niveles),
      valor_desenlace = if_else(desenlace == "NO", 0, 1),
      n = map2_int(categoria, valor_desenlace, ~sum(
        datos_tabla1$MUERTE_FETAL_BINARIA == .y & datos_tabla1[[variable_codigo]] == .x,
        na.rm = TRUE
      )),
      denominador = map_int(valor_desenlace, ~sum(
        datos_tabla1$MUERTE_FETAL_BINARIA == .x & !is.na(datos_tabla1[[variable_codigo]]),
        na.rm = TRUE
      )),
      porcentaje_calculado = 100 * n / denominador
    ) |>
    group_by(variable, desenlace) |>
    mutate(
      suma_columna = sum(porcentaje_calculado),
      validacion_100 = abs(suma_columna - 100) < 0.05
    ) |>
    ungroup()
}

auditoria <- pmap_dfr(
  mutate(mapa, orden_variable = row_number()),
  auditar_variable
) |>
  arrange(orden_variable, orden_categoria, valor_desenlace)

if (any(!auditoria$validacion_100)) {
  print(filter(auditoria, !validacion_100))
  stop("Al menos una variable no suma aproximadamente 100% por columna.")
}

write.csv(
  auditoria |>
    select(variable, categoria, desenlace, n, denominador,
           porcentaje_calculado, suma_columna, validacion_100),
  "tabla1_auditoria_porcentajes.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

tabla_corregida <- auditoria |>
  mutate(
    porcentaje = round(porcentaje_calculado, 2),
    valor_formateado = sprintf("%d (%.2f%%)", n, porcentaje)
  ) |>
  select(
    orden_variable, orden_categoria, variable, etiqueta, categoria,
    desenlace, n, denominador, porcentaje, valor_formateado
  )

write.csv(
  tabla_corregida,
  "tabla1_corregida.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("datos_tabla1:", nrow(datos_tabla1), "registros\n")
cat("Porcentajes auditados:", nrow(tabla_corregida), "\n")
cat("Validación de sumas por columna: OK\n")
