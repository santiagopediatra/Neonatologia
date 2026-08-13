options(brms.backend = "cmdstanr", mc.cores = min(4L, parallel::detectCores()))

suppressPackageStartupMessages({
  library(brms); library(cmdstanr); library(posterior); library(bayesplot)
  library(loo); library(ggplot2); library(dplyr); library(tidyr); library(readr)
})

RAIZ <- normalizePath(".")
SALIDA <- file.path(RAIZ, "resultados", "bayesiano_2026-08-10")
DIR_MODELOS <- file.path(SALIDA, "modelos")
DIR_TABLAS <- file.path(SALIDA, "tablas")
DIR_FIGURAS <- file.path(SALIDA, "figuras")
DIR_DIAG <- file.path(SALIDA, "diagnosticos")
DIR_STAN <- file.path(SALIDA, "stan")
DIR_PP <- file.path(SALIDA, "posterior_predictive")
DIR_PRIOR_PP <- file.path(SALIDA, "prior_predictive")
DIR_DOC <- file.path(SALIDA, "documentacion")
invisible(lapply(c(DIR_MODELOS, DIR_TABLAS, DIR_FIGURAS, DIR_DIAG, DIR_STAN,
                   DIR_PP, DIR_PRIOR_PP, DIR_DOC), dir.create, recursive=TRUE, showWarnings=FALSE))

leer_base_bayes <- function() readRDS(file.path(SALIDA, "base_bayesiana_derivada.rds"))

filas_modelo <- function(formula, datos) {
  vars <- all.vars(formula)
  datos[stats::complete.cases(datos[, vars, drop=FALSE]), , drop=FALSE]
}

diagnostico_modelo <- function(fit, nombre) {
  sm <- posterior::summarise_draws(as_draws(fit), "rhat", "ess_bulk", "ess_tail")
  sm <- sm[grepl("^(b_|Intercept)", sm$variable), ]
  np <- tryCatch(brms::nuts_params(fit), error=function(e) NULL)
  diverg <- if (is.null(np)) NA_integer_ else sum(np$Parameter == "divergent__" & np$Value == 1)
  td <- if (is.null(np)) NA_integer_ else sum(np$Parameter == "treedepth__" & np$Value >= 15, na.rm=TRUE)
  tibble(Modelo=nombre, N=nobs(fit), Eventos=sum(fit$data$MUERTE_FETAL_BINARIA),
         Numero_parametros=nrow(sm), Max_Rhat=max(sm$rhat, na.rm=TRUE),
         Min_ESS_bulk=min(sm$ess_bulk, na.rm=TRUE), Min_ESS_tail=min(sm$ess_tail, na.rm=TRUE),
         Divergencias=diverg, Max_treedepth_excedido=td,
         Estado=ifelse(max(sm$rhat,na.rm=TRUE)<=1.01 && isTRUE(diverg==0), "OK", "REVISAR"))
}

