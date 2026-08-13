import pandas as pd
import numpy as np
import re
from pathlib import Path


# ============================================================
# 1. CONFIGURACION
# ============================================================

PROCESADOS = Path("datos/procesados")
REPORTES = Path("datos/reportes")

REPORTES.mkdir(parents=True, exist_ok=True)

ARCHIVO_EMBARAZOS = (
    PROCESADOS /
    "cohorte_embarazos_preanalitica.csv"
)

ARCHIVO_FETAL = (
    PROCESADOS /
    "cohorte_fetal_preanalitica.csv"
)


# ============================================================
# 2. CARGAR BASES
# ============================================================

embarazos = pd.read_csv(
    ARCHIVO_EMBARAZOS,
    low_memory=False
)

fetal = pd.read_csv(
    ARCHIVO_FETAL,
    low_memory=False
)


print()
print("==================================================")
print("CONSTRUCCION DE BASE PARA ESTUDIO DE MUERTE FETAL")
print("==================================================")

print(
    f"Embarazos: {len(embarazos)}"
)

print(
    f"Registros fetales: {len(fetal)}"
)


# ============================================================
# 3. FUNCIONES GENERALES
# ============================================================

def texto_normalizado(valor):

    if pd.isna(valor):
        return pd.NA

    return (
        str(valor)
        .strip()
        .upper()
    )


def distribucion(df, variable):

    if variable not in df.columns:
        return pd.DataFrame()

    tabla = (
        df[variable]
        .fillna("FALTANTE")
        .astype(str)
        .str.strip()
        .value_counts(dropna=False)
        .reset_index()
    )

    tabla.columns = [
        "CATEGORIA",
        "N"
    ]

    tabla["PORCENTAJE"] = (
        tabla["N"]
        / len(df)
        * 100
    ).round(3)

    return tabla


def guardar_distribucion(
    df,
    variable,
    prefijo=""
):

    tabla = distribucion(
        df,
        variable
    )

    if len(tabla) == 0:
        return

    nombre = (
        prefijo +
        variable.lower()
        .replace(".", "_")
        + ".csv"
    )

    tabla.to_csv(
        REPORTES / nombre,
        index=False,
        encoding="utf-8-sig"
    )


# ============================================================
# 4. ANONIMIZACION
#
# CEDULA y HC no deben estar en la base del articulo.
# ID_REGISTRO se conserva como identificador tecnico anonimo.
# ============================================================

identificadores_eliminar = [
    "CEDULA",
    "HC",
    "HC."
]

embarazos = embarazos.drop(
    columns=[
        c
        for c in identificadores_eliminar
        if c in embarazos.columns
    ],
    errors="ignore"
)

fetal = fetal.drop(
    columns=[
        c
        for c in identificadores_eliminar
        if c in fetal.columns
    ],
    errors="ignore"
)


# ============================================================
# 5. EDAD MATERNA
#
# Mantener continua y crear categoria.
# No reemplazar edad continua.
# ============================================================

if "EDAD_NUM" in fetal.columns:

    edad = pd.to_numeric(
        fetal["EDAD_NUM"],
        errors="coerce"
    )

    fetal["EDAD_MATERNA_CATEGORIA"] = pd.cut(
        edad,
        bins=[
            -np.inf,
            19,
            34,
            np.inf
        ],
        labels=[
            "<20",
            "20-34",
            ">=35"
        ]
    )

elif "EDAD_NUM" in embarazos.columns:

    edad = pd.to_numeric(
        embarazos["EDAD_NUM"],
        errors="coerce"
    )

    embarazos[
        "EDAD_MATERNA_CATEGORIA"
    ] = pd.cut(
        edad,
        bins=[
            -np.inf,
            19,
            34,
            np.inf
        ],
        labels=[
            "<20",
            "20-34",
            ">=35"
        ]
    )


# ============================================================
# 6. PAREJA ESTABLE VS ESTADO CIVIL
#
# No eliminamos automaticamente.
# Primero generamos tabla de concordancia.
# ============================================================

if all(
    x in embarazos.columns
    for x in [
        "PAREJA_ESTABLE",
        "ESTADO_CIVIL"
    ]
):

    tabla_pareja = pd.crosstab(
        embarazos[
            "PAREJA_ESTABLE"
        ].fillna("FALTANTE"),

        embarazos[
            "ESTADO_CIVIL"
        ].fillna("FALTANTE"),

        margins=True
    )

    tabla_pareja.to_csv(
        REPORTES /
        "pareja_estable_vs_estado_civil.csv",
        encoding="utf-8-sig"
    )


