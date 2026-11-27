# ModaEstilo – Proyecto final (Grupo 8)

Solución de Inteligencia de Negocios y Big Data para ModaEstilo, una tienda de venta y alquiler de ropa formal.

## Cómo replicar

| Qué | Carpeta | Herramienta |
|---|---|---|
| ETL de Excel y OLTP a OLAP (`ModaEstilo_DW`) | [`ETL`](ETL) | SQL Server y SSMS |
| Solución Big Data (EDA, limpieza, Medallion, gráficos y Genie) | [`BigData/Solucion_ModaEstilo`](BigData/Solucion_ModaEstilo) | Databricks |
| Experimento BI-07: volumen del ETL | [`BI/EXP-BI-07_Volumen_ETL`](BI/EXP-BI-07_Volumen_ETL) | SQL Server y SSMS |
| Experimento BD-07: esquema inferido frente a esquema declarado | [`BigData/BD07_Esquema_Inferido_vs_Declarado`](BigData/BD07_Esquema_Inferido_vs_Declarado) | Databricks |

Cada carpeta tiene su propio README con los pasos.

Orden recomendado: primero `ETL` (crea `ModaEstilo_DW`), después Power BI sobre `ModaEstilo_DW` y, por último, la solución Big Data.

## Otros archivos del grupo

- Dashboard de Power BI: `Dashboards finales actualizados.pbix` y su PDF
- Experimentos BI-01 a BI-05 y BD-01 a BD-05: `.github/workflows/`
- Experimento BI-06: `BI/EXP-BI-06_Indice_No_Agrupado.sql`
- Experimento BD-06: `BigData/BD06_Imputacion_Importes_Nulos.py`
- Scripts de base de datos: `database/`
