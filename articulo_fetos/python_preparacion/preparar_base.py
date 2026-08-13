import pandas as pd
import numpy as np
import re
import unicodedata
from pathlib import Path


# ============================================================
# 1. CONFIGURACION DE CARPETAS
# ============================================================

CARPETA_ORIGINAL = Path("datos/originales")
CARPETA_PROCESADOS = Path("datos/procesados")
CARPETA_REPORTES = Path("datos/reportes")

CARPETA_PROCESADOS.mkdir(parents=True, exist_ok=True)
CARPETA_REPORTES.mkdir(parents=True, exist_ok=True)


# ============================================================
# 2. LOCALIZAR AUTOMATICAMENTE EL CSV ORIGINAL
# ============================================================

archivos_csv = list(CARPETA_ORIGINAL.glob("*.csv"))

if len(archivos_csv) == 0:
    raise FileNotFoundError(
        "No se encontro ningun archivo CSV dentro de datos/originales/"
    )

if len(archivos_csv) > 1:
    raise RuntimeError(
        "Hay mas de un CSV dentro de datos/originales/. "
        "Deja solamente la base original que quieres procesar."
    )

archivo = archivos_csv[0]

print("\n======================================")
print("ARCHIVO ENCONTRADO")
print("======================================")
print(archivo.name)


# ============================================================
# 3. CARGAR LA BASE ORIGINAL
# ============================================================

df = pd.read_csv(
    archivo,
    sep=";",
    encoding="latin1",
    dtype="string"
)

filas_originales = len(df)
columnas_originales = len(df.columns)

print(f"\nFilas originales: {filas_originales}")
print(f"Columnas originales: {columnas_originales}")


# ============================================================
# 4. CREAR IDENTIFICADOR TECNICO INTERNO
#
# No utiliza cedula ni historia clinica.
# ============================================================

df.insert(
    0,
    "ID_REGISTRO",
    range(1, len(df) + 1)
)


# ============================================================
# 5. NORMALIZAR NOMBRES DE COLUMNAS
# ============================================================

def normalizar_nombre_columna(nombre):

    nombre = str(nombre).strip()

    nombre = unicodedata.normalize(
        "NFKD",
        nombre
    )

    nombre = "".join(
        caracter
        for caracter in nombre
        if not unicodedata.combining(caracter)
    )

    nombre = nombre.upper()

    nombre = re.sub(
        r"[^A-Z0-9]+",
        "_",
        nombre
    )

    nombre = re.sub(
        r"_+",
        "_",
        nombre
    )

    return nombre.strip("_")


df.columns = [
    normalizar_nombre_columna(columna)
    for columna in df.columns
]


# ============================================================
# 6. LIMPIEZA GENERAL DE TEXTO
# ============================================================

for columna in df.columns:

    if columna == "ID_REGISTRO":
        continue

    df[columna] = (
        df[columna]
        .astype("string")
        .str.strip()
        .str.replace(
            r"\s+",
            " ",
            regex=True
        )
    )


# ============================================================
# 7. NORMALIZAR VALORES FALTANTES
#
# Importante:
# un valor faltante NO se transforma en "NO".
# ============================================================

valores_faltantes = {
    "",
    "NA",
    "N/A",
    "N.A.",
    "NAN",
    "NULL",
    "NONE",
    "S/D",
    "SD",
    "S D",
    "SIN DATO",
    "SIN DATOS",
    "NO REGISTRA",
    "NO REGISTRADO",
    "NO REGISTRADA",
    "NO CONSTA",
    "DESCONOCIDO",
    "DESCONOCIDA"
}


def limpiar_faltante(valor):

    if pd.isna(valor):
        return pd.NA

    texto = str(valor).strip()

    if texto.upper() in valores_faltantes:
        return pd.NA

    return texto


for columna in df.columns:

    if columna == "ID_REGISTRO":
        continue

    df[columna] = df[columna].map(
        limpiar_faltante
    )