guardar_distribucion(
    embarazos,
    "PAREJA_ESTABLE",
    "distribucion_"
)

guardar_distribucion(
    embarazos,
    "ESTADO_CIVIL",
    "distribucion_"
)


# ============================================================
# 7. SEGURO
#
# Se conserva SEGURO.
# AFILIACION se mantiene solamente en control,
# pero se eliminara de la base candidata del articulo.
# ============================================================

guardar_distribucion(
    embarazos,
    "SEGURO",
    "distribucion_"
)

guardar_distribucion(
    embarazos,
    "AFILIACION",
    "distribucion_"
)


# ============================================================
# 8. GRUPO CULTURAL VS ETNIA MINORITARIA
# ============================================================

guardar_distribucion(
    embarazos,
    "GRUPO_CULTURAL",
    "distribucion_"
)

guardar_distribucion(
    embarazos,
    "ETNIA_MINORITARIA",
    "distribucion_"
)


if all(
    x in embarazos.columns
    for x in [
        "GRUPO_CULTURAL",
        "ETNIA_MINORITARIA"
    ]
):

    tabla_etnia = pd.crosstab(
        embarazos[
            "GRUPO_CULTURAL"
        ].fillna("FALTANTE"),

        embarazos[
            "ETNIA_MINORITARIA"
        ].fillna("FALTANTE")
    )

    tabla_etnia.to_csv(
        REPORTES /
        "grupo_cultural_vs_etnia_minoritaria.csv",
        encoding="utf-8-sig"
    )


# ============================================================
# 9. DETECTAR CATEGORIAS ESCASAS
#
# Se consideran escasas para auditoria las categorias
# con menos de 1% o menos de 30 observaciones.
# NO se agrupan automaticamente.
# ============================================================

variables_categoricas_auditar = [
    "PAREJA_ESTABLE",
    "ESTADO_CIVIL",
    "SEGURO",
    "GRUPO_CULTURAL",
    "ETNIA_MINORITARIA",
    "HIPERTENSIVOS",
    "PRESENTACION_FETAL",
    "POSICION_DEL_PARTO",
    "TIPO_PARTO",
    "ALTERACION_PLACENTA",
    "TRASTRONOS_DE_LIQUIDO_AMNIOTICO",
    "ALTERACIONES_DEL_CORDON"
]


categorias_escasas = []


for variable in variables_categoricas_auditar:

    if variable not in embarazos.columns:
        continue

    tabla = distribucion(
        embarazos,
        variable
    )

    if len(tabla) == 0:
        continue

    for _, fila in tabla.iterrows():

        if fila["CATEGORIA"] == "FALTANTE":
            continue

        if (
            fila["N"] < 30
            or
            fila["PORCENTAJE"] < 1
        ):

            categorias_escasas.append({
                "VARIABLE":
                    variable,

                "CATEGORIA":
                    fila["CATEGORIA"],

                "N":
                    fila["N"],

                "PORCENTAJE":
                    fila["PORCENTAJE"],

                "ACCION":
                    "REVISAR_AGRUPACION"
            })


