# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "6"
# ///
# MAGIC %md
# MAGIC # Experimentos Big Data - ModaEstilo (Grupo 8)
# MAGIC
# MAGIC
# MAGIC | Exp | Pregunta | Variable independiente | Metrica |
# MAGIC |---|---|---|---|
# MAGIC | BD-01 | ¿Como escala el tiempo con el volumen? | Filas (K) | tiempo, filas/s |
# MAGIC | BD-02 | ¿Que formato conviene? | CSV / Parquet / Delta | tiempo lectura, MB |
# MAGIC | BD-03 | ¿Particionar reduce el tiempo? | partitionBy(anio) | tiempo, archivos leidos |
# MAGIC | BD-04 | ¿Broadcast vs sort-merge join? | estrategia de join | tiempo, plan |
# MAGIC | BD-05 | ¿Que tan bien limpia Bronze->Silver? | % suciedad inyectada | error del KPI |

# COMMAND ----------

import time, statistics, datetime, json
from pyspark.sql import functions as F

# ---- CONFIGURACION (editar) --------------------------------------------------
VOLUME   = "/Volumes/workspace/default/moda"      # carpeta donde subieron los CSV
RESPONSABLE = "<<Eduardo_Velasquez>>"
SCALES   = [1, 1000, 10000, 100000]               # x701 filas; reducir si el cluster no aguanta
REPS     = 5                                      # repeticiones por medicion (1 calentamiento aparte)
REF      = {"VENTA": 92784.70, "ALQUILER": 44131.00}   # referencia validada contra SQL (K=1)
RESULTS  = []                                     # bitacora de ejecuciones

def entorno():
    return dict(fecha=str(datetime.datetime.now()), spark=spark.version,
                compute="serverless", responsable=RESPONSABLE)
print(entorno())

def medir(nombre, fn, reps=REPS, **meta):
    """Ejecuta fn() 1 vez de calentamiento + reps veces; guarda mediana y desviacion."""
    fn()
    ts = []
    for _ in range(reps):
        t = time.perf_counter(); fn(); ts.append(time.perf_counter() - t)
    r = dict(experimento=nombre, mediana_s=round(statistics.median(ts), 3),
             desv_s=round(statistics.pstdev(ts), 3), min_s=round(min(ts), 3), max_s=round(max(ts), 3), **meta)
    RESULTS.append(r); print(r); return r

def ejecutar(df):                      # fuerza la ejecucion sin traer datos al driver
    df.write.format("noop").mode("overwrite").save()

# COMMAND ----------

# MAGIC %md ## Carga del dataset original

# COMMAND ----------

hechos = (spark.read.option("header", True).option("inferSchema", True)
          .csv(f"{VOLUME}/modaestilo_hechos_base.csv"))
pagos  = (spark.read.option("header", True).option("inferSchema", True)
          .csv(f"{VOLUME}/modaestilo_pagos_base.csv"))
hechos = hechos.withColumn("fecha", F.to_date("fecha")).withColumn("anio", F.year("fecha")) \
               .withColumn("mes", F.month("fecha"))
print("filas hechos:", hechos.count(), "| filas pagos:", pagos.count())
hechos.printSchema()
hechos.describe("cantidad", "precio_unitario", "importe").show()
# Validacion contra referencia SQL (debe coincidir exactamente)
chk = hechos.groupBy("tipo_operacion").agg(F.round(F.sum("importe"), 2).alias("total")).collect()
for r in chk:
    assert abs(r["total"] - REF[r["tipo_operacion"]]) < 0.01, (r["tipo_operacion"], r["total"])
print("Validacion K=1 OK:", {r["tipo_operacion"]: r["total"] for r in chk})

# COMMAND ----------

# MAGIC %md ## Generador de escala (replica determinista; sin datos aleatorios)

# COMMAND ----------

OFFSET = 1_000_000          # separa los id_operacion de cada replica

def escalar(df, K, cols_id=("id_operacion", "id_detalle")):
    if K == 1:
        return df
    out = df.crossJoin(spark.range(K).withColumnRenamed("id", "k"))
    for c in cols_id:
        out = out.withColumn(c, F.col(c) + F.col("k") * F.lit(OFFSET))
    return out.drop("k")

