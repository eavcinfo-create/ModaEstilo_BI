# Databricks notebook source
# MAGIC %md
# MAGIC # Solución Big Data – ModaEstilo
# MAGIC Datos: `modaestilo_hechos.csv` (ventas y alquileres) y `modaestilo_devoluciones.csv`, exportados del OLAP **ModaEstilo_DW**.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parte 1. Esquema y volumen

# COMMAND ----------

spark.sql("CREATE SCHEMA IF NOT EXISTS workspace.moda")
spark.sql("CREATE VOLUME IF NOT EXISTS workspace.moda.datos")
ruta = "/Volumes/workspace/moda/datos"
display(dbutils.fs.ls(ruta))     # aquí deben estar los 2 CSV

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parte 2. Lectura de los CSV en DataFrames de Spark (capa Bronze)

# COMMAND ----------

dfHechos = (spark.read
  .format("csv")
  .option("header", "true")
  .option("inferSchema", "true")
  .load(f"{ruta}/modaestilo_hechos.csv"))

dfDevol = (spark.read
  .format("csv")
  .option("header", "true")
  .option("inferSchema", "true")
  .load(f"{ruta}/modaestilo_devoluciones.csv"))

dfHechos.write.mode("overwrite").saveAsTable("workspace.moda.bronze_hechos")
dfDevol.write.mode("overwrite").saveAsTable("workspace.moda.bronze_devoluciones")

# COMMAND ----------

dfHechos.printSchema()
dfDevol.printSchema()

# COMMAND ----------

display(dfHechos)
print("Filas de hechos:", dfHechos.count(), "| Filas de devoluciones:", dfDevol.count())

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parte 3. Análisis exploratorio (EDA)

# COMMAND ----------

from pyspark.sql import functions as F

# Estadísticas básicas
display(dfHechos.describe("cantidad", "precio_unitario", "importe"))

# COMMAND ----------

# Valores nulos por columna
display(dfHechos.select([F.sum(F.col(c).isNull().cast("int")).alias(c) for c in dfHechos.columns]))

# COMMAND ----------

# Operaciones, unidades e importe por tipo
display(dfHechos.groupBy("tipo_operacion")
        .agg(F.countDistinct("id_operacion").alias("operaciones"),
             F.sum("cantidad").alias("unidades"),
             F.round(F.sum("importe"), 2).alias("importe")))

# COMMAND ----------

# Importe por categoría y por canal
display(dfHechos.groupBy("categoria").agg(F.round(F.sum("importe"), 2).alias("importe")).orderBy(F.desc("importe")))
display(dfHechos.groupBy("canal").count().orderBy(F.desc("count")))

# COMMAND ----------

# Valores distintos y posibles duplicados
display(dfHechos.select("estado").distinct())
print("Filas:", dfHechos.count(), "| Filas distintas:", dfHechos.distinct().count())

# COMMAND ----------

# Muestra aproximada del 10 % (con semilla para repetir el resultado)
muestra = dfHechos.sample(0.10, seed=42)
print("Filas en la muestra:", muestra.count())
display(muestra)

# COMMAND ----------

# Devoluciones: tipo de devolución y tipo de falla
display(dfDevol.groupBy("tipo_devolucion").count().orderBy(F.desc("count")))
display(dfDevol.filter(F.col("tipo_falla") != "Ninguna")
        .groupBy("tipo_falla", "gravedad").agg(F.count("*").alias("prendas"), F.sum("monto_cargo").alias("cargos")))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parte 4. Limpieza y preparación (capa Silver)

# COMMAND ----------

dfHechos2 = (spark.table("workspace.moda.bronze_hechos")
  .withColumnRenamed("precio_unitario", "precio")
  .withColumnRenamed("importe", "monto")
  .select("tipo_operacion", "id_operacion", "id_detalle", "nro_documento", "fuente", "fecha",
          "distrito", "cargo", "articulo", "categoria", "canal", "cantidad", "precio", "monto", "estado")
  .withColumn("fecha", F.to_date("fecha"))
  .withColumn("monto", F.col("monto").cast("decimal(12,2)"))
  .withColumn("precio", F.col("precio").cast("decimal(12,2)"))
  .na.drop(subset=["id_detalle", "fecha", "monto"])
  .na.fill({"distrito": "No registrado", "canal": "No registrado"})
  .filter((F.col("cantidad") > 0) & (F.col("monto") > 0))
  .dropDuplicates(["tipo_operacion", "id_detalle"])
  .withColumn("anio", F.year("fecha"))
  .withColumn("mes", F.month("fecha"))
  .withColumn("anio_mes", F.date_format("fecha", "yyyy-MM")))

