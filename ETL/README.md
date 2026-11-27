# ETL ModaEstilo: de Excel a OLAP

Extrae los datos del Excel `Fuentes_ModaEstilo.xlsx` y de la base `ModaEstilo_Final`, los limpia en `ModaEstilo_Staging` y los carga en el modelo estrella `ModaEstilo_DW`.

El paso a paso con capturas está en **Procedimiento de replicación ETL.pdf**.

## Requisitos

- SQL Server 2025 Developer y SQL Server Management Studio 22
- Microsoft Access Database Engine 2016 (64 bits), para que SQL Server pueda leer el Excel
- El Excel debe estar **cerrado** al ejecutar los scripts. Si está abierto, sale el error 7303.

## Contenido

| Carpeta / archivo | Qué es |
|---|---|
| `1_Fuentes_Excel/Fuentes_ModaEstilo.xlsx` | Hojas Catalogo, Ventas, Alquileres e Inspeccion (con errores a propósito) |
| `2_Scripts_SQL/00_crear_oltp_ModaEstilo_Final.sql` | Crea la base de origen ModaEstilo_Final |
| `2_Scripts_SQL/01_preparacion.sql` | Versión del motor y permisos para leer el Excel |
| `2_Scripts_SQL/02_extraccion.sql` | Extracción a ModaEstilo_Staging |
| `2_Scripts_SQL/03_transformacion.sql` | Limpieza, rechazos y duplicados |
| `2_Scripts_SQL/04_carga.sql` | Carga a ModaEstilo_DW con MERGE |
| `2_Scripts_SQL/05_OLAP_ModaEstilo_DW.sql` | Crea ModaEstilo_DW con los datos ya limpios (sin pasar por el Excel). Es el que usa Power BI |

## Pasos

1. Descarga la carpeta `ETL` y déjala, por ejemplo, en `C:\ModaEstilo\ETL`.
2. Abre PowerShell **como administrador** y dale permiso de lectura a SQL Server sobre la carpeta del Excel (un solo comando, en una línea):

   ```
   icacls "C:\ModaEstilo\ETL\1_Fuentes_Excel" /grant "NT Service\MSSQLSERVER:(OI)(CI)RX"
   ```

3. En SSMS abre y ejecuta (F5) `00_crear_oltp_ModaEstilo_Final.sql`.
4. Abre `01_preparacion.sql` y `02_extraccion.sql`, cambia la ruta del Excel por la tuya y ejecútalos (F5):
   - `01_preparacion.sql`, línea 20: `Database=C:\...\1_Fuentes_Excel\Fuentes_ModaEstilo.xlsx`
   - `02_extraccion.sql`, línea 83: `DECLARE @Archivo ... = N'C:\...\1_Fuentes_Excel\Fuentes_ModaEstilo.xlsx'`
5. Ejecuta `03_transformacion.sql`.
6. Ejecuta `04_carga.sql`.

Si solo necesitas el modelo estrella para Power BI, basta con ejecutar `05_OLAP_ModaEstilo_DW.sql`.

## Resultado esperado

| Etapa | Resultado |
|---|---|
| Extracción | Catalogo 25, Ventas 129, Alquileres 119 e Inspeccion 109 filas |
| Transformación | 353 filas limpias, 25 rechazadas y 4 duplicadas (tabla `etl.Rechazo`) |
| Carga | FactVenta 125, FactAlquiler 125, FactDevolucion 107, DimCliente 44, DimArticulo 24, DimTrabajador 5, DimCanal 5, DimFalla 9 y DimFecha 1095 |
| Totales | Ventas S/ 38 056,40, alquileres S/ 14 118,00 y cargos por devolución S/ 1 544,00 |

Si ejecutas `04_carga.sql` otra vez, inserta 0 filas y actualiza 0: no se duplican datos.
