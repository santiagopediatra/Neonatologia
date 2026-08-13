#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(tidyverse))

ruta_base <- "datos/procesados/base_analitica_frecuentista.csv"
datos <- read.csv(
  ruta_base, check.names = FALSE, fileEncoding = "UTF-8",
  na.strings = c("", "NA", "N/A", "NULL")
)

stopifnot("MUERTE_FETAL_BINARIA" %in% names(datos))
stopifnot("EDAD_GESTACIONAL_ANALITICA" %in% names(datos))
stopifnot("NO_CONTROLES_NUM" %in% names(datos))

if (!identical(sort(unique(na.omit(datos$MUERTE_FETAL_BINARIA))), c(0L, 1L)) &&
    !identical(sort(unique(na.omit(datos$MUERTE_FETAL_BINARIA))), c(0, 1))) {
  stop("MUERTE_FETAL_BINARIA no está codificada exclusivamente como 0/1.")
}
if (sum(!is.na(datos$MUERTE_FETAL_BINARIA)) != 23642) {
  stop("La población con desenlace válido no es 23.642.")
}

datos <- datos |>
  mutate(
    controles_observados = suppressWarnings(as.numeric(NO_CONTROLES_NUM)),
    eg_original = suppressWarnings(as.numeric(SEMANAS_GESTACION_NUM)),
    eg_analitica = suppressWarnings(as.numeric(EDAD_GESTACIONAL_ANALITICA)),
    eg_implausible = !is.na(eg_original) & (eg_original < 20 | eg_original > 43),
    controles_implausibles = !is.na(controles_observados) & controles_observados < 0
  )

controles_esperados <- function(eg) {
  case_when(
    is.na(eg) ~ NA_real_,
    eg < 13 ~ 1,
    eg < 20 ~ 2,
    eg < 28 ~ 3,
    eg < 36 ~ 6,
    eg >= 36 ~ 8
  )
}

datos_adherencia <- datos |>
  filter(
    !is.na(MUERTE_FETAL_BINARIA),
    !is.na(eg_analitica),
    !is.na(controles_observados),
    !eg_implausible,
    !controles_implausibles
  ) |>
  mutate(
    controles_esperados = controles_esperados(eg_analitica),
    adherencia_pct = 100 * controles_observados / controles_esperados,
    categoria_adherencia = factor(
      case_when(
        adherencia_pct >= 80 ~ "Buena",
        adherencia_pct >= 50 ~ "Parcial",
        adherencia_pct < 50 ~ "Baja"
      ),
      levels = c("Buena", "Parcial", "Baja")
    )
  )

n_inicial <- nrow(datos)
n_des_validos <- sum(!is.na(datos$MUERTE_FETAL_BINARIA))
n_eg_valida <- sum(!is.na(datos$EDAD_GESTACIONAL_ANALITICA))
n_controles_validos <- sum(!is.na(datos$controles_observados) & !datos$controles_implausibles)
n_final <- nrow(datos_adherencia)

auditoria <- tibble(
  indicador = c(
    "N inicial", "N con muerte fetal válida", "N con EG analítica válida",
    "N con controles válidos", "N analítico", "Muerte fetal faltante",
    "EG analítica faltante", "Controles faltantes", "EG implausible en variable original",
    "Controles implausibles", "Mínimo EG", "Máximo EG", "Mediana EG",
    "Mínimo controles", "Máximo controles", "Mediana controles",
    "Casos adherencia >100%", "Porcentaje adherencia >100%"
  ),
  valor = c(
    n_inicial, n_des_validos, n_eg_valida, n_controles_validos, n_final,
    sum(is.na(datos$MUERTE_FETAL_BINARIA)), sum(is.na(datos$eg_analitica)),
    sum(is.na(datos$controles_observados)), sum(datos$eg_implausible, na.rm = TRUE),
    sum(datos$controles_implausibles, na.rm = TRUE),
    min(datos_adherencia$eg_analitica), max(datos_adherencia$eg_analitica),
    median(datos_adherencia$eg_analitica), min(datos_adherencia$controles_observados),
    max(datos_adherencia$controles_observados), median(datos_adherencia$controles_observados),
    sum(datos_adherencia$adherencia_pct > 100),
    100 * mean(datos_adherencia$adherencia_pct > 100)
  )
)
write.csv(auditoria, "adherencia_auditoria.csv", row.names = FALSE, fileEncoding = "UTF-8")

