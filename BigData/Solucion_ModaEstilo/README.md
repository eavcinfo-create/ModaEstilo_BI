# Solución Big Data ModaEstilo (Databricks)

Notebook de PySpark con los datos de `ModaEstilo_DW`. Lee los CSV en DataFrames, hace el análisis exploratorio, limpia los datos y los guarda en tablas Delta con arquitectura Medallion (Bronze, Silver y Gold). Al final arma los gráficos.

## Contenido

| Archivo | Qué es |
|---|---|
| `datos/modaestilo_hechos.csv` | 250 filas: 125 líneas de venta y 125 de alquiler (18 columnas, sin datos personales) |
| `datos/modaestilo_devoluciones.csv` | 107 devoluciones con tipo de falla, gravedad y cargo |
| `BigData_ModaEstilo.ipynb` | Notebook de Databricks |
| `capturas/` | Capturas de una ejecución completa (27/11/2026) y `BigData_ModaEstilo_ejecutado.ipynb`, el notebook con sus resultados |
| `exportar_csv_desde_DW.sql` | Consultas con las que se generaron los CSV desde ModaEstilo_DW (no hace falta ejecutarlo: los CSV ya están en `datos`) |

## Pasos en Databricks Free Edition

1. Descomprime el repositorio en `C:\ModaEstilo_BI-main` (ver el [README principal](../../README.md)).
2. En Databricks entra a **Catalog**, luego a **workspace**, y haz clic en **Create → Create schema**. Ponle el nombre `moda`.
3. Dentro de `moda`, haz clic en **Create → Create volume**. Ponle el nombre `datos` y elige el tipo **Managed**.
4. Entra al volumen `datos`, haz clic en **Upload to this volume** y sube los 2 CSV de `C:\ModaEstilo_BI-main\BigData\Solucion_ModaEstilo\datos`.
5. Ve a **Workspace**, abre tu carpeta y haz clic en **⋮ → Import**. Sube `BigData_ModaEstilo.ipynb`; se abre como notebook.
6. Conecta el notebook a **Serverless** y haz clic en **Run all**.

## Resultado esperado

| Capa | Tabla en `workspace.moda` | Filas |
|---|---|---|
| Bronze | `bronze_hechos` / `bronze_devoluciones` | 250 / 107 |
| Silver | `silver_hechos` / `silver_alquileres` | 250 / 125 |
| Gold | `gold_ingresos_mes` / `gold_ingresos_categoria` / `gold_ingresos_canal` / `gold_devoluciones` | 22 / 13 / 5 / 14 |

En la parte 4 debe salir el mensaje **Silver cuadra con el OLAP**: las ventas suman S/ 38 056,40 y los alquileres S/ 14 118,00, igual que en `ModaEstilo_DW`.

Los gráficos se hacen en el resultado de cada celda `%sql`: haz clic en **+ → Visualization**.

## Genie

1. En el menú de la izquierda, haz clic en **Genie Agents → New** (en otras versiones se llama **Genie**).
2. Elige las 4 tablas `gold_*` de `workspace.moda` y haz clic en **Create manually**.
3. En **Instructions** escribe: *Responde en español. Los montos están en soles.*
4. Pregunta, por ejemplo: *¿Qué canal generó más ingresos?* La respuesta debe ser WhatsApp, con S/ 17 634,05.

En nuestra prueba acertó 3 de 4 preguntas. En *¿Cuántas prendas se devolvieron con falla y cuánto se cobró?* contó 47 prendas en vez de 29, porque sumó las 18 «Sin devolver»; el cargo (S/ 1 454,00) sí coincide.