# ============================================================
# 8. PASAR TEXTO A MAYUSCULAS
# ============================================================

for columna in df.columns:

    if columna == "ID_REGISTRO":
        continue

    df[columna] = df[columna].map(
        lambda x:
        str(x).strip().upper()
        if pd.notna(x)
        else pd.NA
    )


# ============================================================
# 9. UNIFORMIZAR ACOMPAÑAMIENTO
#
# ESPOSO/PAREJA, ESPOSO, CONYUGE y PAREJA
# significan la misma categoria analitica: PAREJA
# ============================================================

if "ACOMPANADA" in df.columns:

    mapa_acompanada = {
        "ESPOSO/PAREJA": "PAREJA",
        "ESPOSO / PAREJA": "PAREJA",
        "ESPOSO": "PAREJA",
        "PAREJA": "PAREJA",
        "CONYUGE": "PAREJA",
        "CÓNYUGE": "PAREJA"
    }

    df["ACOMPANADA"] = df["ACOMPANADA"].map(
        lambda x:
        mapa_acompanada.get(x, x)
        if pd.notna(x)
        else pd.NA
    )


# ============================================================
# 10. NORMALIZAR SI / NO
#
# Solo sobre variables documentadas que razonablemente
# pueden ser binarias.
# ============================================================

mapa_si_no = {
    "SI": "SI",
    "SÍ": "SI",
    "S": "SI",
    "YES": "SI",

    "NO": "NO",
    "N": "NO"
}


columnas_binarias = [
    "PAREJA_ESTABLE",
    "ANTECEDENTE_DE_CIRUGIA_UTERINA",
    "ANOMALIAS_GENITALES",
    "VIH",
    "OBESIDAD",
    "DIABETES_EN_EL_EMBARAZO",
    "DESPRENDIMIENTO_PREMATURO_DE_PLACENTA",
    "ANEMIA",
    "ALTERACION_PLACENTA",
    "ISOINMUNIZACION",
    "INFECCION_GENITAL",
    "IVU",
    "TORCH",
    "ITS",
    "RUPTURA_UTERINA",
    "ALTERACIONES_DEL_CORDON",
    "PARTO_PROLONGADO",
    "PARTO_PRECIPITADO",
    "SUFRIMIENTO_FETAL",
    "RPM",
    "PSICOPROFILAXIS",
    "EPISIOTOMIA",
    "MANEJO_ACTIVO",
    "SOLICITO_PLACENTA",
    "HEMORRAGIA",
    "LIGADURA",
    "REANIMACION",
    "APEGO_PRECOZ",
    "LACTANCIA",
    "CONSEJERIA_ANTICONCEPCION"
]


for columna in columnas_binarias:

    if columna in df.columns:

        df[columna] = df[columna].map(
            lambda x:
            mapa_si_no.get(x, x)
            if pd.notna(x)
            else pd.NA
        )


# ============================================================
# 11. EMBARAZO MULTIPLE
# ============================================================

if "EMBARAZO_MULTIPLE" in df.columns:

    mapa_embarazo_multiple = {
        "NO": 1,
        "UNICO": 1,
        "ÚNICO": 1,

        "DOBLE": 2,
        "GEMELAR": 2,
        "GEMELOS": 2,

        "TRIPLE": 3,
        "TRILLIZOS": 3,

        "CUADRUPLE": 4,
        "CUÁDRUPLE": 4
    }

    df["NUM_FETOS_ESPERADOS"] = (
        df["EMBARAZO_MULTIPLE"]
        .map(mapa_embarazo_multiple)
        .astype("Int64")
    )

else:

    df["NUM_FETOS_ESPERADOS"] = 1


# ============================================================
# 12. EXTRAER AÑO DE LAS FECHAS
#
# La fecha completa se conserva en la base de control.
# La base analitica utilizará principalmente el año.
# ============================================================

