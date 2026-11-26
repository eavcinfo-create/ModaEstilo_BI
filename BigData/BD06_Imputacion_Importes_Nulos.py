# MAGIC %md
# MAGIC ###  **BD-06: imputar importes nulos en Silver en lugar de eliminar esas filas.**
# MAGIC
# MAGIC Objetivo: Evaluar si la imputación de importes nulos mediante la multiplicación de la cantidad por el precio unitario permite mejorar la calidad de los datos y reducir el error del indicador de ingresos, en comparación con la limpieza original de Silver.

# COMMAND ----------


from pyspark.sql import functions as F

# Referencia del total esperado
TOTAL_REF = 136915700.0

# Silver nueva: imputar importes nulos
silver_nueva = (
    bronze
    .dropDuplicates(["tipo_operacion", "id_detalle"])
    .filter(
        (F.col("cantidad") > 0) &
        (F.col("precio_unitario") > 0)
    )
    .withColumn(
        "importe",
        F.when(
            F.col("importe").isNull(),
            F.round(F.col("cantidad") * F.col("precio_unitario"), 2)
        ).otherwise(F.col("importe"))
    )
)

# Función para resumir los resultados
def resumen(nombre, df):
    filas = df.count()
    total = df.agg(F.sum("importe")).first()[0]
    error = (total - TOTAL_REF) / TOTAL_REF * 100
    nulos = df.filter(F.col("importe").isNull()).count()

    return (
        nombre,
        filas,
        round(total, 1),
        round(error, 3),
        nulos
    )

# Comparación de las tres capas
filas = [
    resumen("Bronze", bronze),
    resumen("Silver original", silver),
    resumen("Silver nueva", silver_nueva)
]

res = spark.createDataFrame(
    filas,
    ["capa", "filas", "total", "error_pct", "importes_nulos"]
)

display(res)

# Gold nueva: ingresos por categoría y año
gold_nueva = (
    silver_nueva
    .groupBy("categoria", "anio")
    .agg(F.sum("importe").alias("ingreso"))
    .orderBy("categoria", "anio")
)

display(gold_nueva)