ajustar_modelo_bayes <- function(formula, datos, priors, nombre, seed=20260810,
                                  iter=4000, warmup=2000, force=FALSE) {
  archivo <- file.path(DIR_MODELOS, paste0(nombre, ".rds"))
  logf <- file.path(DIR_DIAG, paste0("LOG_", nombre, ".txt"))
  d <- filas_modelo(formula, datos)
  if (file.exists(archivo) && !force) {
    fit <- readRDS(archivo)
    dg <- tryCatch(diagnostico_modelo(fit, nombre), error=function(e) NULL)
    if (!is.null(dg) && dg$Estado == "OK") return(fit)
  }
  configs <- list(
    list(iter=iter, warmup=warmup, adapt_delta=.99, max_treedepth=15),
    list(iter=max(iter,6000), warmup=max(warmup,3000), adapt_delta=.995, max_treedepth=15),
    list(iter=max(iter,6000), warmup=max(warmup,3000), adapt_delta=.999, max_treedepth=18)
  )
  for (i in seq_along(configs)) {
    z <- configs[[i]]
    cat(sprintf("%s | intento %d | N=%d | iter=%d warmup=%d adapt_delta=%s treedepth=%d\n",
                Sys.time(), i, nrow(d), z$iter, z$warmup, z$adapt_delta, z$max_treedepth),
        file=logf, append=TRUE)
    fit <- brm(formula=formula, data=d, family=bernoulli("logit"), prior=priors,
               seed=seed, chains=4, cores=min(4,parallel::detectCores()),
               iter=z$iter, warmup=z$warmup, thin=1, backend="cmdstanr",
               control=list(adapt_delta=z$adapt_delta,max_treedepth=z$max_treedepth),
               file=file.path(DIR_STAN, nombre), file_refit="on_change",
               save_pars=save_pars(all=TRUE), refresh=200)
    saveRDS(fit, archivo)
    dg <- diagnostico_modelo(fit, nombre)
    write_csv(dg, file.path(DIR_DIAG, paste0("DIAGNOSTICOS_", nombre, ".csv")))
    cat(sprintf("Resultado: Max_Rhat=%.4f; divergencias=%s; estado=%s\n",
                dg$Max_Rhat, dg$Divergencias, dg$Estado), file=logf, append=TRUE)
    if (dg$Estado == "OK") break
  }
  fit
}

etiqueta_parametro <- function(x) {
  dplyr::case_when(
    x=="b_EDAD_CAT<20" ~ "Edad <20 vs 20-34",
    x=="b_EDAD_CAT>=35" ~ "Edad >=35 vs 20-34",
    grepl("HIPERTENSIVOS_AECLAMPSIA",x) ~ "Eclampsia vs ningún trastorno hipertensivo",
    grepl("HIPERTENSIVOS_APREECLAMPSIA",x) ~ "Preeclampsia vs ninguno",
    grepl("HIPERTENSIVOS_AHTAINDUCIDA",x) ~ "HTA inducida por embarazo vs ninguno",
    grepl("HIPERTENSIVOS_AHTAPREEXISTENTE",x) ~ "HTA preexistente vs ninguno",
    grepl("PAREJA_ESTABLE_ASI",x) ~ "Pareja estable sí vs no",
    grepl("INSTRUCCION_ANINGUNA",x) ~ "Ninguna instrucción vs secundaria",
    grepl("INSTRUCCION_APRIMARIA",x) ~ "Primaria vs secundaria",
    grepl("INSTRUCCION_ASUPERIOR",x) ~ "Superior vs secundaria",
    grepl("ACOMPANADA_BINSI",x) ~ "Acompañada vs sola",
    x=="b_CONTROLES_Z" ~ "Controles prenatales, por 1 DE adicional",
    x=="b_SESIONES_Z" ~ "Sesiones de psicoprofilaxis, por 1 DE adicional",
    x=="b_EDAD_Z" ~ "Edad materna, por 1 DE adicional",
    x=="b_EG_Z" ~ "Edad gestacional, por 1 DE adicional",
    grepl("IVU_ASI",x) ~ "IVU sí vs no", grepl("RPM_ASI",x) ~ "RPM sí vs no",
    grepl("DPPSI",x) ~ "DPP sí vs no", grepl("HEMORRAGIA_ASI",x) ~ "Hemorragia sí vs no",
    grepl("VERTICESI",x) ~ "Presentación vértice sí vs no",
    grepl("RIESGO_INGRESO_ARIESGOALTO",x) ~ "Riesgo alto vs riesgo bajo",
    grepl("RIESGO_INGRESO_ARIESGOINMINENTE",x) ~ "Riesgo inminente vs riesgo bajo",
    grepl("SEGURO_ASI",x) ~ "Seguro sí vs no",
    grepl("ACOMPANADA_DETALLEFAMILIAR",x) ~ "Familiar vs pareja",
    grepl("ACOMPANADA_DETALLEOTRO",x) ~ "Otro vs pareja",
    grepl("ACOMPANADA_DETALLESOLA",x) ~ "Sola vs pareja",
    grepl("HIPERTENSIVOS_AGRUPADOPREECLAMPSIA",x) ~ "Preeclampsia/eclampsia vs ninguno",
    grepl("HIPERTENSIVOS_AGRUPADOHTAGESTACIONAL",x) ~ "HTA gestacional vs ninguno",
    grepl("HIPERTENSIVOS_AGRUPADOHTAPREEXISTENTE",x) ~ "HTA preexistente vs ninguno",
    TRUE ~ sub("^b_", "", x)
  )
}