display(dfHechos2)

# COMMAND ----------

# Join: a cada alquiler se le agrega su devolución (tipo de devolución, falla y cargo)
dfDevol2 = (spark.table("workspace.moda.bronze_devoluciones")
  .withColumnRenamed("monto_cargo", "cargo_devolucion")
  .select("alquiler", "articulo", "fecha_devolucion", "tipo_devolucion", "tipo_falla", "gravedad", "cargo_devolucion"))

dfAlquileres = (dfHechos2.filter("tipo_operacion = 'ALQUILER'")
  .withColumn("alquiler", F.concat_ws("-", "fuente", "nro_documento"))
  .join(dfDevol2, on=["alquiler", "articulo"], how="left")
  .na.fill({"tipo_devolucion": "Sin devolver", "tipo_falla": "Sin devolver"}))

display(dfAlquileres.selectExpr("alquiler", "articulo", "estado", "tipo_devolucion", "tipo_falla", "cargo_devolucion"))

# COMMAND ----------

# Comprobación: los totales deben cuadrar con ModaEstilo_DW (ventas S/ 38 056.40 y alquileres S/ 14 118.00)
totales = {r["tipo_operacion"]: float(r["total"])
           for r in dfHechos2.groupBy("tipo_operacion").agg(F.sum("monto").alias("total")).collect()}
print(totales)
assert abs(totales["VENTA"] - 38056.40) < 0.01 and abs(totales["ALQUILER"] - 14118.00) < 0.01
print("Silver cuadra con el OLAP")

dfHechos2.write.mode("overwrite").saveAsTable("workspace.moda.silver_hechos")
dfAlquileres.write.mode("overwrite").saveAsTable("workspace.moda.silver_alquileres")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parte 5. Indicadores (capa Gold)

# COMMAND ----------

gold_mes = (dfHechos2.groupBy("anio_mes", "tipo_operacion")
  .agg(F.sum("monto").alias("ingreso"),
       F.countDistinct("id_operacion").alias("operaciones"),
       F.sum("cantidad").alias("unidades"))
  .withColumn("ticket_promedio", F.round(F.col("ingreso") / F.col("operaciones"), 2))
  .orderBy("anio_mes"))

gold_categoria = (dfHechos2.groupBy("categoria", "tipo_operacion")
  .agg(F.sum("monto").alias("ingreso"), F.sum("cantidad").alias("unidades")))

gold_canal = (dfHechos2.groupBy("canal")
  .agg(F.sum("monto").alias("ingreso"), F.countDistinct("id_operacion").alias("operaciones")))

gold_devoluciones = (dfAlquileres.groupBy("tipo_devolucion", "tipo_falla")
  .agg(F.count("*").alias("prendas"), F.sum("cargo_devolucion").alias("cargos")))

gold_mes.write.mode("overwrite").saveAsTable("workspace.moda.gold_ingresos_mes")
gold_categoria.write.mode("overwrite").saveAsTable("workspace.moda.gold_ingresos_categoria")
gold_canal.write.mode("overwrite").saveAsTable("workspace.moda.gold_ingresos_canal")
gold_devoluciones.write.mode("overwrite").saveAsTable("workspace.moda.gold_devoluciones")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parte 6. Visualizaciones (en cada resultado: + > Visualization)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Ingresos por mes (gráfico de líneas: X anio_mes, Y ingreso, agrupar por tipo_operacion)
# MAGIC SELECT anio_mes, tipo_operacion, ingreso, operaciones, ticket_promedio
# MAGIC FROM workspace.moda.gold_ingresos_mes
# MAGIC ORDER BY anio_mes

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Ingresos por categoría (barras)
# MAGIC SELECT categoria, tipo_operacion, ingreso, unidades
# MAGIC FROM workspace.moda.gold_ingresos_categoria
# MAGIC ORDER BY ingreso DESC

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Ingresos por canal (barras o anillo)
# MAGIC SELECT canal, ingreso, operaciones
# MAGIC FROM workspace.moda.gold_ingresos_canal
# MAGIC ORDER BY ingreso DESC

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Devoluciones por tipo y falla (barras apiladas)
# MAGIC SELECT tipo_devolucion, tipo_falla, prendas, cargos
# MAGIC FROM workspace.moda.gold_devoluciones
# MAGIC ORDER BY prendas DESC
