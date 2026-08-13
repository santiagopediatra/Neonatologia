import pandas as pd
import numpy as np
from pathlib import Path


# ============================================================
# CONFIGURACION
# ============================================================

CARPETA_PROCESADOS = Path("datos/procesados")
CARPETA_REPORTES = Path("datos/reportes")

ARCHIVO_EMBARAZOS = (
    CARPETA_PROCESADOS /
    "base_analitica_embarazos.csv"
)

ARCHIVO_FETAL = (
    CARPETA_PROCESADOS /
    "base_analitica_fetal.csv"
)

ARCHIVO_DUPLICADOS = (
    CARPETA_REPORTES /
    "duplicados_exactos.csv"
)


# ============================================================
# CARGAR BASES
# ============================================================

embarazos = pd.read_csv(
    ARCHIVO_EMBARAZOS,
    low_memory=False
)

fetal = pd.read_csv(
    ARCHIVO_FETAL,
    low_memory=False
)

duplicados = pd.read_csv(
    ARCHIVO_DUPLICADOS,
    low_memory=False
)


print()
print("======================================")
print("CREACION DE BASE PREANALITICA")
print("======================================")

print(
    f"Embarazos antes de depuracion: "
    f"{len(embarazos)}"
)

print(
    f"Registros fetales antes: "
    f"{len(fetal)}"
)


# ============================================================
# 1. EXCLUIR LAS 649 FILAS DE RELLENO
#
# El grupo completo fue auditado:
# - 649 filas identicas
# - 62 campos vacios
# - sin informacion individual suficiente
# - valores predeterminados repetidos
#
# NO conservamos una fila porque no representa un registro
# clínico identificable.
# ============================================================

ids_relleno = set(
    pd.to_numeric(
        duplicados["ID_REGISTRO"],
        errors="coerce"
    )
    .dropna()
    .astype(int)
)


embarazos["ID_REGISTRO"] = pd.to_numeric(
    embarazos["ID_REGISTRO"],
    errors="coerce"
).astype("Int64")


fetal["ID_REGISTRO"] = pd.to_numeric(
    fetal["ID_REGISTRO"],
    errors="coerce"
).astype("Int64")


embarazos = embarazos[
    ~embarazos["ID_REGISTRO"].isin(
        ids_relleno
    )
].copy()


fetal = fetal[
    ~fetal["ID_REGISTRO"].isin(
        ids_relleno
    )
].copy()


# ============================================================
# 2. FUNCION PARA INVALIDAR SOLO LA VERSION NUMERICA
#
# El valor textual/original se mantiene.
# La variable *_NUM pasa a NA si esta fuera del rango
# conservador de control de calidad.
# ============================================================

correcciones = []


def validar_rango(
    df,
    variable,
    minimo,
    maximo,
    fuente
):

    if variable not in df.columns:
        return

    serie = pd.to_numeric(
        df[variable],
        errors="coerce"
    )

    mascara = (
        serie.notna()
        &
        (
            (serie < minimo)
            |
            (serie > maximo)
        )
    )

    for indice in df.index[mascara]:

        correcciones.append({
            "FUENTE":
                fuente,

            "ID_REGISTRO":
                df.loc[
                    indice,
                    "ID_REGISTRO"
                ],

            "VARIABLE":
                variable,

            "VALOR_INVALIDADO":
                serie.loc[indice],

            "MIN_CONTROL":
                minimo,

            "MAX_CONTROL":
                maximo,

            "ACCION":
                "CONVERTIDO_A_NA_EN_VARIABLE_NUMERICA"
        })

    # Solo modificamos la version numerica analitica
    df.loc[
        mascara,
        variable
    ] = np.nan


# ============================================================
# 3. EDAD MATERNA
# ============================================================

validar_rango(
    embarazos,
    "EDAD_NUM",
    10,
    55,
    "EMBARAZO"
)


# ============================================================
# 4. NUMERO DE CONTROLES
#
# No imponemos maximo clinico arbitrario.
# Solo valores negativos son imposibles.
# ============================================================

if "NO_CONTROLES_NUM" in embarazos.columns:

    controles = pd.to_numeric(
        embarazos["NO_CONTROLES_NUM"],
        errors="coerce"
    )

    mascara = (
        controles.notna()
        &
        (controles < 0)
    )

    embarazos.loc[
        mascara,
        "NO_CONTROLES_NUM"
    ] = np.nan


# ============================================================
# 5. SEMANAS DE GESTACION
# ============================================================

validar_rango(
    fetal,
    "SEMANAS_GESTACION_NUM",
    15,
    45,
    "FETAL"
)


# ============================================================
# 6. PESO
# ============================================================

validar_rango(
    fetal,
    "PESO_NUM",
    100,
    7000,
    "FETAL"
)


if "PESO_AL_NACIMIENTO_NUM" in fetal.columns:

    validar_rango(
        fetal,
        "PESO_AL_NACIMIENTO_NUM",
        100,
        7000,
        "FETAL"
    )


