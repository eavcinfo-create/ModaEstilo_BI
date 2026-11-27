# Databricks notebook source
# MAGIC %md
# MAGIC # Experimento Big Data: esquema inferido vs esquema declarado
# MAGIC Se leen los mismos CSV con `inferSchema` y con un esquema declarado (`StructType`), con 100, 500, 10 000,
# MAGIC 100 000 y 1 000 000 filas. Se mide el tiempo de lectura + cálculo del indicador y se revisa el tipo de dato
# MAGIC y la exactitud del total de importes.
# MAGIC
# MAGIC Requisito: haber subido `modaestilo_hechos.csv` a `/Volumes/workspace/moda/datos`.

# COMMAND ----------

# 1. Configuración
import time, statistics
from pyspark.sql import functions as F
from pyspark.sql.types import (StructType, StructField, StringType, LongType, IntegerType, DateType, DecimalType)

ruta = "/Volumes/workspace/moda/datos"
carpeta_exp = f"{ruta}/exp_esquema"
VOLUMENES = [100, 500, 10_000, 100_000, 1_000_000]
REPETICIONES = 3

# Esquema declarado: cada columna con su tipo correcto
esquema = StructType([
    StructField("tipo_operacion", StringType(), True),
    StructField("id_operacion", LongType(), True),
    StructField("id_detalle", LongType(), True),
    StructField("nro_documento", StringType(), True),
    StructField("fuente", StringType(), True),
    StructField("fecha", DateType(), True),
    StructField("id_cliente", IntegerType(), True),
    StructField("distrito", StringType(), True),
    StructField("id_trabajador", IntegerType(), True),
    StructField("cargo", StringType(), True),
    StructField("id_articulo", IntegerType(), True),
    StructField("articulo", StringType(), True),
    StructField("categoria", StringType(), True),
    StructField("canal", StringType(), True),
    StructField("cantidad", IntegerType(), True),
    StructField("precio_unitario", DecimalType(12, 2), True),
    StructField("importe", DecimalType(12, 2), True),
    StructField("estado", StringType(), True),
])

base = spark.read.format("csv").option("header", "true").schema(esquema).load(f"{ruta}/modaestilo_hechos.csv")
n_base = base.count()
print("Versión de Spark:", spark.version)
print("Filas base:", n_base)

# COMMAND ----------

# 2. Generar un CSV por volumen (copias de los datos reales con identificadores distintos)
for n in VOLUMENES:
    k = -(-n // n_base)                                         # copias necesarias
    df = (base.crossJoin(spark.range(k).withColumnRenamed("id", "copia"))
              .withColumn("id_operacion", F.col("id_operacion") + F.col("copia") * 1_000_000)
              .withColumn("id_detalle", F.col("id_detalle") + F.col("copia") * 1_000_000)
              .orderBy("copia", "id_detalle")
              .limit(n)
              .drop("copia"))
    (df.coalesce(1).write.mode("overwrite").option("header", "true")
       .csv(f"{carpeta_exp}/filas_{n}"))
    print("CSV generado:", n, "filas")

display(dbutils.fs.ls(carpeta_exp))

# COMMAND ----------

# 3. Funciones de lectura y medición
def leer_inferido(n):
    return (spark.read.format("csv").option("header", "true").option("inferSchema", "true")
            .load(f"{carpeta_exp}/filas_{n}"))

def leer_declarado(n):
    return (spark.read.format("csv").option("header", "true").schema(esquema)
            .load(f"{carpeta_exp}/filas_{n}"))

def indicador(df):
    """Ingreso por categoría y tipo de operación (obliga a leer todo el archivo)."""
    return df.groupBy("categoria", "tipo_operacion").agg(F.sum("importe").alias("ingreso")).collect()

def medir(lector, n):
    tiempos = []
    for _ in range(REPETICIONES):
        t0 = time.perf_counter()
        indicador(lector(n))                                    # lectura + inferencia (si hay) + cálculo
        tiempos.append(time.perf_counter() - t0)
    return statistics.median(tiempos), statistics.stdev(tiempos)

# COMMAND ----------

# 4. Ejecución del experimento
RESULTADOS = []
for n in VOLUMENES:
    t_inf, d_inf = medir(leer_inferido, n)
    t_dec, d_dec = medir(leer_declarado, n)

    di, dd = leer_inferido(n), leer_declarado(n)
    tipos = dict(di.dtypes)
    total_inf = di.agg(F.sum("importe")).collect()[0][0]         # suma con el tipo inferido
    total_dec = dd.agg(F.sum("importe")).collect()[0][0]         # suma con DECIMAL(12,2): exacta

    RESULTADOS.append({
        "filas": n,
        "inferido_s": round(t_inf, 3), "inferido_desv": round(d_inf, 3),
        "declarado_s": round(t_dec, 3), "declarado_desv": round(d_dec, 3),
        "diferencia_pct": round((t_inf - t_dec) / t_inf * 100, 1),
        "tipo_fecha_inferido": tipos["fecha"], "tipo_importe_inferido": tipos["importe"],
        "tipo_id_inferido": tipos["id_detalle"],
        "total_inferido": repr(float(total_inf)),                  # se ve el redondeo del tipo double
        "total_declarado": str(total_dec),
        "diferencia_total": float(total_inf) - float(total_dec),
    })
    print(RESULTADOS[-1])

# COMMAND ----------

# 5. Bitácora de resultados (tabla Delta)
bitacora = spark.createDataFrame(RESULTADOS).select(
    "filas", "inferido_s", "inferido_desv", "declarado_s", "declarado_desv", "diferencia_pct",
    "tipo_fecha_inferido", "tipo_importe_inferido", "tipo_id_inferido",
    "total_inferido", "total_declarado", "diferencia_total")
bitacora.write.mode("overwrite").saveAsTable("workspace.moda.bitacora_exp_esquema")
display(bitacora.orderBy("filas"))

# COMMAND ----------

# MAGIC %sql
# MAGIC -- 6. Gráfico de líneas: X filas (escala logarítmica), Y inferido_s y declarado_s
# MAGIC SELECT filas, inferido_s, declarado_s
# MAGIC FROM workspace.moda.bitacora_exp_esquema
# MAGIC ORDER BY filas

# COMMAND ----------

# 7. Esquemas obtenidos con el volumen más grande
leer_inferido(VOLUMENES[-1]).printSchema()
leer_declarado(VOLUMENES[-1]).printSchema()
