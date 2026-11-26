/* ============================================================
   EXPERIMENTO EXP-BI-06
   Optimización del rendimiento mediante índices no agrupados
   Base de datos: ModaEstilo_BI_Demo
   Tabla: exp.FactVenta_Row
   ============================================================ */

-- Seleccionar la base de datos donde se realizará el experimento.
USE ModaEstilo_BI_Demo;
GO

/* ============================================================
   1. VERIFICACIÓN INICIAL DE LA TABLA
   ============================================================ */

-- Mostrar los primeros cinco registros de la tabla de ventas
-- para comprobar que contiene información.
SELECT TOP 5 *
FROM exp.FactVenta_Row;

-- Contar la cantidad total de registros de la tabla.
-- COUNT_BIG permite devolver un resultado de tipo BIGINT.
SELECT COUNT_BIG(*) AS TotalFilas
FROM exp.FactVenta_Row;


/* ============================================================
   2. IDENTIFICACIÓN DE LOS ÍNDICES EXISTENTES
   ============================================================ */

-- Consultar los índices asociados a FactVenta_Row.
-- Se muestran el nombre, tipo y columnas que forman cada índice.
-- Esta consulta permite conocer la estructura inicial de índices.
SELECT
    i.name AS NombreIndice,
    i.type_desc AS TipoIndice,
    c.name AS Columna
FROM sys.indexes i
INNER JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
INNER JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('exp.FactVenta_Row')
ORDER BY i.name, ic.key_ordinal;


/* ============================================================
   3. MEDICIÓN DEL RENDIMIENTO ANTES DE CREAR EL ÍNDICE
   ============================================================ */

-- Activar las estadísticas de lecturas y tiempo de ejecución.
-- STATISTICS IO muestra las lecturas realizadas por SQL Server.
-- STATISTICS TIME muestra el tiempo de CPU y el tiempo transcurrido.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Consultar la cantidad de operaciones y el ingreso total
-- correspondientes a la categoría 3.
-- Esta consulta servirá como referencia antes de crear el índice.
SELECT
    CategoriaKey,
    COUNT(*) AS Operaciones,
    SUM(ImporteVenta) AS IngresoTotal
FROM exp.FactVenta_Row
WHERE CategoriaKey = 3
GROUP BY CategoriaKey;

-- Desactivar las estadísticas después de la medición.
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;


/* ============================================================
   4. CREACIÓN DEL ÍNDICE NO AGRUPADO
   ============================================================ */

-- Crear un índice no agrupado sobre CategoriaKey.
-- La columna ImporteVenta se incluye para que SQL Server
-- pueda obtener el importe directamente desde el índice
-- al calcular el ingreso total.
CREATE NONCLUSTERED INDEX IX_FactVenta_Categoria
ON exp.FactVenta_Row (CategoriaKey)
INCLUDE (ImporteVenta);
GO


/* ============================================================
   5. MEDICIÓN DEL RENDIMIENTO DESPUÉS DE CREAR EL ÍNDICE
   ============================================================ */

-- Activar nuevamente las estadísticas de lecturas y tiempo.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Ejecutar la misma consulta utilizada antes de crear el índice.
-- Esto permite comparar las lecturas y los tiempos de ejecución.
SELECT
    CategoriaKey,
    COUNT(*) AS Operaciones,
    SUM(ImporteVenta) AS IngresoTotal
FROM exp.FactVenta_Row
WHERE CategoriaKey = 3
GROUP BY CategoriaKey;

-- Desactivar las estadísticas al finalizar la medición.
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;


/* ============================================================
   6. VERIFICACIÓN DEL RESULTADO DE LA CONSULTA
   ============================================================ */

-- Ejecutar nuevamente la consulta para comprobar
-- que se obtienen los resultados esperados para la categoría 3.
SELECT
    CategoriaKey,
    COUNT(*) AS Operaciones,
    SUM(ImporteVenta) AS IngresoTotal
FROM exp.FactVenta_Row
WHERE CategoriaKey = 3
GROUP BY CategoriaKey;

-- FIN DEL EXPERIMENTO EXP-BI-06