def extraer_anio(valor):

    if pd.isna(valor):
        return pd.NA

    texto = str(valor).strip()

    # Primero buscar un año completo 19xx o 20xx
    coincidencia = re.search(
        r"(19\d{2}|20\d{2})",
        texto
    )

    if coincidencia:
        return int(coincidencia.group(1))

    # Si la fecha termina en año de dos digitos
    partes = re.findall(
        r"\d+",
        texto
    )

    if len(partes) >= 3:

        ultimo = partes[-1]

        if len(ultimo) == 2:

            numero = int(ultimo)

            # Para esta base histórica:
            # 00-30 -> 2000-2030
            if numero <= 30:
                return 2000 + numero

            # 31-99 -> 1931-1999
            return 1900 + numero

    return pd.NA


mapa_fechas = {
    "FECHA_INGRESO":
        "ANIO_INGRESO",

    "FECHA_NACIMI_MADRE":
        "ANIO_NACIMIENTO_MADRE",

    "FECHA_NACIMIENTO":
        "ANIO_NACIMIENTO_FETO",

    "FECHA_DE_EGRESO":
        "ANIO_EGRESO"
}


for columna_fecha, columna_anio in mapa_fechas.items():

    if columna_fecha in df.columns:

        df[columna_anio] = (
            df[columna_fecha]
            .map(extraer_anio)
            .astype("Int64")
        )


# ============================================================
# 13. FUNCION GENERAL PARA CONVERTIR NUMEROS
#
# Acepta:
# 41
# 41,5
# 41.5
# 41 CM
#
# NO procesa valores separados por /
# ============================================================

def convertir_numero(valor):

    if pd.isna(valor):
        return np.nan

    texto = str(valor).strip()

    if "/" in texto:
        return np.nan

    texto = texto.replace(",", ".")

    coincidencia = re.search(
        r"-?\d+(?:\.\d+)?",
        texto
    )

    if coincidencia is None:
        return np.nan

    try:
        return float(
            coincidencia.group()
        )

    except ValueError:
        return np.nan


# ============================================================
# 14. VARIABLES NUMERICAS GENERALES
# ============================================================

variables_numericas_generales = [
    "EDAD",
    "SCORE",
    "NO_CONTROLES",
    "SESIONES",
    "SCORE_1"
]


for variable in variables_numericas_generales:

    if variable in df.columns:

        df[
            f"{variable}_NUM"
        ] = df[variable].map(
            convertir_numero
        )


# ============================================================
# 15. VARIABLES QUE PUEDEN CAMBIAR ENTRE FETOS
#
# Estas SI pueden estar separadas por /
# ============================================================

variables_por_feto = [
    "MUERTE_INTRAUTERINA",
    "SEXO",
    "PESO",
    "PESO_AL_NACIMIENTO",
    "TALLA",
    "P_CEFALICO",
    "REANIMACION",
    "PINZAMIENTO",
    "APEGO_PRECOZ",
    "LACTANCIA",
    "APGAR_1",
    "APGAR_1_MENOR",
    "APGAR_2",
    "APGAR_5_MENOR"
]


variables_por_feto = [
    variable
    for variable in variables_por_feto
    if variable in df.columns
]


# ============================================================
# 16. VARIABLES COMPARTIDAS POR TODO EL EMBARAZO
#
# Estas se pueden repetir correctamente en cada feto.
# ============================================================

variables_compartidas_embarazo = [
    "SEMANAS_GESTACION",
    "EDAD_GESTACIONAL_CATEGORIA"
]


variables_compartidas_embarazo = [
    variable
    for variable in variables_compartidas_embarazo
    if variable in df.columns
]


# ============================================================
# 17. DIVIDIR VALORES FETALES
# ============================================================

def dividir_valor_fetal(valor):

    if pd.isna(valor):
        return []

    texto = str(valor).strip()

    if "/" not in texto:
        return [texto]

    return [
        parte.strip()
        for parte in texto.split("/")
    ]


