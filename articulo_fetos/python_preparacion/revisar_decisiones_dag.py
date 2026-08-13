import pandas as pd
import numpy as np
from pathlib import Path


# ============================================================
# CONFIGURACION
# ============================================================

PROCESADOS = Path("datos/procesados")
REPORTES = Path("datos/reportes")

BASE = PROCESADOS / "base_estudio_muerte_fetal.csv"

df = pd.read_csv(
    BASE,
    low_memory=False
)


# ============================================================
# FUNCIONES
# ============================================================

def distribucion(variable, max_filas=30):

    print()
    print("=" * 60)
    print(variable)
    print("=" * 60)

    if variable not in df.columns:
        print("NO EXISTE")
        return

    serie = (
        df[variable]
        .astype("string")
        .str.strip()
    )

    tabla = (
        serie
        .fillna("FALTANTE")
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
    ).round(2)

    print(
        tabla.head(max_filas).to_string(
            index=False
        )
    )


def concordancia(variable1, variable2):

    print()
    print("=" * 60)
    print(f"{variable1} vs {variable2}")
    print("=" * 60)

    if (
        variable1 not in df.columns
        or variable2 not in df.columns
    ):
        print("Una o ambas variables no existen.")
        return

    a = (
        df[variable1]
        .astype("string")
        .str.strip()
        .str.upper()
    )

    b = (
        df[variable2]
        .astype("string")
        .str.strip()
        .str.upper()
    )

    comparables = (
        a.notna()
        &
        b.notna()
    )

    iguales = (
        comparables
        &
        (a == b)
    )

    print(
        f"Comparables: {int(comparables.sum())}"
    )

    print(
        f"Iguales: {int(iguales.sum())}"
    )

    if comparables.sum() > 0:

        print(
            f"Concordancia exacta: "
            f"{iguales.sum() / comparables.sum() * 100:.2f}%"
        )

    tabla = pd.crosstab(
        a.fillna("FALTANTE"),
        b.fillna("FALTANTE")
    )

    print()
    print(tabla.to_string())


# ============================================================
# 1. DESENLACE
# ============================================================

print()
print("#" * 60)
print("1. DESENLACE PRINCIPAL")
print("#" * 60)

distribucion(
    "MUERTE_FETAL"
)


# ============================================================
# 2. EDAD MATERNA
# ============================================================

print()
print("#" * 60)
print("2. EDAD MATERNA")
print("#" * 60)

if "EDAD_NUM" in df.columns:

    edad = pd.to_numeric(
        df["EDAD_NUM"],
        errors="coerce"
    )

    print(
        edad.describe(
            percentiles=[
                0.01,
                0.25,
                0.50,
                0.75,
                0.99
            ]
        ).to_string()
    )

distribucion(
    "EDAD_MATERNA_CATEGORIA"
)


# ============================================================
# 3. PAREJA / ESTADO CIVIL
# ============================================================

print()
print("#" * 60)
print("3. PAREJA ESTABLE Y ESTADO CIVIL")
print("#" * 60)

distribucion(
    "PAREJA_ESTABLE"
)

distribucion(
    "ESTADO_CIVIL"
)

concordancia(
    "PAREJA_ESTABLE",
    "ESTADO_CIVIL"
)


# ============================================================
# 4. SEGURO
# ============================================================

print()
print("#" * 60)
print("4. SEGURO")
print("#" * 60)

distribucion(
    "SEGURO"
)


# ============================================================
# 5. GRUPO CULTURAL / ETNIA
# ============================================================

print()
print("#" * 60)
print("5. GRUPO CULTURAL Y ETNIA MINORITARIA")
print("#" * 60)

distribucion(
    "GRUPO_CULTURAL",
    50
)

distribucion(
    "ETNIA_MINORITARIA",
    50
)


# ============================================================
# 6. RIESGO / SCORE MAMA
# ============================================================

print()
print("#" * 60)
print("6. RIESGO Y SCORE MAMA")
print("#" * 60)

for variable in [
    "RIESGO_AL_INGRESO",
    "SCORE_NUM",
    "RIESGO",
    "SCORE_1_NUM"
]:
    distribucion(
        variable,
        50
    )


