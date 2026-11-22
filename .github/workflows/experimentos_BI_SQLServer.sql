/* ============================================================================
 EXPERIMENTOS BI - ModaEstilo (Grupo 8)  |  Base: ModaEstilo_BI_Demo
 Ejecutar DESPUES de ModeloEstrella_ModaEstilo.sql. No modifica dbo ni bi:
============================================================================ */
USE ModaEstilo_BI_Demo;
GO
IF SCHEMA_ID(N'exp') IS NULL EXEC(N'CREATE SCHEMA exp');
GO
/* ---------------------------------------------------------------------------
 0. GENERADOR DE VOLUMEN (EXP-BI-01, 03, 05)
    K = factor de replicacion de ventas/detalles (1, 100, 1000, 5000).
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE exp.usp_GenerarEscala @K INT AS
BEGIN
  SET NOCOUNT ON;
  DROP TABLE IF EXISTS exp.FactVenta_Row, exp.FactVenta_CCI, exp.VentaK, exp.DetalleVentaK, exp.Numeros;
  CREATE TABLE exp.Numeros(k INT PRIMARY KEY);
  INSERT exp.Numeros SELECT TOP (@K) ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c;
  DECLARE @mv INT=(SELECT MAX(idVenta) FROM dbo.Venta);
  SELECT v.idVenta+n.k*@mv AS idVenta, v.idCliente, v.idTrabajador, v.fechaVenta, v.total
    INTO exp.VentaK FROM dbo.Venta v CROSS JOIN exp.Numeros n;
  SELECT d.idVenta+n.k*@mv AS idVenta, d.idArticulo, d.cantidad, d.subtotal
    INTO exp.DetalleVentaK FROM dbo.DetalleVenta d CROSS JOIN exp.Numeros n;
  CREATE CLUSTERED INDEX cx_v ON exp.VentaK(idVenta);
  CREATE CLUSTERED INDEX cx_d ON exp.DetalleVentaK(idVenta);
  -- Tabla de hechos estrella (grano: articulo dentro de venta)
  SELECT d.idVenta AS VentaID, v.idTrabajador AS TrabajadorKey, d.idArticulo AS ArticuloKey,
         a.idCategoria AS CategoriaKey,
         YEAR(v.fechaVenta)*10000+MONTH(v.fechaVenta)*100+DAY(v.fechaVenta) AS FechaKey,
         d.cantidad AS Cantidad, d.subtotal AS ImporteVenta
    INTO exp.FactVenta_Row
    FROM exp.DetalleVentaK d JOIN exp.VentaK v ON v.idVenta=d.idVenta
    JOIN dbo.Articulo a ON a.idArticulo=d.idArticulo;
  SELECT * INTO exp.FactVenta_CCI FROM exp.FactVenta_Row;
  CREATE CLUSTERED COLUMNSTORE INDEX ccix ON exp.FactVenta_CCI;      -- EXP-BI-03
  CREATE CLUSTERED INDEX cx_f ON exp.FactVenta_Row(FechaKey);        -- rowstore
  SELECT @K AS K, (SELECT COUNT(*) FROM exp.FactVenta_Row) AS FilasHecho;
END;
GO

EXEC exp.usp_GenerarEscala @K = 1;
/* ---------------------------------------------------------------------------
 EXP-BI-01  Modelo normalizado (dbo) vs modelo estrella (bi/exp)
 Medir con: SET STATISTICS TIME, IO ON  (ver "CPU time" y "elapsed time")
 Controles: DBCC DROPCLEANBUFFERS (solo en instancia de pruebas) + 1 corrida de
 calentamiento + 7 repeticiones; reportar mediana y desviacion estandar.
--------------------------------------------------------------------------- */
-- EXEC exp.usp_GenerarEscala @K=100;   -- repetir con 1, 100, 1000, 5000
SET STATISTICS TIME ON; SET STATISTICS IO ON;

-- Q1 normalizado
SELECT c.nombreCategoria, FORMAT(v.fechaVenta,'yyyy-MM') AS AnioMes, SUM(d.subtotal) AS Ingreso
FROM exp.VentaK v JOIN exp.DetalleVentaK d ON d.idVenta=v.idVenta
JOIN dbo.Articulo a ON a.idArticulo=d.idArticulo JOIN dbo.Categoria c ON c.idCategoria=a.idCategoria
GROUP BY c.nombreCategoria, FORMAT(v.fechaVenta,'yyyy-MM');
-- Q1 estrella
SELECT dc.Categoria, df.AnioMes, SUM(f.ImporteVenta) AS Ingreso
FROM exp.FactVenta_Row f JOIN bi.DimCategoria dc ON dc.CategoriaKey=f.CategoriaKey
JOIN bi.DimCalendario df ON df.FechaKey=f.FechaKey
GROUP BY dc.Categoria, df.AnioMes;

