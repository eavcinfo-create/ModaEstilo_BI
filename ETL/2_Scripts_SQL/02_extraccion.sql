/* =====================================================================
   02 - EXTRACCION
   Copia las 4 hojas del Excel tal cual (como texto y con su número de fila)
   y las tablas de la base OLTP ModaEstilo_Final a la base ModaEstilo_Staging.
   Si se ejecuta de nuevo, vacía y vuelve a llenar estas tablas de paso.
   ===================================================================== */
IF DB_ID(N'ModaEstilo_Staging') IS NULL
    CREATE DATABASE ModaEstilo_Staging COLLATE Modern_Spanish_CI_AS;
GO
USE ModaEstilo_Staging;
GO
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
GO
IF OBJECT_ID(N'stg.raw_catalogo') IS NULL
CREATE TABLE stg.raw_catalogo (
    fila INT NOT NULL PRIMARY KEY,
    codigo NVARCHAR(400), nombre NVARCHAR(400), categoria NVARCHAR(400), talla NVARCHAR(400),
    color NVARCHAR(400), costo_compra NVARCHAR(400), precio_alquiler NVARCHAR(400),
    precio_venta NVARCHAR(400), stock NVARCHAR(400), stock_minimo NVARCHAR(400));
IF OBJECT_ID(N'stg.raw_ventas') IS NULL
CREATE TABLE stg.raw_ventas (
    fila INT NOT NULL PRIMARY KEY,
    nro_pedido NVARCHAR(400), fecha NVARCHAR(400), dni_cliente NVARCHAR(400), nombres NVARCHAR(400),
    apellidos NVARCHAR(400), telefono NVARCHAR(400), distrito NVARCHAR(400), codigo_articulo NVARCHAR(400),
    cantidad NVARCHAR(400), precio_unitario NVARCHAR(400), canal NVARCHAR(400), dni_vendedor NVARCHAR(400),
    comprobante NVARCHAR(400));
IF OBJECT_ID(N'stg.raw_alquileres') IS NULL
CREATE TABLE stg.raw_alquileres (
    fila INT NOT NULL PRIMARY KEY,
    nro_alquiler NVARCHAR(400), fecha_alquiler NVARCHAR(400), fecha_entrega NVARCHAR(400),
    fecha_devolucion_programada NVARCHAR(400), dni_cliente NVARCHAR(400), nombres NVARCHAR(400),
    apellidos NVARCHAR(400), telefono NVARCHAR(400), distrito NVARCHAR(400), codigo_articulo NVARCHAR(400),
    cantidad NVARCHAR(400), precio_unitario NVARCHAR(400), canal NVARCHAR(400), dni_trabajador NVARCHAR(400),
    tipo_evento NVARCHAR(400));
IF OBJECT_ID(N'stg.raw_inspeccion') IS NULL
CREATE TABLE stg.raw_inspeccion (
    fila INT NOT NULL PRIMARY KEY,
    nro_alquiler NVARCHAR(400), codigo_articulo NVARCHAR(400), fecha_devolucion NVARCHAR(400),
    tipo_falla NVARCHAR(400), costo_reparacion NVARCHAR(400), dni_inspector NVARCHAR(400),
    observacion NVARCHAR(400));
GO

-- Lee una hoja del Excel a su tabla raw. La cabecera entra como fila 1 para que todo llegue como texto.
CREATE OR ALTER PROCEDURE etl.usp_LeerHoja
    @Archivo NVARCHAR(400), @Hoja NVARCHAR(40), @Tabla SYSNAME, @Cabecera NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj INT = OBJECT_ID(N'stg.' + QUOTENAME(@Tabla));
    DECLARE @cols NVARCHAR(MAX), @src NVARCHAR(MAX), @cab NVARCHAR(MAX), @sql NVARCHAR(MAX), @encontrada NVARCHAR(MAX), @msg NVARCHAR(2048);
    SELECT @cols = STRING_AGG(QUOTENAME(name), N', ') WITHIN GROUP (ORDER BY column_id),
           @src  = STRING_AGG(CONCAT(N'CAST(F', rn, N' AS NVARCHAR(400))'), N', ') WITHIN GROUP (ORDER BY column_id),
           @cab  = STRING_AGG(CONCAT(N'ISNULL(LTRIM(RTRIM(', QUOTENAME(name), N')), N'''')'), N', N''|'', ') WITHIN GROUP (ORDER BY column_id)
    FROM (SELECT name, column_id, ROW_NUMBER() OVER (ORDER BY column_id) AS rn
          FROM sys.columns WHERE object_id = @obj AND name <> N'fila') c;

    SET @sql = N'TRUNCATE TABLE stg.' + QUOTENAME(@Tabla) + N';
        INSERT INTO stg.' + QUOTENAME(@Tabla) + N' (fila, ' + @cols + N')
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), ' + @src + N'
        FROM OPENROWSET(''Microsoft.ACE.OLEDB.16.0'',
             ''Excel 12.0 Xml;HDR=NO;IMEX=1;Database=' + REPLACE(@Archivo, N'''', N'''''') + N''',
             ''SELECT * FROM [' + REPLACE(@Hoja, N']', N'') + N'$]'');';
    EXEC sys.sp_executesql @sql;

    -- La cabecera debe ser la esperada
    SET @sql = N'SELECT @c = CONCAT(' + @cab + N') FROM stg.' + QUOTENAME(@Tabla) + N' WHERE fila = 1;';
    EXEC sys.sp_executesql @sql, N'@c NVARCHAR(MAX) OUTPUT', @encontrada OUTPUT;
    IF ISNULL(@encontrada, N'') <> @Cabecera
    BEGIN
        SET @msg = CONCAT(N'La hoja ', @Hoja, N' no tiene las columnas esperadas. Encontrado: ', @encontrada);
        THROW 53001, @msg, 1;
    END;

    -- Quitar la cabecera y las filas vacías
    SET @sql = N'DELETE FROM stg.' + QUOTENAME(@Tabla) + N' WHERE fila = 1;
                 DELETE FROM stg.' + QUOTENAME(@Tabla) + N' WHERE COALESCE(' + @cols + N') IS NULL;';
    EXEC sys.sp_executesql @sql;
