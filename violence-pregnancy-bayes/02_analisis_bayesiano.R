# =============================================================================
# SCRIPT 01: ANÁLISIS BAYESIANO PRINCIPAL
# Violencia gestacional y desenlaces neonatales — HGOIA 2009–2024
# brms/Stan con priors N(0, 2.5)
# Tiempo estimado: 4–6 horas (Ryzen 9 3900X, 24 núcleos)
# =============================================================================

library(tidyverse)
library(brms)
library(posterior)
library(bayestestR)

set.seed(2024)
options(mc.cores = parallel::detectCores())

# ── CARGAR DATOS ──────────────────────────────────────────────────────────────
rds    <- readRDS("objetos_analisis_violencia_corregido.rds")
df     <- rds$d |>
  rename(sustancias = drogas, gestas = gestas_prev, consultas = n_cpn)

# ── PRIORS ────────────────────────────────────────────────────────────────────
priors_default <- c(
  prior(normal(0, 2.5),       class = b),
  prior(student_t(3, 0, 2.5), class = Intercept)
)

ctrl_mcmc <- list(adapt_delta = 0.97, max_treedepth = 15)

covars <- "edad_mat + escol_baja + etnia_min + pareja + tabaco_act +
           alcohol + sustancias + gestas + consultas"

desenlaces <- list(
  prematuro  = list(var = "prematuro",  viols = c("viol_1","viol_2","viol_3")),
  peg        = list(var = "pequeno_eg", viols = c("viol_1","viol_2","viol_3")),
  apgar1     = list(var = "apgar1",     viols = c("viol_1","viol_2","viol_3")),
  lactancia  = list(var = "lactancia",  viols = c("viol_1","viol_2","viol_3"))
)

resultados <- list()

for (des_name in names(desenlaces)) {
  des_info <- desenlaces[[des_name]]
  for (i in seq_along(des_info$viols)) {
    viol_var   <- des_info$viols[i]
    trimestre  <- paste0("T", i)
    model_name <- paste0(des_name, "_", trimestre)

    cat(sprintf("\n[%s] Ajustando: %s ~ %s\n",
                format(Sys.time(), "%H:%M"), des_info$var, viol_var))

    f <- as.formula(paste(des_info$var, "~", viol_var, "+", covars))

    fit <- tryCatch(
      brm(formula  = f,
          data     = df,
          family   = bernoulli(link = "logit"),
          prior    = priors_default,
          chains   = 4, iter = 6000, warmup = 2000,
          cores    = 4, seed  = 2024,
          control  = ctrl_mcmc,
          refresh  = 0, silent = 2),
      error = function(e) { cat("ERROR:", e$message, "\n"); NULL }
    )

    if (!is.null(fit)) {
      post <- as_draws_df(fit)[[paste0("b_", viol_var)]]
      resultados[[model_name]] <- tibble(
        desenlace  = des_info$var,
        trimestre  = trimestre,
        viol_var   = viol_var,
        logOR_med  = median(post),
        OR         = exp(median(post)),
        ICr_lo     = exp(quantile(post, 0.025)),
        ICr_hi     = exp(quantile(post, 0.975)),
        P_OR_gt_1  = mean(post > 0),
        Rhat_max   = max(rhat(fit), na.rm = TRUE),
        ESS_min    = min(ess_bulk(fit), na.rm = TRUE)
      )
      saveRDS(fit, paste0("modelo_", model_name, ".rds"))
    }
  }
}

tabla_bayes <- bind_rows(resultados)
write_csv(tabla_bayes, "tabla_resultados_bayesianos.csv")
print(tabla_bayes)
cat("\n=== Script 01 completado ===\n")