# ============================================================
# 7. TALLA
# ============================================================

validar_rango(
    fetal,
    "TALLA_NUM",
    20,
    65,
    "FETAL"
)


# ============================================================
# 8. PERIMETRO CEFALICO
# ============================================================

validar_rango(
    fetal,
    "P_CEFALICO_NUM",
    15,
    45,
    "FETAL"
)


# ============================================================
# 9. APGAR
#
# Escala valida 0-10.
# ============================================================

variables_apgar = [
    "APGAR_1_NUM",
    "APGAR_1_MENOR_NUM",
    "APGAR_2_NUM",
    "APGAR_5_MENOR_NUM"
]


for variable in variables_apgar:

    validar_rango(
        fetal,
        variable,
        0,
        10,
        "FETAL"
    )


# ============================================================
# 10. GUARDAR REPORTE DE VALORES INVALIDADOS
# ============================================================

reporte_correcciones = pd.DataFrame(
    correcciones
)


reporte_correcciones.to_csv(
    CARPETA_REPORTES /
    "valores_invalidos_convertidos_a_na.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 11. CREAR BANDERA DE DATO FETAL INCOMPLETO EN MULTIPLES
# ============================================================

variables_fetales_clave = [
    "SEXO",
    "PESO_NUM",
    "TALLA_NUM",
    "P_CEFALICO_NUM",
    "APGAR_1_NUM",
    "APGAR_2_NUM"
]


variables_fetales_clave = [
    v
    for v in variables_fetales_clave
    if v in fetal.columns
]


if variables_fetales_clave:

    fetal[
        "DATO_FETAL_INCOMPLETO"
    ] = (
        fetal[
            variables_fetales_clave
        ]
        .isna()
        .any(axis=1)
        .map({
            True: "SI",
            False: "NO"
        })
    )


# ============================================================
# 12. NO IMPUTAR VARIABLES CLINICAS
#
# Importante:
# - no imputamos SEXO
# - no imputamos PESO
# - no imputamos APGAR
# - no imputamos MUERTE INTRAUTERINA
# - no imputamos diabetes
# - no imputamos hipertension
# - no imputamos etnia
#
# Esto se decidira despues segun el modelo analitico.
# ============================================================


# ============================================================
# 13. REPORTE FINAL DE FALTANTES
# ============================================================

def reporte_faltantes(
    df,
    fuente
):

    resultado = []

    for variable in df.columns:

        n = int(
            df[variable]
            .isna()
            .sum()
        )

        resultado.append({
            "FUENTE":
                fuente,

            "VARIABLE":
                variable,

            "N":
                len(df),

            "FALTANTES":
                n,

            "PORCENTAJE_FALTANTES":
                round(
                    n / len(df) * 100,
                    2
                )
        })

    return pd.DataFrame(
        resultado
    )


faltantes_embarazos = reporte_faltantes(
    embarazos,
    "EMBARAZOS"
)

faltantes_fetal = reporte_faltantes(
    fetal,
    "FETAL"
)


reporte_final_faltantes = pd.concat(
    [
        faltantes_embarazos,
        faltantes_fetal
    ],
    ignore_index=True
)


reporte_final_faltantes.to_csv(
    CARPETA_REPORTES /
    "faltantes_base_preanalitica.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 14. GUARDAR BASES PREANALITICAS
# ============================================================

archivo_embarazos_final = (
    CARPETA_PROCESADOS /
    "cohorte_embarazos_preanalitica.csv"
)

archivo_fetal_final = (
    CARPETA_PROCESADOS /
    "cohorte_fetal_preanalitica.csv"
)


embarazos.to_csv(
    archivo_embarazos_final,
    index=False,
    encoding="utf-8-sig"
)


fetal.to_csv(
    archivo_fetal_final,
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 15. RESUMEN
# ============================================================

print()
print("======================================")
print("PROCESO TERMINADO")
print("======================================")

print(
    f"Filas de relleno excluidas: "
    f"{len(ids_relleno)}"
)

print(
    f"Embarazos finales: "
    f"{len(embarazos)}"
)

print(
    f"Registros fetales finales: "
    f"{len(fetal)}"
)

print(
    f"Valores numericos fuera de rango "
    f"convertidos a NA: "
    f"{len(reporte_correcciones)}"
)

print()
print("BASES RESULTANTES:")

print(
    "datos/procesados/"
    "cohorte_embarazos_preanalitica.csv"
)

print(
    "datos/procesados/"
    "cohorte_fetal_preanalitica.csv"
)

print()
print("REPORTES:")

print(
    "datos/reportes/"
    "valores_invalidos_convertidos_a_na.csv"
)

print(
    "datos/reportes/"
    "faltantes_base_preanalitica.csv"
)

print()
print("IMPORTANTE:")

print(
    "- Los valores originales no fueron inventados."
)

print(
    "- Los valores numericos implausibles se conservaron "
    "en las columnas originales y se marcaron como NA "
    "solo en las variables numericas de analisis."
)

print(
    "- No se realizo imputacion estadistica."
)