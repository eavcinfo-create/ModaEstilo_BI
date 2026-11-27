# EXP-12 (BD-07): esquema inferido frente a esquema declarado

Lee el mismo CSV con `inferSchema` y con un esquema declarado (`StructType`) en escalas crecientes a partir de la línea base (250 filas reales de ModaEstilo_DW), con 100, 500, 10 000, 100 000, 1 000 000, 5 000 000 y 10 000 000 de filas. Mide el tiempo de lectura y cálculo, y compara el tipo de dato y el total de importes que se obtiene con cada forma.

## Requisitos

- El esquema `workspace.moda` y el volumen `datos` en Databricks, con `modaestilo_hechos.csv` subido. Los pasos 2 a 4 están en [`Solucion_ModaEstilo`](../Solucion_ModaEstilo) y el CSV está en `../Solucion_ModaEstilo/datos/`.

## Pasos

1. Ve a **Workspace**, haz clic en **⋮ → Import** y sube `Experimento_BD_Esquema.ipynb` (está en `C:\ModaEstilo_BI-main\BigData\BD07_Esquema_Inferido_vs_Declarado`).
2. Conecta el notebook a **Serverless**.
3. Ejecuta las celdas en orden (Shift + Enter):
   - **1. Configuración**: muestra la versión de Spark y las filas base (250).
   - **2. Generar los CSV**: crea `exp_esquema/filas_100` ... `filas_10000000` dentro del volumen (cerca de 2 GB). Tarda varios minutos.
   - **3. Funciones**: define la lectura con cada esquema y la medición (5 repeticiones, mediana).
   - **4. Ejecución**: mide los 7 volúmenes y muestra una línea por volumen con el peso del archivo y los tiempos. Tarda entre 10 y 20 minutos.
   - **5. Bitácora**: guarda los resultados en la tabla `workspace.moda.bitacora_exp_esquema`. Las columnas `filas_leidas` y `tamano_mb` muestran que cada CSV tiene las filas indicadas.
   - **6. Gráfico**: en el resultado, haz clic en **+ → Visualization → Line**. Pon `filas` en el eje X (escala logarítmica) y `inferido_s` y `declarado_s` en el eje Y.
   - **7. Esquemas**: muestra con `printSchema` qué tipo de dato asigna cada forma de lectura.

## Qué comparar

- El tiempo (`inferido_s` frente a `declarado_s`) en cada volumen
- Las filas por segundo (`filas_s_inferido` y `filas_s_declarado`) al crecer el volumen
- Los registros procesados (`filas_leidas`, igual a `filas`) y la consistencia del total: `total_esperado` sale de la línea base (250 filas) multiplicada por la escala, y `consistente` debe decir **Sí** en todas las escalas
- El tipo de `fecha`, `id_detalle` e `importe` con `inferSchema`, frente a `date`, `bigint` y `decimal(12,2)` con `StructType`
- `total_inferido` frente a `total_declarado` y su diferencia (`diferencia_total`)