datos_adherencia |>
  filter(adherencia_pct > 100) |>
  select(ID_REGISTRO, MUERTE_FETAL_BINARIA, eg_analitica, controles_observados,
         controles_esperados, adherencia_pct, categoria_adherencia) |>
  write.csv("adherencia_mayor_100.csv", row.names = FALSE, fileEncoding = "UTF-8")

resumir_grupo <- function(df, grupo, desenlace) {
  tibble(
    categoria_adherencia = grupo,
    desenlace = desenlace,
    n = nrow(df),
    porcentaje_columna = 100 * nrow(df) / ifelse(
      desenlace == "Total", nrow(datos_adherencia),
      sum(datos_adherencia$MUERTE_FETAL_BINARIA == ifelse(desenlace == "NO", 0, 1))
    ),
    media_controles_observados = mean(df$controles_observados),
    de_controles_observados = sd(df$controles_observados),
    mediana_controles_observados = median(df$controles_observados),
    q1_controles_observados = quantile(df$controles_observados, 0.25),
    q3_controles_observados = quantile(df$controles_observados, 0.75),
    media_controles_esperados = mean(df$controles_esperados),
    de_controles_esperados = sd(df$controles_esperados),
    media_eg = mean(df$eg_analitica),
    de_eg = sd(df$eg_analitica)
  )
}

tabla_a1 <- map_dfr(levels(datos_adherencia$categoria_adherencia), function(cat) {
  dcat <- filter(datos_adherencia, categoria_adherencia == cat)
  bind_rows(
    resumir_grupo(filter(dcat, MUERTE_FETAL_BINARIA == 0), cat, "NO"),
    resumir_grupo(filter(dcat, MUERTE_FETAL_BINARIA == 1), cat, "SI"),
    resumir_grupo(dcat, cat, "Total")
  )
})
write.csv(tabla_a1, "adherencia_tabla_A1.csv", row.names = FALSE, fileEncoding = "UTF-8")

wilson <- function(x, n, z = qnorm(0.975)) {
  p <- x / n
  den <- 1 + z^2 / n
  centro <- (p + z^2 / (2 * n)) / den
  margen <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  c(inf = 100 * (centro - margen), sup = 100 * (centro + margen))
}

tabla_a2 <- datos_adherencia |>
  group_by(categoria_adherencia, .drop = FALSE) |>
  summarise(N = n(), n_muertes = sum(MUERTE_FETAL_BINARIA == 1), .groups = "drop") |>
  rowwise() |>
  mutate(
    mortalidad_pct = 100 * n_muertes / N,
    IC95_inf = wilson(n_muertes, N)[1],
    IC95_sup = wilson(n_muertes, N)[2],
    metodo_ic = "Wilson"
  ) |>
  ungroup()
write.csv(tabla_a2, "adherencia_tabla_A2.csv", row.names = FALSE, fileEncoding = "UTF-8")