# COMMAND ----------

# MAGIC %md ## BD-01 Escalabilidad: mismo job sobre volumen creciente
# MAGIC **Motivo:** Se evalua como responde la solucion al crecer el volumen (seccion 3.5.4).

# COMMAND ----------

def job_kpi(df):
    return (df.groupBy("categoria", "anio", "mes", "tipo_operacion")
              .agg(F.sum("importe").alias("ingreso"), F.sum("cantidad").alias("unidades"),
                   F.countDistinct("id_operacion").alias("operaciones")))

for K in SCALES:
    d = escalar(hechos, K)
    n = d.count()
    r = medir("BD-01", lambda: ejecutar(job_kpi(d)), K=K, filas=n)
    r["filas_por_s"] = int(n / r["mediana_s"])
    # exactitud: el total debe ser exactamente K * referencia
    tot = d.groupBy("tipo_operacion").agg(F.round(F.sum("importe"), 2).alias("t")).collect()
    r["exacto"] = all(abs(x["t"] - REF[x["tipo_operacion"]] * K) < 0.01 * K for x in tot)
    print("  filas/s:", r["filas_por_s"], "| total exacto:", r["exacto"])

# COMMAND ----------

# MAGIC %md ## BD-02 Formato de almacenamiento: CSV vs Parquet vs Delta
# MAGIC **Motivo:** Se define cuanto se lee del disco; columnar + compresion deberia reducir MB y tiempo.

# COMMAND ----------

K2 = SCALES[2]
base = escalar(hechos, K2)
rutas = {"csv": f"{VOLUME}/exp/f_csv", "parquet": f"{VOLUME}/exp/f_parquet", "delta": f"{VOLUME}/exp/f_delta"}
base.write.mode("overwrite").option("header", True).csv(rutas["csv"])
base.write.mode("overwrite").parquet(rutas["parquet"])
base.write.mode("overwrite").format("delta").save(rutas["delta"])

def tam_mb(p):
    def rec(path):
        t = 0
        for f in dbutils.fs.ls(path):
            t += rec(f.path) if f.isDir() else f.size
        return t
    return round(rec(p) / 1e6, 2)

def leer(fmt):
    if fmt == "csv":
        return spark.read.option("header", True).option("inferSchema", True).csv(rutas[fmt])
    return spark.read.format(fmt).load(rutas[fmt])

for fmt in ["csv", "parquet", "delta"]:
    medir("BD-02", lambda f=fmt: ejecutar(job_kpi(leer(f))), formato=fmt, K=K2, mb_disco=tam_mb(rutas[fmt]))

# COMMAND ----------

# MAGIC %md ## BD-03 Particionamiento: partitionBy(anio) y poda de particiones
# MAGIC **Motivo:** Si la consulta filtra por anio (año), Spark solo deberia leer la carpeta de ese anio.

# COMMAND ----------

p_plano = f"{VOLUME}/exp/p_plano"; p_part = f"{VOLUME}/exp/p_part"
base.write.mode("overwrite").parquet(p_plano)
base.write.mode("overwrite").partitionBy("anio").parquet(p_part)

def consulta_2025(path):
    return (spark.read.parquet(path).filter(F.col("anio") == 2025)
            .groupBy("categoria").agg(F.sum("importe").alias("ingreso")))

for nombre, ruta in [("sin_particion", p_plano), ("partitionBy_anio", p_part)]:
    medir("BD-03", lambda r=ruta: ejecutar(consulta_2025(r)), variante=nombre, K=K2)
    print(nombre); consulta_2025(ruta).explain()      # buscar PartitionFilters / numero de archivos leidos

# COMMAND ----------

# MAGIC %md ## BD-04 Estrategia de join: broadcast vs sort-merge (+ shuffle partitions)
# MAGIC **Motivo:** Como la dimensión articulo es diminuta; difundirla evita el shuffle del hecho grande.

# COMMAND ----------

dim_art = hechos.select("id_articulo", "articulo", "categoria").distinct()
f_big = escalar(hechos.drop("articulo", "categoria"), K2)