-- Q2 top 10 articulos (normalizado)
SELECT TOP 10 a.nombre, SUM(d.subtotal) AS Ingreso FROM exp.DetalleVentaK d
JOIN exp.VentaK v ON v.idVenta=d.idVenta JOIN dbo.Articulo a ON a.idArticulo=d.idArticulo
GROUP BY a.idArticulo, a.nombre ORDER BY Ingreso DESC;
-- Q2 estrella
SELECT TOP 10 da.Articulo, SUM(f.ImporteVenta) AS Ingreso FROM exp.FactVenta_Row f
JOIN bi.DimArticulo da ON da.ArticuloKey=f.ArticuloKey GROUP BY da.ArticuloKey, da.Articulo ORDER BY Ingreso DESC;

-- Q3 ticket promedio por trabajador (normalizado: usa solo cabecera)
SELECT t.nombres, AVG(v.total) AS TicketPromedio FROM exp.VentaK v
JOIN dbo.Trabajador t ON t.idTrabajador=v.idTrabajador GROUP BY t.idTrabajador, t.nombres;
-- Q3 estrella (requiere DISTINCT sobre grano detalle)
SELECT dt.Trabajador, SUM(f.ImporteVenta)*1.0/COUNT(DISTINCT f.VentaID) AS TicketPromedio
FROM exp.FactVenta_Row f JOIN bi.DimTrabajador dt ON dt.TrabajadorKey=f.TrabajadorKey
GROUP BY dt.TrabajadorKey, dt.Trabajador;
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;

/* ---------------------------------------------------------------------------
 EXP-BI-03  Rowstore vs Clustered Columnstore en la tabla de hechos
--------------------------------------------------------------------------- */
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT CategoriaKey, FechaKey/100 AS AnioMes, SUM(ImporteVenta) AS Ingreso, SUM(Cantidad) AS Unidades
FROM exp.FactVenta_Row GROUP BY CategoriaKey, FechaKey/100;      -- rowstore
SELECT CategoriaKey, FechaKey/100 AS AnioMes, SUM(ImporteVenta) AS Ingreso, SUM(Cantidad) AS Unidades
FROM exp.FactVenta_CCI GROUP BY CategoriaKey, FechaKey/100;      -- columnstore
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
-- Espacio ocupado (MB) por cada estructura:
EXEC sp_spaceused N'exp.FactVenta_Row';
EXEC sp_spaceused N'exp.FactVenta_CCI';

/* ---------------------------------------------------------------------------
 EXP-BI-05  Exactitud de la informacion: error de grano (join cabecera+detalle+pago)
 Referencia correcta (K=1): Ventas = 92 784,70 ; Alquileres = 44 131,00
--------------------------------------------------------------------------- */
-- Correcto (cada hecho en su grano)
SELECT SUM(total) AS IngresoVentas_Correcto FROM dbo.Venta;
SELECT SUM(total) AS IngresoAlquiler_Correcto FROM dbo.Alquiler;
-- Incorrecto 1: sumar el total de CABECERA despues de unir con DETALLE (se repite por cada articulo)
SELECT SUM(v.total) AS IngresoVentas_Inflado FROM dbo.Venta v JOIN dbo.DetalleVenta d ON d.idVenta=v.idVenta;
SELECT SUM(a.total) AS IngresoAlquiler_Inflado FROM dbo.Alquiler a JOIN dbo.DetalleAlquiler d ON d.idAlquiler=a.idAlquiler;
-- Incorrecto 2: unir tambien con PAGO (fan-out doble)
SELECT SUM(a.total) AS IngresoAlquiler_Inflado2 FROM dbo.Alquiler a
JOIN dbo.DetalleAlquiler d ON d.idAlquiler=a.idAlquiler JOIN dbo.Pago p ON p.idAlquiler=a.idAlquiler;
-- Variante estrella (correcta por construccion): usar el importe del DETALLE
SELECT SUM(ImporteVenta) AS IngresoVentas_Estrella FROM bi.FactVenta;
SELECT SUM(ImporteAlquiler) AS IngresoAlquiler_Estrella FROM bi.FactAlquiler;