ajustar_modelo <- function(formula, etiqueta) {
  advertencias <- character()
  fit <- withCallingHandlers(
    glm(formula, family = binomial(), data = datos_adherencia),
    warning = function(w) {
      advertencias <<- c(advertencias, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  sm <- summary(fit)$coefficients
  salida <- as.data.frame(sm) |>
    rownames_to_column("termino") |>
    transmute(
      modelo = etiqueta,
      termino,
      coeficiente = Estimate,
      SE = `Std. Error`,
      OR = exp(coeficiente),
      IC95_inf = exp(coeficiente - qnorm(0.975) * SE),
      IC95_sup = exp(coeficiente + qnorm(0.975) * SE),
      p = `Pr(>|z|)`,
      N = nobs(fit),
      eventos = sum(model.response(model.frame(fit)) == 1),
      convergencia = fit$converged,
      coeficientes_finitos = all(is.finite(coef(fit))),
      advertencias = paste(unique(advertencias), collapse = " | "),
      prob_min = min(fitted(fit)),
      prob_max = max(fitted(fit))
    )
  list(fit = fit, tabla = salida)
}

crudo <- ajustar_modelo(
  MUERTE_FETAL_BINARIA ~ categoria_adherencia,
  "Crudo"
)
ajustado <- ajustar_modelo(
  MUERTE_FETAL_BINARIA ~ categoria_adherencia + scale(eg_analitica),
  "Ajustado_EG"
)
modelos <- bind_rows(crudo$tabla, ajustado$tabla)
write.csv(modelos, "adherencia_modelos_logisticos.csv", row.names = FALSE, fileEncoding = "UTF-8")

diagnosticos <- tabla_a2 |>
  transmute(
    categoria_adherencia, N, eventos = n_muertes,
    pocos_eventos = eventos < 10
  )
write.csv(diagnosticos, "adherencia_diagnosticos_modelos.csv", row.names = FALSE, fileEncoding = "UTF-8")

# Los análisis previos usan número continuo de controles; se documentan como
# contexto direccional y se marcan explícitamente como no comparables en magnitud.
prev_eg <- read.csv("resultados/tablas/04_controles_ajustados_edad_gestacional.csv", check.names = FALSE) |>
  filter(VARIABLE == "CONTROLES_NUM")
prev_a <- read.csv("resultados/tablas/04_modelo_A_social_atencion.csv", check.names = FALSE) |>
  filter(VARIABLE == "CONTROLES_NUM")
comparacion <- bind_rows(
  tibble(
    analisis = c("Previo frecuentista Modelo A", "Previo frecuentista ajustado por EG"),
    definicion_exposicion = c("Número de controles, por unidad", "Número de controles, por unidad"),
    covariables = c("Dominio social/atención", "Edad gestacional continua"),
    OR = c(prev_a$OR_AJUSTADO, prev_eg$OR_AJUSTADO),
    IC95_inf = c(prev_a$IC95_INF, prev_eg$IC95_INF),
    IC95_sup = c(prev_a$IC95_SUP, prev_eg$IC95_SUP),
    p = c(prev_a$P_VALOR, prev_eg$P_VALOR),
    N = c(prev_a$N_MODELO, prev_eg$N),
    eventos = c(NA_integer_, NA_integer_),
    comparabilidad = "NO_DIRECTA: exposición continua distinta de categoría de adherencia"
  ),
  modelos |>
    filter(grepl("^categoria_adherencia", termino)) |>
    transmute(
      analisis = paste0("Adherencia ", modelo, ": ", sub("categoria_adherencia", "", termino), " vs Buena"),
      definicion_exposicion = "Categoría derivada de controles observados/esperados por EG",
      covariables = if_else(modelo == "Crudo", "Ninguna", "Edad gestacional estandarizada (sensibilidad)"),
      OR, IC95_inf, IC95_sup, p, N, eventos,
      comparabilidad = "Comparación interna entre categorías; no equiparable al OR por control"
    )
)
write.csv(comparacion, "adherencia_comparacion_modelos.csv", row.names = FALSE, fileEncoding = "UTF-8")

n_menor_20 <- sum(datos_adherencia$eg_analitica < 20)
estratificado <- datos_adherencia |>
  mutate(estrato_eg = cut(
    eg_analitica,
    breaks = c(20, 28, 36, Inf),
    right = FALSE,
    labels = c("20 a <28 semanas", "28 a <36 semanas", "≥36 semanas")
  )) |>
  filter(!is.na(estrato_eg)) |>
  group_by(estrato_eg, categoria_adherencia, .drop = FALSE) |>
  summarise(N = n(), n_muertes = sum(MUERTE_FETAL_BINARIA == 1), .groups = "drop") |>
  rowwise() |>
  mutate(
    mortalidad_pct = ifelse(N > 0, 100 * n_muertes / N, NA_real_),
    IC95_inf = ifelse(N > 0, wilson(n_muertes, N)[1], NA_real_),
    IC95_sup = ifelse(N > 0, wilson(n_muertes, N)[2], NA_real_),
    casos_eg_menor_20_excluidos = n_menor_20
  ) |>
  ungroup()
write.csv(estratificado, "adherencia_estratificado.csv", row.names = FALSE, fileEncoding = "UTF-8")

fig <- ggplot(tabla_a2, aes(x = categoria_adherencia, y = mortalidad_pct)) +
  geom_point(size = 2.7, colour = "#1F4E79") +
  geom_errorbar(aes(ymin = IC95_inf, ymax = IC95_sup), width = 0.15, colour = "#1F4E79") +
  geom_text(aes(label = paste0("N=", N)), vjust = -1.1, size = 3.5) +
  labs(
    title = "Mortalidad fetal por adherencia a controles prenatales",
    x = "Categoría de adherencia", y = "Mortalidad fetal (%)"
  ) +
  theme_classic(base_size = 11) +
  expand_limits(y = max(tabla_a2$IC95_sup) * 1.15)
ggsave("adherencia_fig1.png", fig, width = 7, height = 5, dpi = 300)

fmt <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")
dist <- datos_adherencia |>
  count(categoria_adherencia, .drop = FALSE) |>
  mutate(pct = 100 * n / sum(n))
mods_cat <- modelos |>
  filter(grepl("^categoria_adherencia", termino))

lineas <- c(
  "# Resumen del análisis de adherencia prenatal", "",
  "## Población analítica", "",
  paste0("- N inicial: ", n_inicial, "."),
  paste0("- N con muerte fetal válida: ", n_des_validos, "."),
  paste0("- N analítico final: ", n_final, "."),
  paste0("- Desenlace faltante: ", sum(is.na(datos$MUERTE_FETAL_BINARIA)), "."),
  paste0("- Edad gestacional analítica faltante: ", sum(is.na(datos$eg_analitica)), "."),
  paste0("- Controles faltantes: ", sum(is.na(datos$controles_observados)), "."),
  paste0("- Edad gestacional original implausible (<20 o >43): ", sum(datos$eg_implausible), "."),
  paste0("- Controles implausibles (<0): ", sum(datos$controles_implausibles), "."), "",
  "## Adherencia", "",
  paste0("- ", dist$categoria_adherencia, ": ", dist$n, " (", fmt(dist$pct), "%)."),
  paste0("- Adherencia >100%: ", sum(datos_adherencia$adherencia_pct > 100), " (",
         fmt(100 * mean(datos_adherencia$adherencia_pct > 100)), "%)."), "",
  "## Mortalidad", "",
  "| Categoría | N | Muertes | Mortalidad % | IC95% Wilson |",
  "|:--|--:|--:|--:|:--|",
  paste0("| ", tabla_a2$categoria_adherencia, " | ", tabla_a2$N, " | ", tabla_a2$n_muertes,
         " | ", fmt(tabla_a2$mortalidad_pct), " | ", fmt(tabla_a2$IC95_inf), "–",
         fmt(tabla_a2$IC95_sup), " |"), "",
  "## Regresión", "",
  "La categoría de referencia fue Buena. El modelo ajustado por edad gestacional se consideró una sensibilidad.", "",
  "| Modelo | Contraste | OR | IC95% | p |",
  "|:--|:--|--:|:--|--:|",
  paste0("| ", mods_cat$modelo, " | ", sub("categoria_adherencia", "", mods_cat$termino),
         " vs Buena | ", fmt(mods_cat$OR), " | ", fmt(mods_cat$IC95_inf), "–",
         fmt(mods_cat$IC95_sup), " | ", format.pval(mods_cat$p, digits = 3, eps = 0.001), " |"), "",
  "## Estratificación", "",
  paste0("Casos con EG <20 semanas excluidos del análisis estratificado: ", n_menor_20, ". Los resultados completos están en `adherencia_estratificado.csv`."), "",
  "## Comparación con análisis previo", "",
  "Los modelos previos expresaron la exposición como número continuo de controles (por unidad o por 1 DE). La nueva exposición es una categoría derivada de controles observados y edad gestacional; por ello, la comparación es conceptual y direccional, no una comparación numérica directa de OR.", "",
  "## Lo que los datos muestran", "",
  "Los datos describen diferencias de mortalidad y de odds entre categorías operacionales de adherencia. El cambio al incluir edad gestacional se interpreta como sensibilidad de especificación.", "",
  "## Lo que los datos no pueden demostrar", "",
  "No permiten separar causalmente edad gestacional, oportunidad acumulada de controles, acoplamiento matemático, selección, temporalidad, confusión residual y una posible asociación real. La regla 1/2/3/6/8 fue una especificación operacional solicitada y no se atribuyó como regla textual exacta de la OMS."
)
writeLines(lineas, "RESUMEN_ADHERENCIA.md", useBytes = TRUE)

cat("N analítico adherencia:", n_final, "\n")
print(dist)
print(tabla_a2)
print(mods_cat)
cat("Casos EG <20 en datos analíticos:", n_menor_20, "\n")