def join_broadcast():
    return f_big.join(F.broadcast(dim_art), "id_articulo").groupBy("categoria").agg(F.sum("importe"))
def join_merge():
    return f_big.join(dim_art.hint("merge"), "id_articulo").groupBy("categoria").agg(F.sum("importe"))

for nombre, fn in [("broadcast", join_broadcast), ("sort_merge", join_merge)]:
    medir("BD-04", lambda f=fn: ejecutar(f()), variante=nombre, K=K2)
    fn().explain()

# Barrido de spark.sql.shuffle.partitions (puede estar restringido en serverless: se omite si falla)
for sp in [8, 64, 200, 800]:
    try:
        spark.conf.set("spark.sql.shuffle.partitions", sp)
        medir("BD-04", lambda: ejecutar(join_merge()), variante=f"shuffle_partitions={sp}", K=K2)
    except Exception as e:
        print("Config no permitida en este compute:", e); break

# COMMAND ----------

# MAGIC %md ## BD-05 Calidad: Bronze -> Silver -> Gold con suciedad inyectada
# MAGIC **Motivo:** El experimento exige demostrar limpieza real, no solo cargar datos.

# COMMAND ----------

def inyectar_suciedad(df, p_null=0.02, p_dup=0.01, p_neg=0.01, seed=42):
    r = F.rand(seed)
    sucio = (df.withColumn("importe", F.when(r < p_null, F.lit(None)).otherwise(F.col("importe")))
               .withColumn("cantidad", F.when(F.rand(seed + 1) < p_neg, -F.col("cantidad")).otherwise(F.col("cantidad"))))
    dups = df.sample(False, p_dup, seed + 2)
    return sucio.unionByName(dups)

K5 = SCALES[1]
bronze = inyectar_suciedad(escalar(hechos, K5))
bronze.write.mode("overwrite").format("delta").save(f"{VOLUME}/exp/bronze")

def a_silver(b):
    return (b.dropDuplicates(["tipo_operacion", "id_detalle"])
             .filter(F.col("importe").isNotNull() & (F.col("cantidad") > 0) & (F.col("importe") >= 0))
             .withColumn("importe", F.round("importe", 2)))

silver = a_silver(spark.read.format("delta").load(f"{VOLUME}/exp/bronze"))
silver.write.mode("overwrite").format("delta").save(f"{VOLUME}/exp/silver")
gold = (silver.groupBy("categoria", "anio", "mes", "tipo_operacion")
              .agg(F.sum("importe").alias("ingreso"), F.countDistinct("id_operacion").alias("operaciones")))
gold.write.mode("overwrite").format("delta").save(f"{VOLUME}/exp/gold")

nb, ns = bronze.count(), silver.count()
ref_total = sum(REF.values()) * K5
tot_b = bronze.agg(F.sum("importe")).first()[0]
tot_s = silver.agg(F.sum("importe")).first()[0]
cal = dict(experimento="BD-05", K=K5, filas_bronze=nb, filas_silver=ns, descartadas=nb - ns,
           total_ref=round(ref_total, 2), total_bronze=round(tot_b, 2), total_silver=round(tot_s, 2),
           error_bronze_pct=round(100 * (tot_b - ref_total) / ref_total, 3),
           error_silver_pct=round(100 * (tot_s - ref_total) / ref_total, 3))
RESULTS.append(cal); print(cal)
# Nota: Silver pierde las filas con importe nulo (2%): el error residual es esperable y debe
# discutirse (imputar desde cantidad*precio_unitario seria una mejora a probar).

# COMMAND ----------

# MAGIC %md ## Bitacora de resultados

# COMMAND ----------

res_df = spark.createDataFrame([json.loads(json.dumps(r, default=str)) for r in RESULTS])
display(res_df)
res_df.toPandas().to_csv(f"{VOLUME}/exp/resultados_bigdata_{RESPONSABLE}.csv", index=False)

# COMMAND ----------

import pandas as pd
bd01 = pd.DataFrame([r for r in RESULTS if r["experimento"] == "BD-01"])
bd01 = bd01[["filas", "mediana_s", "desv_s", "filas_por_s"]]
display(bd01)