# ============================================================
# 18. CREAR BASE FETAL EN FORMATO LARGO
# ============================================================

filas_fetales = []
inconsistencias = []


for _, fila in df.iterrows():

    n_fetos = fila.get(
        "NUM_FETOS_ESPERADOS",
        1
    )

    if pd.isna(n_fetos):
        n_fetos = 1

    n_fetos = int(n_fetos)

    for numero_feto in range(
        1,
        n_fetos + 1
    ):

        nueva = {
            "ID_REGISTRO":
                fila["ID_REGISTRO"],

            "NUMERO_FETO":
                numero_feto,

            "NUM_FETOS_EMBARAZO":
                n_fetos
        }


        # ----------------------------------------------------
        # Variables maternas / obstetricas
        # ----------------------------------------------------

        columnas_excluir_copia = (
            variables_por_feto
            + variables_compartidas_embarazo
            + [
                "ID_REGISTRO",
                "NUM_FETOS_ESPERADOS"
            ]
        )

        for columna in df.columns:

            if columna in columnas_excluir_copia:
                continue

            nueva[columna] = fila[columna]


        # ----------------------------------------------------
        # Variables individuales de cada feto
        # ----------------------------------------------------

        for variable in variables_por_feto:

            valor = fila[variable]

            if pd.isna(valor):

                nueva[variable] = pd.NA
                continue

            partes = dividir_valor_fetal(
                valor
            )

            # Embarazo unico
            if n_fetos == 1:

                nueva[variable] = valor

            # Embarazo multiple bien desagregado
            elif len(partes) == n_fetos:

                nueva[variable] = (
                    partes[numero_feto - 1]
                )

            # Existe un valor unico o un numero incorrecto
            # de componentes.
            #
            # No se adivina a que feto corresponde.
            else:

                nueva[variable] = pd.NA

                inconsistencias.append({
                    "ID_REGISTRO":
                        fila["ID_REGISTRO"],

                    "TIPO_EMBARAZO":
                        fila.get(
                            "EMBARAZO_MULTIPLE",
                            pd.NA
                        ),

                    "NUM_FETOS_ESPERADOS":
                        n_fetos,

                    "VARIABLE":
                        variable,

                    "VALOR_ORIGINAL":
                        valor,

                    "NUM_COMPONENTES":
                        len(partes),

                    "MOTIVO":
                        "VARIABLE FETAL NO DESAGREGADA CORRECTAMENTE"
                })


        # ----------------------------------------------------
        # Variables compartidas por todos los fetos
        # ----------------------------------------------------

        for variable in variables_compartidas_embarazo:

            nueva[variable] = fila[
                variable
            ]


        filas_fetales.append(
            nueva
        )


fetal = pd.DataFrame(
    filas_fetales
)


# ============================================================
# 19. NORMALIZAR SEXO
# ============================================================

if "SEXO" in fetal.columns:

    mapa_sexo = {
        "M": "MASCULINO",
        "MASCULINO": "MASCULINO",
        "HOMBRE": "MASCULINO",

        "F": "FEMENINO",
        "FEMENINO": "FEMENINO",
        "MUJER": "FEMENINO"
    }

    fetal["SEXO"] = fetal["SEXO"].map(
        lambda x:
        mapa_sexo.get(x, x)
        if pd.notna(x)
        else pd.NA
    )


# ============================================================
# 20. CREAR VERSION NUMERICA DE VARIABLES FETALES
# ============================================================

variables_numericas_fetales = [
    "PESO",
    "PESO_AL_NACIMIENTO",
    "TALLA",
    "P_CEFALICO",
    "SEMANAS_GESTACION",
    "APGAR_1",
    "APGAR_1_MENOR",
    "APGAR_2",
    "APGAR_5_MENOR"
]


for variable in variables_numericas_fetales:

    if variable in fetal.columns:

        fetal[
            f"{variable}_NUM"
        ] = fetal[variable].map(
            convertir_numero
        )


