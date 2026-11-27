/* =====================================================================
   07 - EXPERIMENTO BI: EJECUTAR
   Corre el ETL completo con 100, 500, 10 000 y 100 000 filas (3 repeticiones cada uno)
   y muestra los tiempos de extracción, transformación y carga.
   Cerrar los Excel antes de ejecutar.
   ===================================================================== */
USE ModaEstilo_Experimento;
GO
SET NOCOUNT ON;
TRUNCATE TABLE exp.Resultado;
DECLARE @carpeta NVARCHAR(300) = N'C:\ModaEstilo_BI-main\BI\EXP-BI-07_Volumen_ETL\Volumenes\';
DECLARE @vol TABLE (n INT); INSERT INTO @vol VALUES (100), (500), (10000), (100000);
DECLARE @n INT, @rep INT, @archivo NVARCHAR(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT n FROM @vol ORDER BY n;
OPEN c; FETCH NEXT FROM c INTO @n;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @archivo = CONCAT(@carpeta, N'Fuentes_ModaEstilo_', @n, N'.xlsx');
    SET @rep = 1;
    WHILE @rep <= 3
    BEGIN
        EXEC exp.usp_Medir @n, @rep, @archivo;
        SET @rep += 1;
    END;
    FETCH NEXT FROM c INTO @n;
END;
CLOSE c; DEALLOCATE c;
GO

-- Detalle de las 12 corridas
SELECT volumen, repeticion, filas_leidas, limpias, rechazadas, duplicadas, hechos_cargados,
       ms_extraccion, ms_transformacion, ms_carga, ms_total
FROM exp.Resultado ORDER BY volumen, repeticion;

-- Resumen por volumen (promedio de las 3 repeticiones)
SELECT volumen,
       MAX(filas_leidas) AS filas_leidas, MAX(limpias) AS limpias, MAX(rechazadas) AS rechazadas,
       MAX(duplicadas) AS duplicadas,
       CAST(100.0 * MAX(rechazadas + duplicadas) / MAX(filas_leidas) AS DECIMAL(5,2)) AS pct_descartadas,
       MAX(hechos_cargados) AS hechos_cargados,
       AVG(ms_extraccion) AS ms_extraccion, AVG(ms_transformacion) AS ms_transformacion,
       AVG(ms_carga) AS ms_carga, AVG(ms_total) AS ms_total,
       CAST(STDEV(ms_total) AS DECIMAL(10,1)) AS desv_ms_total,
       CAST(MAX(filas_leidas) * 1000.0 / AVG(ms_total) AS DECIMAL(12,1)) AS filas_por_segundo
FROM exp.Resultado GROUP BY volumen ORDER BY volumen;
