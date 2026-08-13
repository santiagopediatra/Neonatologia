source("analisis_bayesiano/00_funciones_bayes.R"); library(openxlsx); d<-leer_base_bayes()
fit<-readRDS(file.path(DIR_MODELOS,"BAYES_PRINCIPAL.rds")); dr<-as_draws_df(fit)
unidad_fun<-function(p,s,n){v<-dr[[p]]/s;tibble(Factor=n,OR_posterior=exp(median(v)),CrI95_inf=exp(quantile(v,.025)),CrI95_sup=exp(quantile(v,.975)),P_OR_mayor_1=mean(v>0),P_OR_menor_1=mean(v<0))}
unidad<-bind_rows(unidad_fun("b_CONTROLES_Z",sd(d$CONTROLES_NUM,na.rm=TRUE),"Controles prenatales, por unidad original"),unidad_fun("b_SESIONES_Z",sd(d$SESIONES_NUM_A,na.rm=TRUE),"Sesiones psicoprofilaxis, por unidad original"))
write_csv(unidad,file.path(DIR_TABLAS,"TABLA_BAYES_CONTROLES_SESIONES_UNIDAD_ORIGINAL.csv"))
readtab<-function(x) read_csv(file.path(DIR_TABLAS,x),show_col_types=FALSE)
tabs<-list(Principal=readtab("TABLA_BAYES_PRINCIPAL.csv"),Priors=readtab("PRIORS_ESPECIFICADOS.csv"),Sens_Priors=readtab("TABLA_SENSIBILIDAD_PRIORS.csv"),Sens_Edad=readtab("TABLA_BAYES_SENS_EDAD_CONTINUA.csv"),Sens_EG=readtab("TABLA_SENS_CONTROLES_EG.csv"),Clinico=readtab("TABLA_BAYES_CLINICO_INGRESO.csv"),Obstetrico=readtab("TABLA_BAYES_OBSTETRICO.csv"),Hipertension=readtab("TABLA_SENS_HIPERTENSION_AGRUPADA.csv"),Seguro=readtab("TABLA_BAYES_SEGURO.csv"),Acompanamiento=readtab("TABLA_BAYES_ACOMPANAMIENTO_DETALLE.csv"))
allres<-bind_rows(tabs$Principal,tabs$Clinico,tabs$Obstetrico)
resumen<-allres%>%distinct(Modelo,Parametro,.keep_all=TRUE)%>%mutate(Dominio=case_when(grepl("DPP|RPM|HEMORRAGIA|VERTICE",Parametro)~"Obstétrico",grepl("RIESGO",Parametro)~"Clínico",TRUE~"Principal"),Factor=Variable,CrI95=sprintf("%.2f-%.2f",CrI95_inf,CrI95_sup),Direccion=ifelse(OR_posterior>=1,"Asociación positiva","Asociación negativa"),P_direccion=ifelse(OR_posterior>=1,P_OR_mayor_1,P_OR_menor_1),Interpretacion_metodologica=ifelse(grepl("RPM",Parametro),"Asociación negativa; la temporalidad del registro impide interpretarla automáticamente como efecto protector. Puede existir temporalidad inversa o diferencias en el registro clínico.","Asociación no causal en un estudio transversal."))%>%select(Dominio,Factor,OR_posterior,CrI95,P_direccion,Direccion,Modelo,Interpretacion_metodologica)
write_csv(resumen,file.path(DIR_TABLAS,"TABLA_RESUMEN_BAYESIANO.csv")); tabs$Resumen<-resumen
if(file.exists(file.path(DIR_TABLAS,"TABLA_COMPARACION_FRECUENTISTA_BAYES.csv"))) tabs$Comparacion_Frec<-readtab("TABLA_COMPARACION_FRECUENTISTA_BAYES.csv")
tabs$Diagnosticos<-read_csv(file.path(DIR_DIAG,"DIAGNOSTICOS_TODOS_MODELOS.csv"),show_col_types=FALSE)
wb<-createWorkbook(); hs<-createStyle(textDecoration="bold",fgFill="#D9EAF7")
for(n in names(tabs)){addWorksheet(wb,n);writeData(wb,n,tabs[[n]],headerStyle=hs,withFilter=TRUE);freezePane(wb,n,firstRow=TRUE);setColWidths(wb,n,1:ncol(tabs[[n]]),"auto")}
saveWorkbook(wb,file.path(DIR_TABLAS,"RESULTADOS_BAYESIANOS.xlsx"),overwrite=TRUE)