END;
GO

/* ---------- Excel ---------- */
DECLARE @Archivo NVARCHAR(400) = N'C:\ModaEstilo_BI-main\ETL\1_Fuentes_Excel\Fuentes_ModaEstilo.xlsx';

EXEC etl.usp_LeerHoja @Archivo, N'Catalogo', N'raw_catalogo',
     N'Código|Nombre|Categoría|Talla|Color|Costo Compra|Precio Alquiler|Precio Venta|Stock|Stock Mínimo';
EXEC etl.usp_LeerHoja @Archivo, N'Ventas', N'raw_ventas',
     N'N° Pedido|Fecha|DNI Cliente|Nombres|Apellidos|Teléfono|Distrito|Código Artículo|Cantidad|Precio Unitario|Canal|DNI Vendedor|Comprobante';
EXEC etl.usp_LeerHoja @Archivo, N'Alquileres', N'raw_alquileres',
     N'N° Alquiler|Fecha Alquiler|Fecha Entrega|Fecha Devolución Programada|DNI Cliente|Nombres|Apellidos|Teléfono|Distrito|Código Artículo|Cantidad|Precio Unitario|Canal|DNI Trabajador|Tipo Evento';
EXEC etl.usp_LeerHoja @Archivo, N'Inspeccion', N'raw_inspeccion',
     N'N° Alquiler|Código Artículo|Fecha Devolución|Tipo Falla|Costo Reparación|DNI Inspector|Observación';
GO

/* ---------- Base OLTP ModaEstilo_Final ---------- */
DROP TABLE IF EXISTS stg.oltp_Categoria, stg.oltp_Trabajador, stg.oltp_Cliente, stg.oltp_Articulo,
                     stg.oltp_Venta, stg.oltp_DetalleVenta, stg.oltp_Alquiler, stg.oltp_DetalleAlquiler,
                     stg.oltp_Devolucion, stg.oltp_Penalidad;
SELECT * INTO stg.oltp_Categoria       FROM ModaEstilo_Final.dbo.Categoria;
SELECT * INTO stg.oltp_Trabajador      FROM ModaEstilo_Final.dbo.Trabajador;
SELECT * INTO stg.oltp_Cliente         FROM ModaEstilo_Final.dbo.Cliente;
SELECT * INTO stg.oltp_Articulo        FROM ModaEstilo_Final.dbo.Articulo;
SELECT * INTO stg.oltp_Venta           FROM ModaEstilo_Final.dbo.Venta;
SELECT * INTO stg.oltp_DetalleVenta    FROM ModaEstilo_Final.dbo.DetalleVenta;
SELECT * INTO stg.oltp_Alquiler        FROM ModaEstilo_Final.dbo.Alquiler;
SELECT * INTO stg.oltp_DetalleAlquiler FROM ModaEstilo_Final.dbo.DetalleAlquiler;
SELECT * INTO stg.oltp_Devolucion      FROM ModaEstilo_Final.dbo.Devolucion;
SELECT * INTO stg.oltp_Penalidad       FROM ModaEstilo_Final.dbo.Penalidad;
GO

/* ---------- Resultado ---------- */
SELECT N'Excel - Catalogo' AS Origen, COUNT(*) AS Filas FROM stg.raw_catalogo
UNION ALL SELECT N'Excel - Ventas', COUNT(*) FROM stg.raw_ventas
UNION ALL SELECT N'Excel - Alquileres', COUNT(*) FROM stg.raw_alquileres
UNION ALL SELECT N'Excel - Inspeccion', COUNT(*) FROM stg.raw_inspeccion
UNION ALL SELECT N'OLTP - Cliente', COUNT(*) FROM stg.oltp_Cliente
UNION ALL SELECT N'OLTP - Articulo', COUNT(*) FROM stg.oltp_Articulo
UNION ALL SELECT N'OLTP - DetalleVenta', COUNT(*) FROM stg.oltp_DetalleVenta
UNION ALL SELECT N'OLTP - DetalleAlquiler', COUNT(*) FROM stg.oltp_DetalleAlquiler
UNION ALL SELECT N'OLTP - Devolucion', COUNT(*) FROM stg.oltp_Devolucion;

SELECT TOP (10) * FROM stg.raw_ventas ORDER BY fila;