concordancia(
    "RIESGO_AL_INGRESO",
    "RIESGO"
)


# Score numerico
if (
    "SCORE_NUM" in df.columns
    and
    "SCORE_1_NUM" in df.columns
):

    s1 = pd.to_numeric(
        df["SCORE_NUM"],
        errors="coerce"
    )

    s2 = pd.to_numeric(
        df["SCORE_1_NUM"],
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

    print()
    print("=" * 60)
    print("SCORE MAMA vs SCORE.1")
    print("=" * 60)

    print(
        f"Comparables: {int(comparables.sum())}"
    )

    print(
        f"Iguales: {int(iguales.sum())}"
    )

    if comparables.sum() > 0:

        print(
            f"Concordancia exacta: "
            f"{iguales.sum() / comparables.sum() * 100:.2f}%"
        )


# ============================================================
# 7. TRASTORNOS HIPERTENSIVOS
# ============================================================

print()
print("#" * 60)
print("7. HIPERTENSIVOS")
print("#" * 60)

distribucion(
    "HIPERTENSIVOS",
    50
)

distribucion(
    "HIPERTENSION_BINARIA"
)


# ============================================================
# 8. PRESENTACION FETAL
# ============================================================

print()
print("#" * 60)
print("8. PRESENTACION FETAL")
print("#" * 60)

distribucion(
    "PRESENTACION_FETAL",
    50
)

distribucion(
    "PRESENTACION_CEFALICA"
)


# ============================================================
# 9. POSICION DEL PARTO
# ============================================================

print()
print("#" * 60)
print("9. POSICION DEL PARTO")
print("#" * 60)

distribucion(
    "POSICION_DEL_PARTO",
    50
)


# ============================================================
# 10. PESO
# ============================================================

print()
print("#" * 60)
print("10. PESO")
print("#" * 60)

for variable in [
    "PESO_NUM",
    "PESO_AL_NACIMIENTO_NUM"
]:

    if variable not in df.columns:
        continue

    serie = pd.to_numeric(
        df[variable],
        errors="coerce"
    )

    print()
    print(variable)

    print(
        f"Disponibles: {int(serie.notna().sum())}"
    )

    print(
        f"Faltantes: {int(serie.isna().sum())}"
    )

    if serie.notna().sum() > 0:

        print(
            serie.describe(
                percentiles=[
                    0.01,
                    0.25,
                    0.50,
                    0.75,
                    0.99
                ]
            ).to_string()
        )


# ============================================================
# 11. EDAD GESTACIONAL
# ============================================================

print()
print("#" * 60)
print("11. EDAD GESTACIONAL")
print("#" * 60)

if "SEMANAS_GESTACION_NUM" in df.columns:

    semanas = pd.to_numeric(
        df["SEMANAS_GESTACION_NUM"],
        errors="coerce"
    )

    print(
        semanas.describe(
            percentiles=[
                0.01,
                0.25,
                0.50,
                0.75,
                0.99
            ]
        ).to_string()
    )

distribucion(
    "EDAD_GESTACIONAL_CATEGORIA",
    30
)


# ============================================================
# 12. INFECCIONES
# ============================================================

print()
print("#" * 60)
print("12. INFECCIONES MATERNAS")
print("#" * 60)

for variable in [
    "INFECCION_GENITAL",
    "IVU",
    "TORCH",
    "ITS",
    "CUALQUIER_INFECCION_MATERNA"
]:

    distribucion(
        variable
    )


# ============================================================
# 13. COMPLICACIONES PLACENTARIAS
# ============================================================

print()
print("#" * 60)
print("13. PLACENTA")
print("#" * 60)

for variable in [
    "ALTERACION_PLACENTA",
    "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA"
]:

    distribucion(
        variable,
        50
    )


# ============================================================
# 14. RPM
# ============================================================

print()
print("#" * 60)
print("14. RPM")
print("#" * 60)

distribucion(
    "RPM"
)


# ============================================================
# 15. EMBARAZO MULTIPLE
# ============================================================

print()
print("#" * 60)
print("15. EMBARAZO MULTIPLE")
print("#" * 60)

distribucion(
    "EMBARAZO_MULTIPLE"
)

distribucion(
    "EMBARAZO_MULTIPLE_BINARIO"
)


# ============================================================
# 16. APGAR - SOLO VERIFICACION
# ============================================================

print()
print("#" * 60)
print("16. APGAR - RESULTADO POSTNATAL")
print("#" * 60)

for variable in [
    "APGAR_1_NUM",
    "APGAR_1_MENOR",
    "APGAR_2_NUM",
    "APGAR_5_MENOR"
]:

    distribucion(
        variable,
        20
    )


# ============================================================
# 17. RESUMEN DE VARIABLES CANDIDATAS PARA DAG
# ============================================================

roles = pd.DataFrame([
    ["EDAD_NUM", "PREEXPOSICION", "CANDIDATA_CONFOUNDING"],
    ["INSTRUCCION", "PREEXPOSICION", "CANDIDATA_CONFOUNDING"],
    ["SEGURO", "PREEXPOSICION", "CANDIDATA_CONTEXTUAL"],
    ["PAREJA_ESTABLE", "PREEXPOSICION", "AUDITAR"],
    ["GRUPO_CULTURAL", "PREEXPOSICION", "AUDITAR"],
    ["ETNIA_MINORITARIA", "PREEXPOSICION", "AUDITAR"],

    ["OBESIDAD", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["DIABETES_EN_EL_EMBARAZO", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["HIPERTENSION_BINARIA", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["ANEMIA", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["VIH", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["IVU", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["TORCH", "MATERNA", "EXPOSICION_CANDIDATA"],
    ["ITS", "MATERNA", "EXPOSICION_CANDIDATA"],

    ["NO_CONTROLES_NUM", "PRENATAL", "EXPOSICION_MEDIADOR_POSIBLE"],

    ["EMBARAZO_MULTIPLE_BINARIO", "EMBARAZO", "EXPOSICION_CANDIDATA"],
    ["PRESENTACION_CEFALICA", "OBSTETRICA", "EXPOSICION_CANDIDATA"],

    ["ALTERACION_PLACENTA", "COMPLICACION", "MEDIADOR_PROXIMAL_POSIBLE"],
    ["DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
     "COMPLICACION", "MEDIADOR_PROXIMAL_POSIBLE"],
    ["RPM", "COMPLICACION", "MEDIADOR_PROXIMAL_POSIBLE"],

    ["SEMANAS_GESTACION_NUM", "FETAL", "MEDIADOR_ELEGIBILIDAD"],
    ["PESO_NUM", "FETAL", "MEDIADOR_POSIBLE"],
    ["SEXO", "FETAL", "CANDIDATA"],

    ["RIESGO_AL_INGRESO", "COMPUESTA", "NO_AJUSTAR_AUTOMATICAMENTE"],
    ["SCORE_NUM", "SCORE_MAMA", "NO_AJUSTAR_AUTOMATICAMENTE"],

    ["MUERTE_FETAL", "OUTCOME", "DESENLACE"],

    ["APGAR_1_NUM", "POSTOUTCOME", "NO_DAG_CAUSAL"],
    ["APGAR_1_MENOR", "POSTOUTCOME", "NO_DAG_CAUSAL"],
    ["APGAR_2_NUM", "POSTOUTCOME", "NO_DAG_CAUSAL"],
    ["APGAR_5_MENOR", "POSTOUTCOME", "NO_DAG_CAUSAL"],
    ["REANIMACION", "POSTOUTCOME", "NO_DAG_CAUSAL"],
    ["LACTANCIA", "POSTOUTCOME", "NO_DAG_CAUSAL"],
    ["APEGO_PRECOZ", "POSTOUTCOME", "NO_DAG_CAUSAL"]
],
columns=[
    "VARIABLE",
    "TEMPORALIDAD",
    "ROL_PRELIMINAR_DAG"
])


roles.to_csv(
    REPORTES /
    "clasificacion_preliminar_dag.csv",
    index=False,
    encoding="utf-8-sig"
)


print()
print("#" * 60)
print("AUDITORIA TERMINADA")
print("#" * 60)

print(
    "No se modifico la base."
)

print(
    "Reporte DAG guardado en:"
)

print(
    "datos/reportes/clasificacion_preliminar_dag.csv"
)