pd.DataFrame(
    categorias_escasas
).to_csv(
    REPORTES /
    "categorias_escasas_revisar.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 10. RIESGO AL INGRESO Y SCORE MAMA
# ============================================================

for variable in [
    "RIESGO_AL_INGRESO",
    "SCORE",
    "SCORE_NUM",
    "RIESGO",
    "SCORE_1",
    "SCORE_1_NUM"
]:

    guardar_distribucion(
        embarazos,
        variable,
        "distribucion_"
    )


# ------------------------------------------------------------
# RIESGO AL INGRESO VS RIESGO
# ------------------------------------------------------------

resumen_redundancia = []


if all(
    x in embarazos.columns
    for x in [
        "RIESGO_AL_INGRESO",
        "RIESGO"
    ]
):

    r1 = (
        embarazos["RIESGO_AL_INGRESO"]
        .astype("string")
        .str.strip()
        .str.upper()
    )

    r2 = (
        embarazos["RIESGO"]
        .astype("string")
        .str.strip()
        .str.upper()
    )

    comparables = (
        r1.notna()
        &
        r2.notna()
    )

    iguales = (
        comparables
        &
        (r1 == r2)
    )

    porcentaje = (
        iguales.sum()
        / comparables.sum()
        * 100
        if comparables.sum() > 0
        else np.nan
    )

    resumen_redundancia.append({
        "VARIABLE_1":
            "RIESGO_AL_INGRESO",

        "VARIABLE_2":
            "RIESGO",

        "N_COMPARABLE":
            int(comparables.sum()),

        "N_IGUALES":
            int(iguales.sum()),

        "CONCORDANCIA_PORCENTAJE":
            round(porcentaje, 2)
    })

    tabla = pd.crosstab(
        r1.fillna("FALTANTE"),
        r2.fillna("FALTANTE")
    )

    tabla.to_csv(
        REPORTES /
        "riesgo_ingreso_vs_riesgo.csv",
        encoding="utf-8-sig"
    )


# ------------------------------------------------------------
# SCORE MAMA AL INGRESO VS SCORE.1
# ------------------------------------------------------------

if all(
    x in embarazos.columns
    for x in [
        "SCORE_NUM",
        "SCORE_1_NUM"
    ]
):

    s1 = pd.to_numeric(
        embarazos["SCORE_NUM"],
        errors="coerce"
    )

    s2 = pd.to_numeric(
        embarazos["SCORE_1_NUM"],
        errors="coerce"
    )

    comparables = (
        s1.notna()
        &
        s2.notna()
    )

    iguales = (
        comparables
        &
        (s1 == s2)
    )

    porcentaje = (
        iguales.sum()
        / comparables.sum()
        * 100
        if comparables.sum() > 0
        else np.nan
    )

    resumen_redundancia.append({
        "VARIABLE_1":
            "SCORE_MAMA_INGRESO",

        "VARIABLE_2":
            "SCORE_1",

        "N_COMPARABLE":
            int(comparables.sum()),

        "N_IGUALES":
            int(iguales.sum()),

        "CONCORDANCIA_PORCENTAJE":
            round(porcentaje, 2)
    })


pd.DataFrame(
    resumen_redundancia
).to_csv(
    REPORTES /
    "auditoria_variables_redundantes.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 11. HIPERTENSION
#
# Mantener HIPERTENSIVOS original.
# Crear una version binaria adicional:
#
# NINGUNO / NO -> NO
# cualquier diagnostico hipertensivo -> SI
#
# Valores faltantes permanecen faltantes.
# ============================================================

def hipertension_binaria(valor):

    if pd.isna(valor):
        return pd.NA

    x = texto_normalizado(
        valor
    )

    negativos = {
        "NO",
        "NINGUNO",
        "NINGUNA",
        "SIN HIPERTENSION",
        "SIN HIPERTENSIVOS"
    }

    if x in negativos:
        return "NO"

    return "SI"


if "HIPERTENSIVOS" in fetal.columns:

    fetal[
        "HIPERTENSION_BINARIA"
    ] = fetal[
        "HIPERTENSIVOS"
    ].map(
        hipertension_binaria
    )

elif "HIPERTENSIVOS" in embarazos.columns:

    embarazos[
        "HIPERTENSION_BINARIA"
    ] = embarazos[
        "HIPERTENSIVOS"
    ].map(
        hipertension_binaria
    )


# ============================================================
# 12. INFECCIONES MATERNAS
#
# Se mantienen independientes:
# IVU
# TORCH
# ITS
# INFECCION_GENITAL
#
# Adicionalmente se crea una variable exploratoria:
# CUALQUIER_INFECCION_MATERNA
#
# Esta NO reemplaza a las originales.
# ============================================================

variables_infeccion = [
    "INFECCION_GENITAL",
    "IVU",
    "TORCH",
    "ITS"
]


def crear_cualquier_infeccion(df):

    disponibles = [
        x
        for x in variables_infeccion
        if x in df.columns
    ]

    if not disponibles:
        return

    resultado = []

    for _, fila in df[
        disponibles
    ].iterrows():

        valores = [
            texto_normalizado(x)
            for x in fila
            if pd.notna(x)
        ]

        if len(valores) == 0:
            resultado.append(pd.NA)
            continue

        if "SI" in valores:
            resultado.append("SI")
        else:
            resultado.append("NO")

    df[
        "CUALQUIER_INFECCION_MATERNA"
    ] = resultado


crear_cualquier_infeccion(
    fetal
)


# ============================================================
# 13. RPM
#
# RPM = ruptura prematura de membranas.
# Se conserva como variable propia.
# ============================================================


# ============================================================
# 14. PRESENTACION FETAL
#
# Crear:
# PRESENTACION_CEFALICA
#
# No confundir con POSICION_DEL_PARTO.
# ============================================================

def presentacion_cefalica(valor):

    if pd.isna(valor):
        return pd.NA

    x = texto_normalizado(
        valor
    )

    # Valores compatibles con presentacion cefalica
    cefalicas = {
        "VERTICE",
        "VÉRTICE",
        "CEFALICA",
        "CEFÁLICA",
        "CEFALICO",
        "CEFÁLICO"
    }

    if x in cefalicas:
        return "SI"

    # Si existe un valor real diferente,
    # se clasifica como no cefalica.
    return "NO"


if "PRESENTACION_FETAL" in fetal.columns:

    fetal[
        "PRESENTACION_CEFALICA"
    ] = fetal[
        "PRESENTACION_FETAL"
    ].map(
        presentacion_cefalica
    )


guardar_distribucion(
    fetal,
    "PRESENTACION_FETAL",
    "distribucion_"
)

guardar_distribucion(
    fetal,
    "POSICION_DEL_PARTO",
    "distribucion_"
)


# ============================================================
# 15. EMBARAZO MULTIPLE
#
# Mantener original y binaria.
# ============================================================

if (
    "EMBARAZO_MULTIPLE_BINARIO"
    not in fetal.columns
    and
    "EMBARAZO_MULTIPLE"
    in fetal.columns
):

    fetal[
        "EMBARAZO_MULTIPLE_BINARIO"
    ] = fetal[
        "EMBARAZO_MULTIPLE"
    ].map(
        lambda x:
        "NO"
        if texto_normalizado(x) == "NO"
        else (
            "SI"
            if pd.notna(x)
            else pd.NA
        )
    )


# ============================================================
# 16. APGAR
#
# Definiciones indicadas:
#
# APGAR_1 = Apgar al minuto
# APGAR_1_MENOR = Apgar < 7 al minuto
#
# APGAR_2 = segundo Apgar registrado
# APGAR_5_MENOR = Apgar < 7 a los 5 minutos
#
# NO usar Apgar como predictor causal de muerte intrauterina.
# ============================================================

validacion_apgar = []


# ------------------------------------------------------------
# APGAR <7 AL MINUTO
# ------------------------------------------------------------

if "APGAR_1_NUM" in fetal.columns:

    apgar1 = pd.to_numeric(
        fetal["APGAR_1_NUM"],
        errors="coerce"
    )

    fetal[
        "APGAR_1_BAJO_DERIVADO"
    ] = np.where(
        apgar1.notna(),
        np.where(
            apgar1 < 7,
            "SI",
            "NO"
        ),
        pd.NA
    )


    if "APGAR_1_MENOR" in fetal.columns:

        observado = (
            fetal[
                "APGAR_1_MENOR"
            ]
            .astype("string")
            .str.strip()
            .str.upper()
        )

        esperado = (
            fetal[
                "APGAR_1_BAJO_DERIVADO"
            ]
            .astype("string")
        )

        comparables = (
            observado.notna()
            &
            esperado.notna()
        )

        iguales = (
            comparables
            &
            (observado == esperado)
        )

        validacion_apgar.append({
            "VARIABLE":
                "APGAR_1_MENOR",

            "DEFINICION":
                "APGAR_1_NUM < 7",

            "COMPARABLES":
                int(comparables.sum()),

            "CONCORDANTES":
                int(iguales.sum()),

            "CONCORDANCIA_PORCENTAJE":
                round(
                    iguales.sum()
                    / comparables.sum()
                    * 100,
                    2
                )
                if comparables.sum() > 0
                else np.nan
        })


# ------------------------------------------------------------
# APGAR <7 A LOS 5 MINUTOS
#
# Se verifica contra APGAR_2_NUM.
# No se asume silenciosamente:
# el reporte indicara si realmente concuerda.
# ------------------------------------------------------------

if "APGAR_2_NUM" in fetal.columns:

    apgar5 = pd.to_numeric(
        fetal["APGAR_2_NUM"],
        errors="coerce"
    )

    fetal[
        "APGAR_5_BAJO_DERIVADO"
    ] = np.where(
        apgar5.notna(),
        np.where(
            apgar5 < 7,
            "SI",
            "NO"
        ),
        pd.NA
    )


    if "APGAR_5_MENOR" in fetal.columns:

        observado = (
            fetal[
                "APGAR_5_MENOR"
            ]
            .astype("string")
            .str.strip()
            .str.upper()
        )

        esperado = (
            fetal[
                "APGAR_5_BAJO_DERIVADO"
            ]
            .astype("string")
        )

        comparables = (
            observado.notna()
            &
            esperado.notna()
        )

        iguales = (
            comparables
            &
            (observado == esperado)
        )

        validacion_apgar.append({
            "VARIABLE":
                "APGAR_5_MENOR",

            "DEFINICION":
                "APGAR_2_NUM < 7",

            "COMPARABLES":
                int(comparables.sum()),

            "CONCORDANTES":
                int(iguales.sum()),

            "CONCORDANCIA_PORCENTAJE":
                round(
                    iguales.sum()
                    / comparables.sum()
                    * 100,
                    2
                )
                if comparables.sum() > 0
                else np.nan
        })


pd.DataFrame(
    validacion_apgar
).to_csv(
    REPORTES /
    "validacion_variables_apgar.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 17. DESENLACE PRINCIPAL
#
# MUERTE_INTRAUTERINA = desenlace principal.
# Crear variable de nombre analitico claro.
# ============================================================

if "MUERTE_INTRAUTERINA" in fetal.columns:

    fetal[
        "MUERTE_FETAL"
    ] = fetal[
        "MUERTE_INTRAUTERINA"
    ].map(
        lambda x:
        texto_normalizado(x)
        if pd.notna(x)
        else pd.NA
    )


# ============================================================
# 18. VARIABLES POSTERIORES AL DESENLACE
#
# Se conservan para descripcion neonatal,
# PERO NO para ajuste causal principal de muerte fetal.
# ============================================================

variables_posteriores = [
    "REANIMACION",
    "PINZAMIENTO",
    "APEGO_PRECOZ",
    "LACTANCIA",
    "APGAR_1",
    "APGAR_1_NUM",
    "APGAR_1_MENOR",
    "APGAR_1_BAJO_DERIVADO",
    "APGAR_2",
    "APGAR_2_NUM",
    "APGAR_5_MENOR",
    "APGAR_5_BAJO_DERIVADO",
    "CONSEJERIA_ANTICONCEPCION",
    "METODO",
    "LIGADURA"
]


# ============================================================
# 19. VARIABLES ANTROPOMETRICAS FETALES
#
# Se conservan, pero no se consideran automaticamente
# confusores del DAG.
# PESO puede ser mediador de varias exposiciones.
# ============================================================


# ============================================================
# 20. PESO AL NACIMIENTO
#
# Nuestra variable numerica anterior estaba 100% vacia.
# Auditar el campo original frente a PESO.
# ============================================================

if all(
    x in fetal.columns
    for x in [
        "PESO",
        "PESO_AL_NACIMIENTO"
    ]
):

    peso_a = (
        fetal["PESO"]
        .astype("string")
        .str.strip()
    )

    peso_b = (
        fetal["PESO_AL_NACIMIENTO"]
        .astype("string")
        .str.strip()
    )

    comparacion_peso = pd.DataFrame({
        "ID_REGISTRO":
            fetal["ID_REGISTRO"],

        "NUMERO_FETO":
            fetal.get(
                "NUMERO_FETO",
                pd.NA
            ),

        "PESO":
            peso_a,

        "PESO_AL_NACIMIENTO":
            peso_b
    })

    comparacion_peso.to_csv(
        REPORTES /
        "auditoria_peso_vs_peso_nacimiento.csv",
        index=False,
        encoding="utf-8-sig"
    )


# ============================================================
# 21. DICCIONARIO DE VARIABLES DEL ARTICULO
# ============================================================

diccionario = [
    {
        "VARIABLE": "ID_REGISTRO",
        "SIGNIFICADO": "Identificador tecnico anonimo del embarazo",
        "ROL": "IDENTIFICADOR_TECNICO",
        "USO_MODELO_CAUSAL": "NO"
    },
    {
        "VARIABLE": "ANIO_INGRESO",
        "SIGNIFICADO": "Año de ingreso",
        "ROL": "CONTEXTO_TEMPORAL",
        "USO_MODELO_CAUSAL": "POSIBLE_AJUSTE_TEMPORAL"
    },
    {
        "VARIABLE": "EDAD_NUM",
        "SIGNIFICADO": "Edad materna continua",
        "ROL": "FACTOR_MATERNO_PREVIO",
        "USO_MODELO_CAUSAL": "SI"
    },
    {
        "VARIABLE": "EDAD_MATERNA_CATEGORIA",
        "SIGNIFICADO": "<20, 20-34, >=35 años",
        "ROL": "DESCRIPTIVA_DERIVADA",
        "USO_MODELO_CAUSAL": "NO_JUNTO_CON_EDAD_NUM"
    },
    {
        "VARIABLE": "PAREJA_ESTABLE",
        "SIGNIFICADO": "Presencia de pareja estable",
        "ROL": "SOCIODEMOGRAFICA",
        "USO_MODELO_CAUSAL": "AUDITAR"
    },
    {
        "VARIABLE": "ESTADO_CIVIL",
        "SIGNIFICADO": "Estado civil",
        "ROL": "SOCIODEMOGRAFICA",
        "USO_MODELO_CAUSAL": "AUDITAR_REDUNDANCIA"
    },
    {
        "VARIABLE": "INSTRUCCION",
        "SIGNIFICADO": "Nivel de instruccion materna",
        "ROL": "SOCIOECONOMICA",
        "USO_MODELO_CAUSAL": "SI"
    },
    {
        "VARIABLE": "SEGURO",
        "SIGNIFICADO": "Disponibilidad/antecedente de seguridad social",
        "ROL": "ACCESO_SOCIAL",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "GRUPO_CULTURAL",
        "SIGNIFICADO": "Grupo cultural registrado",
        "ROL": "SOCIOCULTURAL",
        "USO_MODELO_CAUSAL": "AUDITAR"
    },
    {
        "VARIABLE": "ETNIA_MINORITARIA",
        "SIGNIFICADO": "Pertenencia a etnia minoritaria",
        "ROL": "SOCIOCULTURAL",
        "USO_MODELO_CAUSAL": "AUDITAR"
    },
    {
        "VARIABLE": "NO_CONTROLES_NUM",
        "SIGNIFICADO": "Numero de controles prenatales",
        "ROL": "ATENCION_PRENATAL",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "RIESGO_AL_INGRESO",
        "SIGNIFICADO": "Clasificacion de riesgo materno al ingreso",
        "ROL": "MARCADOR_RIESGO_INICIAL",
        "USO_MODELO_CAUSAL": "CUIDADO_VARIABLE_COMPUESTA"
    },
    {
        "VARIABLE": "SCORE_NUM",
        "SIGNIFICADO": "Score MAMA al ingreso",
        "ROL": "MARCADOR_CLINICO_INICIAL",
        "USO_MODELO_CAUSAL": "NO_AJUSTAR_AUTOMATICAMENTE"
    },
    {
        "VARIABLE": "OBESIDAD",
        "SIGNIFICADO": "Obesidad materna",
        "ROL": "FACTOR_MATERNO",
        "USO_MODELO_CAUSAL": "SI"
    },
    {
        "VARIABLE": "DIABETES_EN_EL_EMBARAZO",
        "SIGNIFICADO": "Diabetes en el embarazo",
        "ROL": "CONDICION_MATERNA",
        "USO_MODELO_CAUSAL": "SI"
    },
    {
        "VARIABLE": "HIPERTENSION_BINARIA",
        "SIGNIFICADO": "Cualquier trastorno hipertensivo registrado",
        "ROL": "CONDICION_MATERNA",
        "USO_MODELO_CAUSAL": "SI"
    },
    {
        "VARIABLE": "ANEMIA",
        "SIGNIFICADO": "Anemia materna",
        "ROL": "CONDICION_MATERNA",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "VIH",
        "SIGNIFICADO": "VIH materno",
        "ROL": "INFECCION_MATERNA",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "IVU",
        "SIGNIFICADO": "Infeccion de vias urinarias materna",
        "ROL": "INFECCION_MATERNA",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "TORCH",
        "SIGNIFICADO": "Registro materno de infeccion TORCH",
        "ROL": "INFECCION_MATERNA",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "ITS",
        "SIGNIFICADO": "Infeccion de transmision sexual",
        "ROL": "INFECCION_MATERNA",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "RPM",
        "SIGNIFICADO": "Ruptura prematura de membranas",
        "ROL": "COMPLICACION_EMBARAZO",
        "USO_MODELO_CAUSAL": "CANDIDATA_MEDIADOR_SEGUN_EXPOSICION"
    },
    {
        "VARIABLE": "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
        "SIGNIFICADO": "Desprendimiento prematuro de placenta",
        "ROL": "COMPLICACION_PLACENTARIA",
        "USO_MODELO_CAUSAL": "PROXIMAL_MEDIADOR_POSIBLE"
    },
    {
        "VARIABLE": "ALTERACION_PLACENTA",
        "SIGNIFICADO": "Alteracion placentaria registrada",
        "ROL": "COMPLICACION_PLACENTARIA",
        "USO_MODELO_CAUSAL": "PROXIMAL_MEDIADOR_POSIBLE"
    },
    {
        "VARIABLE": "EMBARAZO_MULTIPLE_BINARIO",
        "SIGNIFICADO": "Embarazo unico vs multiple",
        "ROL": "CARACTERISTICA_EMBARAZO",
        "USO_MODELO_CAUSAL": "SI"
    },
    {
        "VARIABLE": "PRESENTACION_CEFALICA",
        "SIGNIFICADO": "Presentacion cefalica SI/NO",
        "ROL": "CARACTERISTICA_FETAL_OBSTETRICA",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "SEXO",
        "SIGNIFICADO": "Sexo fetal",
        "ROL": "CARACTERISTICA_FETAL",
        "USO_MODELO_CAUSAL": "CANDIDATA"
    },
    {
        "VARIABLE": "SEMANAS_GESTACION_NUM",
        "SIGNIFICADO": "Semanas de gestacion",
        "ROL": "EDAD_GESTACIONAL",
        "USO_MODELO_CAUSAL": "CUIDADO_POSIBLE_MEDIADOR"
    },
    {
        "VARIABLE": "PESO_NUM",
        "SIGNIFICADO": "Peso fetal/nacimiento registrado",
        "ROL": "ANTROPOMETRIA_FETAL",
        "USO_MODELO_CAUSAL": "NO_AJUSTAR_AUTOMATICAMENTE"
    },
    {
        "VARIABLE": "MUERTE_FETAL",
        "SIGNIFICADO": "Muerte intrauterina SI/NO",
        "ROL": "DESENLACE_PRINCIPAL",
        "USO_MODELO_CAUSAL": "OUTCOME"
    },
    {
        "VARIABLE": "APGAR_1_NUM",
        "SIGNIFICADO": "Apgar al minuto",
        "ROL": "RESULTADO_NEONATAL_POSTERIOR",
        "USO_MODELO_CAUSAL": "NO"
    },
    {
        "VARIABLE": "APGAR_1_MENOR",
        "SIGNIFICADO": "Apgar <7 al minuto",
        "ROL": "RESULTADO_NEONATAL_POSTERIOR",
        "USO_MODELO_CAUSAL": "NO"
    },
    {
        "VARIABLE": "APGAR_5_MENOR",
        "SIGNIFICADO": "Apgar <7 a los 5 minutos",
        "ROL": "RESULTADO_NEONATAL_POSTERIOR",
        "USO_MODELO_CAUSAL": "NO"
    },
    {
        "VARIABLE": "REANIMACION",
        "SIGNIFICADO": "Reanimacion neonatal",
        "ROL": "POSTERIOR_AL_DESENLACE",
        "USO_MODELO_CAUSAL": "NO"
    },
    {
        "VARIABLE": "APEGO_PRECOZ",
        "SIGNIFICADO": "Apego precoz",
        "ROL": "POSTERIOR_AL_DESENLACE",
        "USO_MODELO_CAUSAL": "NO"
    },
    {
        "VARIABLE": "LACTANCIA",
        "SIGNIFICADO": "Lactancia",
        "ROL": "POSTERIOR_AL_DESENLACE",
        "USO_MODELO_CAUSAL": "NO"
    }
]


diccionario_df = pd.DataFrame(
    diccionario
)


diccionario_df.to_csv(
    REPORTES /
    "diccionario_variables_articulo.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 22. CREAR BASE CANDIDATA PARA ANALISIS DE MUERTE FETAL
# ============================================================

base_estudio = fetal.copy()


# ------------------------------------------------------------
# Variables que ya decidimos excluir del articulo
# ------------------------------------------------------------

eliminar_definitivamente = [
    "AFILIACION",

    # fechas exactas
    "FECHA_INGRESO",
    "FECHA_NACIMI_MADRE",
    "FECHA_NACIMIENTO",
    "FECHA_DE_EGRESO"
]


base_estudio = base_estudio.drop(
    columns=[
        x
        for x in eliminar_definitivamente
        if x in base_estudio.columns
    ],
    errors="ignore"
)


# ============================================================
# 23. BASE EXCLUSIVA CANDIDATA PARA DAG
#
# No contiene variables claramente posteriores al desenlace.
# Tampoco elimina aun mediadores potenciales:
# se conservan para poder construir distintos DAG segun
# la exposicion de interes.
# ============================================================

base_dag = base_estudio.drop(
    columns=[
        x
        for x in variables_posteriores
        if x in base_estudio.columns
    ],
    errors="ignore"
)


# ============================================================
# 24. LISTA DE VARIABLES CANDIDATAS PARA EL DAG
# ============================================================

variables_dag_candidatas = [
    "ANIO_INGRESO",

    "EDAD_NUM",
    "EDAD_MATERNA_CATEGORIA",

    "PAREJA_ESTABLE",
    "ESTADO_CIVIL",
    "INSTRUCCION",
    "SEGURO",
    "GRUPO_CULTURAL",
    "ETNIA_MINORITARIA",

    "NO_CONTROLES_NUM",

    "RIESGO_AL_INGRESO",
    "SCORE_NUM",

    "ANTECEDENTE_DE_CIRUGIA_UTERINA",
    "ANOMALIAS_GENITALES",

    "VIH",
    "OBESIDAD",
    "DIABETES_EN_EL_EMBARAZO",
    "HIPERTENSION_BINARIA",
    "ANEMIA",

    "INFECCION_GENITAL",
    "IVU",
    "TORCH",
    "ITS",
    "CUALQUIER_INFECCION_MATERNA",

    "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
    "ALTERACION_PLACENTA",
    "ISOINMUNIZACION",

    "TRASTRONOS_DE_LIQUIDO_AMNIOTICO",
    "RPM",

    "ALTERACIONES_DEL_CORDON",

    "EMBARAZO_MULTIPLE_BINARIO",

    "PRESENTACION_CEFALICA",

    "SEXO",

    "SEMANAS_GESTACION_NUM",

    "PESO_NUM",

    "MUERTE_FETAL"
]


variables_dag_presentes = [
    x
    for x in variables_dag_candidatas
    if x in base_dag.columns
]


pd.DataFrame({
    "VARIABLE":
        variables_dag_presentes
}).to_csv(
    REPORTES /
    "variables_candidatas_dag.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 25. GUARDAR BASES
# ============================================================

base_estudio.to_csv(
    PROCESADOS /
    "base_estudio_muerte_fetal.csv",
    index=False,
    encoding="utf-8-sig"
)


base_dag.to_csv(
    PROCESADOS /
    "base_candidata_dag.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 26. RESUMEN EN TERMINAL
# ============================================================

print()
print("==================================================")
print("RESULTADOS")
print("==================================================")


print()
print("ANONIMIZACION:")
print(
    "CEDULA y HC eliminadas de las bases del articulo."
)


print()
print("EDAD:")
print(
    "Se conserva EDAD_NUM y se crea "
    "EDAD_MATERNA_CATEGORIA."
)


print()
print("SEGURO:")
print(
    "SEGURO se conserva; AFILIACION se excluye "
    "de la base candidata del articulo."
)


print()
print("SCORE:")
print(
    "SCORE_NUM se reconoce como Score MAMA."
)

print(
    "No se elimina SCORE_1/RIESGO todavia; "
    "se genero auditoria de concordancia."
)


print()
print("INFECCIONES:")
print(
    "IVU, TORCH, ITS e INFECCION_GENITAL "
    "se mantienen separadas."
)


print()
print("PRESENTACION:")
print(
    "Se creo PRESENTACION_CEFALICA."
)


print()
print("APGAR:")
if len(validacion_apgar) > 0:

    print(
        pd.DataFrame(
            validacion_apgar
        ).to_string(
            index=False
        )
    )

else:
    print(
        "No fue posible realizar validacion."
    )


print()
print("DESENLACE:")
print(
    "MUERTE_FETAL = MUERTE_INTRAUTERINA."
)


print()
print("BASES CREADAS:")

print(
    "datos/procesados/"
    "base_estudio_muerte_fetal.csv"
)

print(
    "datos/procesados/"
    "base_candidata_dag.csv"
)


print()
print("REPORTES PRINCIPALES:")

print(
    "datos/reportes/"
    "diccionario_variables_articulo.csv"
)

print(
    "datos/reportes/"
    "auditoria_variables_redundantes.csv"
)

print(
    "datos/reportes/"
    "validacion_variables_apgar.csv"
)

print(
    "datos/reportes/"
    "categorias_escasas_revisar.csv"
)

print(
    "datos/reportes/"
    "variables_candidatas_dag.csv"
)

print(
    "datos/reportes/"
    "pareja_estable_vs_estado_civil.csv"
)

print(
    "datos/reportes/"
    "grupo_cultural_vs_etnia_minoritaria.csv"
)

print(
    "datos/reportes/"
    "riesgo_ingreso_vs_riesgo.csv"
)

print(
    "datos/reportes/"
    "auditoria_peso_vs_peso_nacimiento.csv"
)


print()
print("==================================================")
print("PROCESO TERMINADO")
print("==================================================")

print(
    f"Filas base estudio: {len(base_estudio)}"
)

print(
    f"Columnas base estudio: {len(base_estudio.columns)}"
)

print(
    f"Variables candidatas DAG presentes: "
    f"{len(variables_dag_presentes)}"
)

print()
print(
    "No se eliminaron automaticamente categorias "
    "clinicas escasas."
)

print(
    "No se imputaron variables."
)

print(
    "No se ajusto por variables posteriores al desenlace."
)
