source("analisis_bayesiano/00_funciones_bayes.R")
entrada <- "datos/procesados/base_analitica_frecuentista.csv"
d0 <- read_csv(entrada,show_col_types=FALSE)
n_inicial <- nrow(d0); n_conocido <- sum(!is.na(d0$MUERTE_FETAL_BINARIA))
d <- d0 %>% filter(!is.na(MUERTE_FETAL_BINARIA)) %>% mutate(
  EDAD_CAT=factor(EDAD_CATEGORIA_ANALITICA,levels=c("20-34","<20",">=35")),
  EDAD_Z=as.numeric(scale(EDAD_ANALITICA)),
  HIPERTENSIVOS_A=factor(HIPERTENSIVOS,levels=c("NINGUNO","PREECLAMPSIA","HTA INDUCIDA POR EL EMBARAZO","HTA PREEXISTENTE","ECLAMPSIA")),
  HIPERTENSIVOS_AGRUPADO=factor(case_when(HIPERTENSIVOS=="NINGUNO"~"NINGUNO",HIPERTENSIVOS=="HTA INDUCIDA POR EL EMBARAZO"~"HTA_GESTACIONAL",HIPERTENSIVOS=="HTA PREEXISTENTE"~"HTA_PREEXISTENTE",HIPERTENSIVOS %in% c("PREECLAMPSIA","ECLAMPSIA")~"PREECLAMPSIA_ECLAMPSIA"),levels=c("NINGUNO","HTA_GESTACIONAL","HTA_PREEXISTENTE","PREECLAMPSIA_ECLAMPSIA")),
  PAREJA_ESTABLE_A=factor(PAREJA_ESTABLE,levels=c("NO","SI")),
  INSTRUCCION_A=factor(INSTRUCCION,levels=c("SECUNDARIA","NINGUNA","PRIMARIA","SUPERIOR")),
  ACOMPANADA_BIN=factor(case_when(ACOMPANADA=="SOLA"~"NO",ACOMPANADA %in% c("PAREJA","FAMILIAR","OTRO")~"SI"),levels=c("NO","SI")),
  ACOMPANADA_DETALLE=factor(ifelse(ACOMPANADA %in% c("PAREJA","FAMILIAR","OTRO","SOLA"),ACOMPANADA,NA),levels=c("PAREJA","FAMILIAR","OTRO","SOLA")),
  CONTROLES_NUM=ifelse(NO_CONTROLES_NUM<0,NA_real_,NO_CONTROLES_NUM),
  CONTROLES_Z=as.numeric(scale(CONTROLES_NUM)),
  SESIONES_NUM_A=ifelse(SESIONES_NUM<0,NA_real_,SESIONES_NUM), SESIONES_Z=as.numeric(scale(SESIONES_NUM_A)),
  PSICOPROFILAXIS_ALGUNA=factor(case_when(is.na(SESIONES_NUM_A)~NA_character_,SESIONES_NUM_A==0~"NO",SESIONES_NUM_A>0~"SI"),levels=c("NO","SI")),
  IVU_A=factor(IVU,levels=c("NO","SI")), RPM_A=factor(RPM,levels=c("NO","SI")),
  DPP=factor(DESPRENDIMIENTO_PREMATURO_DE_PLACENTA,levels=c("NO","SI")), HEMORRAGIA_A=factor(HEMORRAGIA,levels=c("NO","SI")),
  VERTICE=factor(ifelse(PRESENTACION_FETAL %in% c("VÉRTICE","VERTICE"),"SI","NO"),levels=c("NO","SI")),
  RIESGO_INGRESO_A=factor(RIESGO_AL_INGRESO,levels=c("RIESGO BAJO","RIESGO ALTO","RIESGO INMINENTE")),
  SEGURO_A=factor(SEGURO,levels=c("NO","SI")), EG_Z=as.numeric(scale(EDAD_GESTACIONAL_ANALITICA)))
attr(d,"n_inicial") <- n_inicial; attr(d,"n_conocido") <- n_conocido
saveRDS(d,file.path(SALIDA,"base_bayesiana_derivada.rds"))
vars <- c("EDAD_CAT","EDAD_ANALITICA","EDAD_Z","HIPERTENSIVOS_A","PAREJA_ESTABLE_A","INSTRUCCION_A","ACOMPANADA_BIN","ACOMPANADA_DETALLE","CONTROLES_NUM","CONTROLES_Z","SESIONES_NUM_A","SESIONES_Z","IVU_A","RPM_A","DPP","HEMORRAGIA_A","VERTICE","RIESGO_INGRESO_A","SEGURO_A","EG_Z")
res <- bind_rows(tibble(Indicador=c("N_total_inicial","N_desenlace_conocido","Eventos","No_eventos"),Valor=c(n_inicial,nrow(d),sum(d$MUERTE_FETAL_BINARIA==1),sum(d$MUERTE_FETAL_BINARIA==0)),Media=NA_real_,SD=NA_real_),
  bind_rows(lapply(vars,function(v)tibble(Indicador=paste0("Faltantes_",v),Valor=sum(is.na(d[[v]])),Media=if(is.numeric(d[[v]]))mean(d[[v]],na.rm=TRUE) else NA_real_,SD=if(is.numeric(d[[v]]))sd(d[[v]],na.rm=TRUE) else NA_real_))))
write_csv(res,file.path(DIR_DOC,"resumen_base_bayesiana.csv"))
X <- model.matrix(~EDAD_CAT+HIPERTENSIVOS_A+PAREJA_ESTABLE_A+INSTRUCCION_A+ACOMPANADA_BIN+CONTROLES_Z+SESIONES_Z+IVU_A,data=filas_modelo(MUERTE_FETAL_BINARIA~EDAD_CAT+HIPERTENSIVOS_A+PAREJA_ESTABLE_A+INSTRUCCION_A+ACOMPANADA_BIN+CONTROLES_Z+SESIONES_Z+IVU_A,d))
cn <- kappa(X); write_csv(tibble(Condition_number=cn),file.path(DIR_DIAG,"COLINEALIDAD_PRINCIPAL.csv"))
cat("Base bayesiana preparada:",nrow(d),"registros;",sum(d$MUERTE_FETAL_BINARIA),"eventos; condition number",round(cn,2),"\n")
