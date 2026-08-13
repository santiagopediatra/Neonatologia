rm(list = ls())

options(
  stringsAsFactors = FALSE,
  scipen = 999
)

ruta <- "datos/procesados/base_analitica_frecuentista.csv"

b <- read.csv(
  ruta,
  fileEncoding = "UTF-8",
  check.names = FALSE,
  na.strings = c("", "NA", "N/A", "NULL")
)

# Solo registros con desenlace conocido
d <- b[!is.na(b$MUERTE_FETAL_BINARIA), ]

cat("\n============================================\n")
cat("ANALISIS BIVARIADO DE ASOCIACION\n")
cat("============================================\n\n")

cat("Registros con desenlace conocido:", nrow(d), "\n")
cat("Muertes fetales:", sum(d$MUERTE_FETAL_BINARIA == 1), "\n")
cat("No muertes:", sum(d$MUERTE_FETAL_BINARIA == 0), "\n\n")

# ----------------------------------------------------------
# Funcion para variables binarias
# ----------------------------------------------------------

analizar_binaria <- function(data, variable, referencia = "NO", expuesto = "SI") {

  x <- data[[variable]]
  y <- data$MUERTE_FETAL_BINARIA

  valido <- !is.na(x) & !is.na(y)
  x <- x[valido]
  y <- y[valido]

  tab <- table(x, y)

  if (!(referencia %in% rownames(tab)) ||
      !(expuesto %in% rownames(tab))) {
    return(NULL)
  }

  a <- tab[expuesto, "1"]
  b0 <- tab[expuesto, "0"]
  c <- tab[referencia, "1"]
  d0 <- tab[referencia, "0"]

  # Correccion de Haldane-Anscombe si hay celda cero
  correccion <- any(c(a, b0, c, d0) == 0)

  if (correccion) {
    a2 <- a + 0.5
    b2 <- b0 + 0.5
    c2 <- c + 0.5
    d2 <- d0 + 0.5
  } else {
    a2 <- a
    b2 <- b0
    c2 <- c
    d2 <- d0
  }

  OR <- (a2 * d2) / (b2 * c2)

  SE <- sqrt(
    1/a2 + 1/b2 + 1/c2 + 1/d2
  )

  IC_inf <- exp(log(OR) - 1.96 * SE)
  IC_sup <- exp(log(OR) + 1.96 * SE)

  esperados <- suppressWarnings(
    chisq.test(tab, correct = FALSE)$expected
  )

  if (any(esperados < 5)) {
    prueba <- fisher.test(tab)
    metodo <- "Fisher"
    p <- prueba$p.value
  } else {
    prueba <- chisq.test(tab, correct = FALSE)
    metodo <- "Chi-cuadrado"
    p <- prueba$p.value
  }

  direccion <- ifelse(
    OR > 1,
    "POSITIVA",
    ifelse(OR < 1, "NEGATIVA", "NULA")
  )

  data.frame(
    VARIABLE = variable,
    REFERENCIA = referencia,
    EXPUESTO = expuesto,
    N_ANALIZADO = length(x),
    EVENTOS_EXPUESTO = as.numeric(a),
    NO_EVENTOS_EXPUESTO = as.numeric(b0),
    EVENTOS_REFERENCIA = as.numeric(c),
    NO_EVENTOS_REFERENCIA = as.numeric(d0),
    OR_CRUDO = OR,
    IC95_INF = IC_inf,
    IC95_SUP = IC_sup,
    P_VALOR = p,
    PRUEBA = metodo,
    DIRECCION = direccion,
    CORRECCION_CELDA_CERO = correccion,
    stringsAsFactors = FALSE
  )
}

# ----------------------------------------------------------
# Variables binarias
# ----------------------------------------------------------

vars_binarias <- c(
  "HIPERTENSION_BINARIA",
  "RPM",
  "EMBARAZO_MULTIPLE_BINARIO",
  "CUALQUIER_INFECCION_MATERNA",
  "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
  "PRESENTACION_CEFALICA",
  "ETNIA_MINORITARIA",
  "PAREJA_ESTABLE"
)

resultados_binarios <- do.call(
  rbind,
  lapply(
    vars_binarias,
    function(v) analizar_binaria(d, v)
  )
)

cat("RESULTADOS BINARIOS\n\n")

print(
  resultados_binarios,
  row.names = FALSE
)

write.csv(
  resultados_binarios,
  "resultados/tablas/asociaciones_binarias_crudas.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ----------------------------------------------------------
# Edad materna categorica mediante regresion logistica
# ----------------------------------------------------------

cat("\n============================================\n")
cat("EDAD MATERNA CATEGORICA\n")
cat("============================================\n\n")

edad <- d[
  !is.na(d$EDAD_CATEGORIA_ANALITICA),
]

edad$EDAD_CATEGORIA_ANALITICA <- factor(
  edad$EDAD_CATEGORIA_ANALITICA,
  levels = c("20-34", "<20", ">=35")
)

modelo_edad <- glm(
  MUERTE_FETAL_BINARIA ~ EDAD_CATEGORIA_ANALITICA,
  data = edad,
  family = binomial()
)

coef_edad <- summary(modelo_edad)$coefficients
ic_edad <- confint.default(modelo_edad)

tabla_edad <- data.frame(
  TERMINO = rownames(coef_edad),
  OR = exp(coef(modelo_edad)),
  IC95_INF = exp(ic_edad[,1]),
  IC95_SUP = exp(ic_edad[,2]),
  P_VALOR = coef_edad[,4],
  row.names = NULL
)

print(tabla_edad)

write.csv(
  tabla_edad,
  "resultados/tablas/asociacion_edad_materna_cruda.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ----------------------------------------------------------
# Edad gestacional categorica
# ----------------------------------------------------------

cat("\n============================================\n")
cat("EDAD GESTACIONAL CATEGORICA\n")
cat("============================================\n\n")

eg <- d[
  !is.na(d$EDAD_GESTACIONAL_CATEGORIA),
]

eg$EDAD_GESTACIONAL_CATEGORIA <- factor(
  eg$EDAD_GESTACIONAL_CATEGORIA,
  levels = c("37 A 41,6", "MENOR DE 37", "42 O MAS")
)

modelo_eg <- glm(
  MUERTE_FETAL_BINARIA ~ EDAD_GESTACIONAL_CATEGORIA,
  data = eg,
  family = binomial()
)

coef_eg <- summary(modelo_eg)$coefficients
ic_eg <- confint.default(modelo_eg)

tabla_eg <- data.frame(
  TERMINO = rownames(coef_eg),
  OR = exp(coef(modelo_eg)),
  IC95_INF = exp(ic_eg[,1]),
  IC95_SUP = exp(ic_eg[,2]),
  P_VALOR = coef_eg[,4],
  row.names = NULL
)

print(tabla_eg)

write.csv(
  tabla_eg,
  "resultados/tablas/asociacion_edad_gestacional_cruda.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

cat("\n============================================\n")
cat("ANALISIS BIVARIADO COMPLETADO\n")
cat("============================================\n")

cat("\nArchivos creados:\n")
cat("resultados/tablas/asociaciones_binarias_crudas.csv\n")
cat("resultados/tablas/asociacion_edad_materna_cruda.csv\n")
cat("resultados/tablas/asociacion_edad_gestacional_cruda.csv\n")