# ============================================================
# 21. CREAR SEMANAS_GESTACION_NUM EN BASE DE EMBARAZOS
# ============================================================

if "SEMANAS_GESTACION" in df.columns:

    df[
        "SEMANAS_GESTACION_NUM"
    ] = df[
        "SEMANAS_GESTACION"
    ].map(
        convertir_numero
    )


# ============================================================
# 22. CREAR VARIABLES DERIVADAS EXPLICITAS
#
# No reemplazan las originales.
# ============================================================

if "EMBARAZO_MULTIPLE" in df.columns:

    df["EMBARAZO_MULTIPLE_BINARIO"] = (
        df["NUM_FETOS_ESPERADOS"]
        .map(
            lambda x:
            "NO"
            if pd.notna(x) and x == 1
            else (
                "SI"
                if pd.notna(x) and x > 1
                else pd.NA
            )
        )
    )


# ============================================================
# 23. DUPLICADOS EXACTOS
#
# No los eliminamos automaticamente.
# Se reportan para revision.
# ============================================================

columnas_comparacion = [
    columna
    for columna in df.columns
    if columna != "ID_REGISTRO"
]


mascara_grupos_duplicados = (
    df.duplicated(
        subset=columnas_comparacion,
        keep=False
    )
)


reporte_duplicados = df[
    mascara_grupos_duplicados
].copy()


reporte_duplicados.to_csv(
    CARPETA_REPORTES /
    "duplicados_exactos.csv",
    index=False,
    encoding="utf-8-sig"
)


duplicados_adicionales = int(
    df.duplicated(
        subset=columnas_comparacion,
        keep="first"
    ).sum()
)


filas_en_grupos_duplicados = int(
    mascara_grupos_duplicados.sum()
)


# ============================================================
# 24. REPORTE DE INCONSISTENCIAS DE EMBARAZOS MULTIPLES
# ============================================================

columnas_inconsistencia = [
    "ID_REGISTRO",
    "TIPO_EMBARAZO",
    "NUM_FETOS_ESPERADOS",
    "VARIABLE",
    "VALOR_ORIGINAL",
    "NUM_COMPONENTES",
    "MOTIVO"
]


if inconsistencias:

    reporte_inconsistencias = (
        pd.DataFrame(
            inconsistencias
        )
        .drop_duplicates()
    )

else:

    reporte_inconsistencias = (
        pd.DataFrame(
            columns=columnas_inconsistencia
        )
    )


