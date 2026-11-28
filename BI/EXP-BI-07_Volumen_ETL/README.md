# EXP-11 (BI-07): escalabilidad del ETL según el volumen del Excel

Mide cuánto tarda cada etapa del ETL (extracción, transformación y carga) con Excel de 100, 500, 10 000 y 100 000 filas, 3 veces cada uno.

Usa una base aparte, `ModaEstilo_Experimento`, y no toca `ModaEstilo_DW`.

## Requisitos

- Haber ejecutado `00_crear_oltp_ModaEstilo_Final.sql` y `01_preparacion.sql` de la carpeta [`ETL`](../../ETL)
- Todos los Excel **cerrados**

## Contenido

| Archivo | Qué es |
|---|---|
| `Volumenes/Fuentes_ModaEstilo_100.xlsx` ... `_100000.xlsx` | Los 4 Excel del experimento (de 26 KB a 16 MB) |
| `05_generar_excel_volumenes.py` | Genera esos Excel desde el original (solo si quieres crearlos de nuevo) |
| `06_experimento_preparar.sql` | Crea la base `ModaEstilo_Experimento` y los procedimientos que miden cada etapa |
| `07_experimento_ejecutar.sql` | Ejecuta las 12 corridas y muestra los resultados |

## Pasos

1. Descomprime el repositorio en `C:\ModaEstilo_BI-main` y dale el permiso de `icacls` (ver el [README principal](../../README.md)).
2. En SSMS abre y ejecuta (F5) `06_experimento_preparar.sql`.
3. Abre y ejecuta `07_experimento_ejecutar.sql`. Tarda unos 5 minutos y muestra 2 tablas: el detalle de las 12 corridas y el resumen por volumen.

Si descomprimiste el repositorio en otra carpeta, cambia la ruta de la línea 11 de `07_experimento_ejecutar.sql` (debe terminar en `\`).

Para crear los Excel otra vez (opcional):

```
python -m pip install openpyxl
python 05_generar_excel_volumenes.py "..\..\ETL\1_Fuentes_Excel\Fuentes_ModaEstilo.xlsx" Volumenes "100,500,10000,100000"
```

## Resultado obtenido (27/11/2026, AMD Ryzen 7 5700X, 32 GB de RAM)

| Volumen | Filas leídas | Limpias | % descartadas | Extracción ms | Transformación ms | Carga ms | Total ms | Filas por segundo |
|---|---|---|---|---|---|---|---|---|
| 100 | 319 | 291 | 8,78 | 196 | 155 | 216 | 568 | 562 |
| 500 | 1 467 | 1 367 | 6,82 | 156 | 323 | 798 | 1 277 | 1 149 |
| 10 000 | 28 771 | 26 978 | 6,23 | 1 578 | 3 584 | 2 192 | 7 355 | 3 912 |
| 100 000 | 287 427 | 269 579 | 6,21 | 17 599 | 32 081 | 5 450 | 55 131 | 5 214 |

Los tiempos cambian un poco en cada equipo. Las filas leídas, limpias y rechazadas deben salir iguales.

Los 2 gráficos (tiempo por etapa y filas por segundo) se hicieron en Power BI Desktop con la tabla del resumen (**Inicio → Especificar datos**). Las capturas de esta ejecución están en [`capturas`](capturas).