referencia_parametro <- function(x) {
  case_when(grepl("EDAD_CAT",x)~"20-34", grepl("HIPERTENSIVOS",x)~"NINGUNO",
    grepl("INSTRUCCION",x)~"SECUNDARIA", grepl("ACOMPANADA_DETALLE",x)~"PAREJA",
    grepl("RIESGO_INGRESO",x)~"RIESGO BAJO", grepl("_Z$",x)~"Por 1 DE",
    TRUE~"NO")
}

resumen_posterior <- function(fit, nombre) {
  dr <- as_draws_df(fit)
  pars <- grep("^b_", names(dr), value=TRUE)
  sm <- posterior::summarise_draws(as_draws(fit), "rhat", "ess_bulk", "ess_tail")
  bind_rows(lapply(pars, function(p) {
    v <- dr[[p]]
    ds <- sm[sm$variable==p,]
    tibble(Parametro=p, Variable=etiqueta_parametro(p), Comparacion=etiqueta_parametro(p),
      Referencia=referencia_parametro(p), beta_mediana=median(v), beta_media=mean(v), SD_posterior=sd(v),
      OR_posterior=exp(median(v)), CrI95_inf=exp(quantile(v,.025)), CrI95_sup=exp(quantile(v,.975)),
      P_OR_mayor_1=mean(v>0), P_OR_menor_1=mean(v<0), Rhat=ds$rhat,
      ESS_bulk=ds$ess_bulk, ESS_tail=ds$ess_tail, N_modelo=nobs(fit), Modelo=nombre)
  }))
}

guardar_tabla_modelo <- function(fit, nombre, archivo) {
  z <- resumen_posterior(fit,nombre); write_csv(z,file.path(DIR_TABLAS,archivo)); z
}

guardar_ppc <- function(fit, etiqueta) {
  png(file.path(DIR_PP,paste0("POSTERIOR_PREDICTIVE_",etiqueta,".png")),1800,1200,res=200)
  print(pp_check(fit,type="bars",ndraws=100)); dev.off()
  yrep <- posterior_predict(fit,draws=1000)
  q <- quantile(rowSums(yrep),c(.025,.5,.975))
  write_csv(tibble(Modelo=etiqueta,Eventos_observados=sum(fit$data$MUERTE_FETAL_BINARIA),
                   Eventos_ppc_2.5=q[1],Eventos_ppc_mediana=q[2],Eventos_ppc_97.5=q[3]),
            file.path(DIR_PP,paste0("RESUMEN_PPC_",etiqueta,".csv")))
}

guardar_forest <- function(tabla, archivo, titulo=NULL) {
  p <- ggplot(tabla, aes(x=OR_posterior,y=reorder(Variable,OR_posterior)))+
    geom_vline(xintercept=1,lty=2,color="grey40")+geom_errorbarh(aes(xmin=CrI95_inf,xmax=CrI95_sup),height=.15)+
    geom_point(size=2,color="#176B87")+scale_x_log10()+labs(x="Odds ratio posterior (escala log)",y=NULL,title=titulo)+theme_bw(base_size=10)
  ggsave(file.path(DIR_FIGURAS,archivo),p,width=9,height=max(5,.3*nrow(tabla)+2),dpi=300)
}