reporte_inconsistencias.to_csv(
    CARPETA_REPORTES /
    "inconsistencias_embarazos_multiples.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 25. REPORTE DE DATOS FALTANTES
# ============================================================

reporte_faltantes = []


for columna in df.columns:

    numero_faltantes = int(
        df[columna]
        .isna()
        .sum()
    )

    porcentaje = round(
        numero_faltantes
        / len(df)
        * 100,
        2
    )

    reporte_faltantes.append({
        "VARIABLE":
            columna,

        "N_FALTANTES":
            numero_faltantes,

        "PORCENTAJE_FALTANTES":
            porcentaje
    })


reporte_faltantes = (
    pd.DataFrame(
        reporte_faltantes
    )
    .sort_values(
        "PORCENTAJE_FALTANTES",
        ascending=False
    )
)


reporte_faltantes.to_csv(
    CARPETA_REPORTES /
    "reporte_faltantes.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 26. REPORTE DE CATEGORIAS
# ============================================================

resumen_categorias = []


for columna in df.columns:

    if columna == "ID_REGISTRO":
        continue

    n_unicos = int(
        df[columna]
        .nunique(
            dropna=True
        )
    )

    resumen_categorias.append({
        "VARIABLE":
            columna,

        "N_CATEGORIAS_UNICAS":
            n_unicos
    })


pd.DataFrame(
    resumen_categorias
).to_csv(
    CARPETA_REPORTES /
    "resumen_variables.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 27. BASE DE CONTROL
#
# Conserva:
# - identificadores
# - fechas completas
# - datos originales uniformizados
#
# No usar directamente para tablas publicables.
# ============================================================

df.to_csv(
    CARPETA_PROCESADOS /
    "base_control_uniformizada.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 28. BASE ANALITICA DE EMBARAZOS
#
# Sin cedula, HC ni fechas exactas.
# Conserva los años.
# ============================================================

analitica_embarazos = df.copy()


columnas_privadas_o_fechas = [
    "CEDULA",
    "HC",
    "FECHA_INGRESO",
    "FECHA_NACIMI_MADRE",
    "FECHA_NACIMIENTO",
    "FECHA_DE_EGRESO"
]


analitica_embarazos = (
    analitica_embarazos.drop(
        columns=[
            columna
            for columna in columnas_privadas_o_fechas
            if columna in analitica_embarazos.columns
        ],
        errors="ignore"
    )
)


analitica_embarazos.to_csv(
    CARPETA_PROCESADOS /
    "base_analitica_embarazos.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 29. BASE ANALITICA FETAL
#
# Una fila = un feto esperado.
# ============================================================

analitica_fetal = fetal.copy()


analitica_fetal = (
    analitica_fetal.drop(
        columns=[
            columna
            for columna in columnas_privadas_o_fechas
            if columna in analitica_fetal.columns
        ],
        errors="ignore"
    )
)


analitica_fetal.to_csv(
    CARPETA_PROCESADOS /
    "base_analitica_fetal.csv",
    index=False,
    encoding="utf-8-sig"
)


# ============================================================
# 30. RESUMEN FINAL
# ============================================================

print()
print("======================================")
print("PROCESO COMPLETADO")
print("======================================")

print(
    f"Registros maternos/embarazos: "
    f"{len(df)}"
)

print(
    f"Registros en base fetal: "
    f"{len(fetal)}"
)


if "EMBARAZO_MULTIPLE" in df.columns:

    print()
    print("TIPOS DE EMBARAZO:")

    print(
        df[
            "EMBARAZO_MULTIPLE"
        ].value_counts(
            dropna=False
        )
    )


print()
print(
    f"Duplicados adicionales detectados: "
    f"{duplicados_adicionales}"
)

print(
    f"Filas pertenecientes a grupos duplicados: "
    f"{filas_en_grupos_duplicados}"
)

print(
    f"Inconsistencias fetales en multiples: "
    f"{len(reporte_inconsistencias)}"
)


print()
print("ARCHIVOS GENERADOS:")

print(
    "datos/procesados/"
    "base_control_uniformizada.csv"
)

print(
    "datos/procesados/"
    "base_analitica_embarazos.csv"
)

print(
    "datos/procesados/"
    "base_analitica_fetal.csv"
)

print(
    "datos/reportes/"
    "reporte_faltantes.csv"
)

print(
    "datos/reportes/"
    "duplicados_exactos.csv"
)

print(
    "datos/reportes/"
    "inconsistencias_embarazos_multiples.csv"
)

print(
    "datos/reportes/"
    "resumen_variables.csv"
)


print()
print("IMPORTANTE:")

print(
    "- No se realizaron imputaciones estadisticas."
)

print(
    "- Los faltantes no fueron convertidos automaticamente en NO."
)

print(
    "- ESPOSO/PAREJA fue uniformizado como PAREJA."
)

print(
    "- Las fechas exactas se conservaron solo en la base de control."
)

print(
    "- Las bases analiticas conservan las variables de año."
)

print(
    "- DIABETES_EN_EL_EMBARAZO y ETNIA_MINORITARIA "
    "se mantienen como variables documentadas independientes."
)

print(
    "- Los diferentes campos de atencion permanecen separados."
)

print(
    "- Los embarazos multiples se expandieron a una fila por feto."
)