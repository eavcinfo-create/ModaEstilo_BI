-- Pruebas de la sección 5.4 sobre el ETL (ejecutar después de 02, 03 y 04)
SET NOCOUNT ON;

-- T-01. Filas extraídas de cada hoja del Excel y tablas copiadas del OLTP
USE ModaEstilo_Staging;
SELECT 'raw_catalogo' AS tabla, COUNT(*) AS filas FROM stg.raw_catalogo
UNION ALL SELECT 'raw_ventas', COUNT(*) FROM stg.raw_ventas
UNION ALL SELECT 'raw_alquileres', COUNT(*) FROM stg.raw_alquileres
UNION ALL SELECT 'raw_inspeccion', COUNT(*) FROM stg.raw_inspeccion;
SELECT COUNT(*) AS tablas_oltp_copiadas FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'stg' AND name LIKE 'oltp[_]%';

-- T-02. Cabecera inválida: en una copia del Excel cambiar el nombre de la columna "Fecha" de la hoja Ventas
-- y ejecutar 02_extraccion.sql con esa copia. Debe detenerse con el error 53001.

-- T-03. Funciones de limpieza (NULL = valor inválido)
SELECT etl.fn_Fecha(N'31/09/2026') AS fecha_inexistente, etl.fn_Fecha(N'05/11/2026') AS fecha_ok,
       etl.fn_Decimal(N'S/ 150,50') AS decimal_coma, etl.fn_DNI(N'7512345') AS dni_7_digitos,
       etl.fn_Map(N'CANAL', N'wsp') AS canal_wsp, etl.fn_Map(N'CANAL', N'TikTok') AS canal_no_valido;

-- T-04 y T-05. Ninguna fila se pierde: leídas = cargadas + rechazadas + duplicadas
SELECT hoja, tipo, COUNT(*) AS filas FROM etl.Rechazo GROUP BY hoja, tipo ORDER BY hoja, tipo;
SELECT hoja, fila, tipo, motivo FROM etl.Rechazo ORDER BY hoja, fila;

USE ModaEstilo_DW;
-- T-06. Hechos repetidos por clave natural (debe dar 0)
SELECT (SELECT COUNT(*) FROM (SELECT Fuente, NroDocumento, ArticuloKey FROM dw.FactVenta
                              GROUP BY Fuente, NroDocumento, ArticuloKey HAVING COUNT(*) > 1) x) AS repetidos_venta,
       (SELECT COUNT(*) FROM (SELECT Fuente, NroAlquiler, ArticuloKey FROM dw.FactAlquiler
                              GROUP BY Fuente, NroAlquiler, ArticuloKey HAVING COUNT(*) > 1) x) AS repetidos_alquiler;

-- T-07. Claves huérfanas (debe dar 0 en las 3 tablas de hechos)
SELECT 'FactVenta' AS hecho, COUNT(*) AS huerfanas FROM dw.FactVenta f
WHERE NOT EXISTS (SELECT 1 FROM dw.DimFecha d WHERE d.FechaKey = f.FechaKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimCliente c WHERE c.ClienteKey = f.ClienteKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimArticulo a WHERE a.ArticuloKey = f.ArticuloKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimTrabajador t WHERE t.TrabajadorKey = f.TrabajadorKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimCanal k WHERE k.CanalKey = f.CanalKey)
UNION ALL
SELECT 'FactAlquiler', COUNT(*) FROM dw.FactAlquiler f
WHERE NOT EXISTS (SELECT 1 FROM dw.DimFecha d WHERE d.FechaKey = f.FechaAlquilerKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimCliente c WHERE c.ClienteKey = f.ClienteKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimArticulo a WHERE a.ArticuloKey = f.ArticuloKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimTrabajador t WHERE t.TrabajadorKey = f.TrabajadorKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimCanal k WHERE k.CanalKey = f.CanalKey)
UNION ALL
SELECT 'FactDevolucion', COUNT(*) FROM dw.FactDevolucion f
WHERE NOT EXISTS (SELECT 1 FROM dw.DimFecha d WHERE d.FechaKey = f.FechaDevolucionKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimArticulo a WHERE a.ArticuloKey = f.ArticuloKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimFalla x WHERE x.FallaKey = f.FallaKey)
   OR NOT EXISTS (SELECT 1 FROM dw.DimTrabajador t WHERE t.TrabajadorKey = f.InspectorKey);
SELECT COUNT(*) AS claves_foraneas FROM sys.foreign_keys;

-- T-08. Totales por fuente (Excel + OLTP = DW)
SELECT 'Ventas' AS hecho, Fuente, COUNT(*) AS lineas, SUM(ImporteVenta) AS importe FROM dw.FactVenta GROUP BY Fuente
UNION ALL SELECT 'Alquileres', Fuente, COUNT(*), SUM(ImporteAlquiler) FROM dw.FactAlquiler GROUP BY Fuente
UNION ALL SELECT 'Devoluciones', Fuente, COUNT(*), SUM(MontoCargo) FROM dw.FactDevolucion GROUP BY Fuente
ORDER BY hecho, Fuente;
SELECT (SELECT SUM(ImporteVenta) FROM dw.FactVenta) AS total_ventas,
       (SELECT SUM(ImporteAlquiler) FROM dw.FactAlquiler) AS total_alquileres,
       (SELECT SUM(MontoCargo) FROM dw.FactDevolucion) AS total_cargos;

-- T-10. Ejecutar 04_carga.sql otra vez: su primer resultado debe mostrar 0 insertados y 0 actualizados en todas las tablas.
