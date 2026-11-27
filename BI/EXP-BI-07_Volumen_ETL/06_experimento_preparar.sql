/* =====================================================================
   06 - EXPERIMENTO BI: PREPARAR (una sola vez)
   Crea la base ModaEstilo_Experimento con el mismo ETL de los scripts 02, 03 y 04
   convertido en procedimientos, para cronometrar cada etapa sin tocar ModaEstilo_DW.
   ===================================================================== */
IF DB_ID(N'ModaEstilo_Experimento') IS NULL
    CREATE DATABASE ModaEstilo_Experimento COLLATE Modern_Spanish_CI_AS;
GO
USE ModaEstilo_Experimento;
GO
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
IF SCHEMA_ID(N'dw')  IS NULL EXEC(N'CREATE SCHEMA dw');
IF SCHEMA_ID(N'exp') IS NULL EXEC(N'CREATE SCHEMA exp');
GO

-- ===== Extracción (de 02_extraccion.sql) =====
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

CREATE OR ALTER PROCEDURE exp.usp_Extraer @Archivo NVARCHAR(400) AS
BEGIN
    SET NOCOUNT ON;
    EXEC etl.usp_LeerHoja @Archivo, N'Catalogo', N'raw_catalogo',
         N'Código|Nombre|Categoría|Talla|Color|Costo Compra|Precio Alquiler|Precio Venta|Stock|Stock Mínimo';
    EXEC etl.usp_LeerHoja @Archivo, N'Ventas', N'raw_ventas',
         N'N° Pedido|Fecha|DNI Cliente|Nombres|Apellidos|Teléfono|Distrito|Código Artículo|Cantidad|Precio Unitario|Canal|DNI Vendedor|Comprobante';
    EXEC etl.usp_LeerHoja @Archivo, N'Alquileres', N'raw_alquileres',
         N'N° Alquiler|Fecha Alquiler|Fecha Entrega|Fecha Devolución Programada|DNI Cliente|Nombres|Apellidos|Teléfono|Distrito|Código Artículo|Cantidad|Precio Unitario|Canal|DNI Trabajador|Tipo Evento';
    EXEC etl.usp_LeerHoja @Archivo, N'Inspeccion', N'raw_inspeccion',
         N'N° Alquiler|Código Artículo|Fecha Devolución|Tipo Falla|Costo Reparación|DNI Inspector|Observación';
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
END;
GO

-- ===== Transformación (de 03_transformacion.sql) =====
-- Equivalencias: valor como viene en el Excel -> valor estándar
IF OBJECT_ID(N'etl.MapValor') IS NULL
CREATE TABLE etl.MapValor (
    dominio NVARCHAR(30) NOT NULL, valorOrigen NVARCHAR(100) NOT NULL, valorEstandar NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_MapValor PRIMARY KEY (dominio, valorOrigen));
GO
IF NOT EXISTS (SELECT 1 FROM etl.MapValor)
    INSERT INTO etl.MapValor (dominio, valorOrigen, valorEstandar) VALUES
    -- canales
    (N'CANAL', N'TIENDA FÍSICA', N'Tienda física'), (N'CANAL', N'TIENDA', N'Tienda física'),
    (N'CANAL', N'WHATSAPP', N'WhatsApp'), (N'CANAL', N'WSP', N'WhatsApp'), (N'CANAL', N'WSAP', N'WhatsApp'),
    (N'CANAL', N'INSTAGRAM', N'Instagram'), (N'CANAL', N'IG', N'Instagram'),
    (N'CANAL', N'FACEBOOK', N'Facebook'), (N'CANAL', N'FB', N'Facebook'),
    (N'CANAL', N'WEB', N'Web'), (N'CANAL', N'PÁGINA WEB', N'Web'),
    -- comprobantes
    (N'COMPROBANTE', N'BOLETA', N'Boleta'), (N'COMPROBANTE', N'FACTURA', N'Factura'),
    -- categorias
    (N'CATEGORIA', N'TERNOS', N'Ternos'), (N'CATEGORIA', N'VESTIDOS', N'Vestidos'),
    (N'CATEGORIA', N'CAMISAS', N'Camisas'), (N'CATEGORIA', N'ACCESORIOS', N'Accesorios'),
    (N'CATEGORIA', N'BLAZERS Y SACOS', N'Blazers y sacos'), (N'CATEGORIA', N'SACOS', N'Blazers y sacos'),
    (N'CATEGORIA', N'CALZADO', N'Calzado'), (N'CATEGORIA', N'TRAJES INFANTILES', N'Trajes infantiles'),
    (N'CATEGORIA', N'INFANTIL', N'Trajes infantiles'),
    -- tipos de evento
    (N'EVENTO', N'MATRIMONIO', N'Matrimonio'), (N'EVENTO', N'BODA', N'Matrimonio'),
    (N'EVENTO', N'GRADUACIÓN', N'Graduación'), (N'EVENTO', N'GRADUACION', N'Graduación'),
    (N'EVENTO', N'FIESTA DE PROMOCIÓN', N'Fiesta de promoción'), (N'EVENTO', N'FIESTA DE PROMOCION', N'Fiesta de promoción'),
    (N'EVENTO', N'BAUTIZO', N'Bautizo'), (N'EVENTO', N'EVENTO CORPORATIVO', N'Evento corporativo'),
    (N'EVENTO', N'QUINCEAÑERO', N'Quinceañero'), (N'EVENTO', N'QUINCEANERO', N'Quinceañero'),
    -- tipos de falla (inspeccion de devoluciones)
    (N'FALLA', N'NINGUNA', N'Ninguna'), (N'FALLA', N'SIN FALLA', N'Ninguna'),
    (N'FALLA', N'MANCHA', N'Mancha'), (N'FALLA', N'BOTÓN FALTANTE', N'Botón faltante'),
    (N'FALLA', N'BOTON FALTANTE', N'Botón faltante'), (N'FALLA', N'COSTURA ABIERTA', N'Costura abierta'),
    (N'FALLA', N'CIERRE DAÑADO', N'Cierre dañado'), (N'FALLA', N'CIERRE DANADO', N'Cierre dañado'),
    (N'FALLA', N'ROTURA DE TELA', N'Rotura de tela'), (N'FALLA', N'PÉRDIDA DE ACCESORIO', N'Pérdida de accesorio'),
    (N'FALLA', N'PERDIDA DE ACCESORIO', N'Pérdida de accesorio'), (N'FALLA', N'PÉRDIDA TOTAL', N'Pérdida total'),
    (N'FALLA', N'PERDIDA TOTAL', N'Pérdida total');
GO

-- Funciones de limpieza
-- Texto: quita espacios, saltos de linea y marcadores de vacio
CREATE OR ALTER FUNCTION etl.fn_Texto (@s NVARCHAR(400)) RETURNS NVARCHAR(400) AS
BEGIN
    DECLARE @r NVARCHAR(400) = TRIM(REPLACE(REPLACE(REPLACE(@s, CHAR(13), N''), CHAR(10), N''), NCHAR(160), N' '));
    WHILE CHARINDEX(N'  ', @r) > 0 SET @r = REPLACE(@r, N'  ', N' ');
    IF @r IN (N'', N'NULL', N'N/A', N'NA', N'-') SET @r = NULL;
    RETURN @r;
END;
GO
-- Fecha: acepta dd/mm/aaaa (formato peruano, con o sin hora), aaaa-mm-dd
-- o el numero de serie de Excel (ej. 46237) si la celda quedo en formato General.
CREATE OR ALTER FUNCTION etl.fn_Fecha (@s NVARCHAR(400)) RETURNS DATE AS
BEGIN
    DECLARE @t NVARCHAR(400) = etl.fn_Texto(@s);
    IF CHARINDEX(N' ', @t) > 0 SET @t = LEFT(@t, CHARINDEX(N' ', @t) - 1);   -- quita la hora
    RETURN CASE
        WHEN @t LIKE N'[0-9][0-9][0-9][0-9]-[0-9]%-[0-9]%' THEN TRY_CONVERT(date, @t, 23)
        WHEN @t LIKE N'[0-9]%/[0-9]%/[0-9][0-9][0-9][0-9]'  THEN TRY_CONVERT(date, @t, 103)
        WHEN @t NOT LIKE N'%[^0-9]%' AND LEN(@t) = 5        THEN DATEADD(DAY, CAST(@t AS INT) - 2, CONVERT(date, '19000101', 112))
    END;
END;
GO
-- Decimal: acepta 150.50 o 150,50 (coma decimal). Quita "S/".
CREATE OR ALTER FUNCTION etl.fn_Decimal (@s NVARCHAR(400)) RETURNS DECIMAL(12,2) AS
BEGIN
    DECLARE @t NVARCHAR(400) = REPLACE(REPLACE(etl.fn_Texto(@s), N'S/', N''), N' ', N'');
    IF @t LIKE N'%,%' AND @t NOT LIKE N'%.%' SET @t = REPLACE(@t, N',', N'.');   -- coma decimal
    ELSE SET @t = REPLACE(@t, N',', N'');                                        -- coma de miles
    RETURN TRY_CONVERT(DECIMAL(12,2), @t);
END;
GO
-- DNI: 8 digitos exactos. No se rellenan ceros (no se inventa el dato).
CREATE OR ALTER FUNCTION etl.fn_DNI (@s NVARCHAR(400)) RETURNS CHAR(8) AS
BEGIN
    DECLARE @t NVARCHAR(400) = etl.fn_Texto(@s);
    RETURN CASE WHEN LEN(@t) = 8 AND @t NOT LIKE N'%[^0-9]%' THEN @t END;
END;
GO
-- Busca el valor estandar en el diccionario etl.MapValor
CREATE OR ALTER FUNCTION etl.fn_Map (@dominio NVARCHAR(30), @s NVARCHAR(400)) RETURNS NVARCHAR(100) AS
BEGIN
    RETURN (SELECT valorEstandar FROM etl.MapValor
            WHERE dominio = @dominio AND valorOrigen = UPPER(etl.fn_Texto(@s)));
END;
GO

-- Tablas de datos limpios
IF OBJECT_ID(N'stg.Articulo') IS NULL
CREATE TABLE stg.Articulo (
    codigo VARCHAR(30) NOT NULL PRIMARY KEY, nombre NVARCHAR(100) NOT NULL, categoria NVARCHAR(100) NOT NULL,
    talla NVARCHAR(20) NULL, color NVARCHAR(50) NULL, costoCompra DECIMAL(12,2) NOT NULL,
    precioAlquiler DECIMAL(12,2) NOT NULL, precioVenta DECIMAL(12,2) NOT NULL, fuente VARCHAR(10) NOT NULL
);
IF OBJECT_ID(N'stg.Cliente') IS NULL
CREATE TABLE stg.Cliente (
    dni CHAR(8) NOT NULL PRIMARY KEY, nombres NVARCHAR(100) NOT NULL, apellidos NVARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NULL, distrito NVARCHAR(50) NULL, fechaRegistro DATE NULL, fuente VARCHAR(10) NOT NULL
);
IF OBJECT_ID(N'stg.Trabajador') IS NULL
CREATE TABLE stg.Trabajador (
    dni CHAR(8) NOT NULL PRIMARY KEY, nombres NVARCHAR(100) NOT NULL, apellidos NVARCHAR(100) NOT NULL,
    cargo NVARCHAR(50) NULL, estado NVARCHAR(20) NULL
);
IF OBJECT_ID(N'stg.Venta') IS NULL
CREATE TABLE stg.Venta (
    fuente VARCHAR(10) NOT NULL, nroDocumento NVARCHAR(20) NOT NULL, fecha DATE NOT NULL,
    dniCliente CHAR(8) NOT NULL, codigoArticulo VARCHAR(30) NOT NULL, dniTrabajador CHAR(8) NOT NULL,
    canal NVARCHAR(30) NOT NULL, comprobante NVARCHAR(20) NOT NULL, cantidad INT NOT NULL,
    precioUnitario DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_stgVenta PRIMARY KEY (fuente, nroDocumento, codigoArticulo)
);
IF OBJECT_ID(N'stg.Alquiler') IS NULL
CREATE TABLE stg.Alquiler (
    fuente VARCHAR(10) NOT NULL, nroAlquiler NVARCHAR(20) NOT NULL, fechaAlquiler DATE NOT NULL,
    fechaEntrega DATE NULL, fechaProgramada DATE NOT NULL, fechaReal DATE NULL,
    dniCliente CHAR(8) NOT NULL, codigoArticulo VARCHAR(30) NOT NULL, dniTrabajador CHAR(8) NOT NULL,
    canal NVARCHAR(30) NOT NULL, tipoEvento NVARCHAR(50) NOT NULL, cantidad INT NOT NULL,
    precioUnitario DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_stgAlquiler PRIMARY KEY (fuente, nroAlquiler, codigoArticulo)
);
IF OBJECT_ID(N'stg.Devolucion') IS NULL
CREATE TABLE stg.Devolucion (
    fuente VARCHAR(10) NOT NULL, fuenteAlquiler VARCHAR(10) NOT NULL, nroAlquiler NVARCHAR(20) NOT NULL,
    codigoArticulo VARCHAR(30) NOT NULL, fechaDevolucion DATE NOT NULL, tipoFalla NVARCHAR(50) NOT NULL,
    montoCargo DECIMAL(12,2) NOT NULL, dniInspector CHAR(8) NULL, observacion NVARCHAR(250) NULL,
    CONSTRAINT PK_stgDevolucion PRIMARY KEY (fuenteAlquiler, nroAlquiler, codigoArticulo)
);
IF OBJECT_ID(N'etl.Rechazo') IS NULL
CREATE TABLE etl.Rechazo (
    idRechazo INT IDENTITY(1,1) PRIMARY KEY, hoja NVARCHAR(40) NOT NULL, fila INT NOT NULL,
    clave NVARCHAR(60) NULL, tipo NVARCHAR(20) NOT NULL, motivo NVARCHAR(200) NOT NULL, registro NVARCHAR(2000) NULL);
GO

CREATE OR ALTER PROCEDURE exp.usp_Transformar @FechaCorte DATE AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE etl.Rechazo;
    TRUNCATE TABLE stg.Articulo;  TRUNCATE TABLE stg.Cliente;  TRUNCATE TABLE stg.Trabajador;
    TRUNCATE TABLE stg.Venta;     TRUNCATE TABLE stg.Alquiler; TRUNCATE TABLE stg.Devolucion;

    /* ---------- 1. TRABAJADORES (solo OLTP) ---------- */
    INSERT INTO stg.Trabajador (dni, nombres, apellidos, cargo, estado)
    SELECT etl.fn_DNI(dni), etl.fn_Texto(nombres), etl.fn_Texto(apellidos), etl.fn_Texto(cargo), etl.fn_Texto(estado)
    FROM stg.oltp_Trabajador WHERE etl.fn_DNI(dni) IS NOT NULL;

    /* ---------- 2. ARTICULOS: OLTP + hoja Catalogo ---------- */
    INSERT INTO stg.Articulo (codigo, nombre, categoria, talla, color, costoCompra, precioAlquiler, precioVenta, fuente)
    SELECT UPPER(etl.fn_Texto(a.codigo)), etl.fn_Texto(a.nombre), ISNULL(etl.fn_Map(N'CATEGORIA', c.nombreCategoria), c.nombreCategoria),
           etl.fn_Texto(a.talla), etl.fn_Texto(a.color), ISNULL(a.costoCompra, 0), ISNULL(a.precioAlquiler, 0),
           ISNULL(a.precioVenta, 0), 'OLTP'
    FROM stg.oltp_Articulo a JOIN stg.oltp_Categoria c ON c.idCategoria = a.idCategoria;

    SELECT r.fila, x.*,
           CONCAT(r.codigo, N';', r.nombre, N';', r.categoria, N';', r.talla, N';', r.color, N';', r.costo_compra, N';', r.precio_alquiler, N';', r.precio_venta, N';', r.stock, N';', r.stock_minimo) AS registro,
           CAST(NULL AS NVARCHAR(200)) AS motivo, CAST(NULL AS NVARCHAR(20)) AS tipo
    INTO #cat
    FROM stg.raw_catalogo r
    CROSS APPLY (SELECT UPPER(etl.fn_Texto(r.codigo)) AS codigo, etl.fn_Texto(r.nombre) AS nombre,
                        etl.fn_Map(N'CATEGORIA', r.categoria) AS categoria, etl.fn_Texto(r.categoria) AS categoriaTxt,
                        etl.fn_Texto(r.talla) AS talla, etl.fn_Texto(r.color) AS color,
                        etl.fn_Decimal(r.costo_compra) AS costo, etl.fn_Decimal(r.precio_alquiler) AS pAlq,
                        etl.fn_Decimal(r.precio_venta) AS pVen) x;

    WITH c AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY codigo, nombre, categoria, talla, color, costo, pAlq, pVen ORDER BY fila) AS rnExacto,
                  ROW_NUMBER() OVER (PARTITION BY codigo ORDER BY fila) AS rnClave
        FROM #cat)
    UPDATE c SET motivo = CASE
        WHEN rnExacto > 1 THEN N'Duplicado exacto de una línea anterior'
        WHEN codigo IS NULL THEN N'Código vacío'
        WHEN EXISTS (SELECT 1 FROM stg.Articulo s WHERE s.codigo = c.codigo AND s.fuente = 'OLTP')
             THEN N'El código ya existe en el OLTP (el sistema OLTP es la fuente oficial)'
        WHEN nombre IS NULL THEN N'Nombre vacío'
        WHEN categoria IS NULL THEN CONCAT(N'Categoría no reconocida: ', categoriaTxt)
        WHEN costo IS NULL OR costo < 0 THEN N'Costo de compra vacío, no numérico o negativo'
        WHEN pAlq IS NULL OR pAlq < 0 THEN N'Precio de alquiler vacío, no numérico o negativo'
        WHEN pVen IS NULL OR pVen < 0 THEN N'Precio de venta vacío, no numérico o negativo'
        WHEN rnClave > 1 THEN N'Código repetido con datos distintos'
    END,
    tipo = CASE WHEN rnExacto > 1 THEN N'DUPLICADO' ELSE N'RECHAZO' END;

    INSERT INTO stg.Articulo (codigo, nombre, categoria, talla, color, costoCompra, precioAlquiler, precioVenta, fuente)
    SELECT codigo, nombre, categoria, talla, color, costo, pAlq, pVen, 'ARCHIVO' FROM #cat WHERE motivo IS NULL;

    /* ---------- 3. VENTAS (hoja Ventas) ---------- */
    SELECT r.fila, x.*,
           CONCAT(r.nro_pedido, N';', r.fecha, N';', r.dni_cliente, N';', r.nombres, N';', r.apellidos, N';', r.telefono, N';', r.distrito, N';', r.codigo_articulo, N';', r.cantidad, N';', r.precio_unitario, N';', r.canal, N';', r.dni_vendedor, N';', r.comprobante) AS registro,
           CAST(NULL AS NVARCHAR(200)) AS motivo, CAST(NULL AS NVARCHAR(20)) AS tipo
    INTO #ven
    FROM stg.raw_ventas r
    CROSS APPLY (SELECT etl.fn_Texto(r.nro_pedido) AS nro, etl.fn_Fecha(r.fecha) AS fecha, etl.fn_Texto(r.fecha) AS fechaTxt,
                        etl.fn_DNI(r.dni_cliente) AS dni, etl.fn_Texto(r.dni_cliente) AS dniTxt,
                        etl.fn_Texto(r.nombres) AS nombres, etl.fn_Texto(r.apellidos) AS apellidos,
                        etl.fn_Texto(r.telefono) AS telefono, etl.fn_Texto(r.distrito) AS distrito,
                        UPPER(etl.fn_Texto(r.codigo_articulo)) AS codigo,
                        TRY_CONVERT(INT, etl.fn_Texto(r.cantidad)) AS cantidad, etl.fn_Decimal(r.precio_unitario) AS precio,
                        etl.fn_Map(N'CANAL', r.canal) AS canal, etl.fn_Texto(r.canal) AS canalTxt,
                        etl.fn_DNI(r.dni_vendedor) AS dniVend, etl.fn_Map(N'COMPROBANTE', r.comprobante) AS comprobante) x;

    WITH c AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY nro, fecha, dni, nombres, apellidos, telefono, distrito, codigo,
                                                  cantidad, precio, canal, dniVend, comprobante ORDER BY fila) AS rnExacto,
                  ROW_NUMBER() OVER (PARTITION BY nro, codigo ORDER BY fila) AS rnClave
        FROM #ven)
    UPDATE c SET motivo = CASE
        WHEN rnExacto > 1 THEN N'Duplicado exacto de una línea anterior'
        WHEN nro IS NULL THEN N'Número de pedido vacío'
        WHEN fecha IS NULL THEN CONCAT(N'Fecha inválida: ', fechaTxt)
        WHEN fecha > @FechaCorte THEN N'Fecha futura (posterior a la fecha de corte)'
        WHEN fecha < '20250101' THEN N'Fecha fuera del calendario del DW'
        WHEN dni IS NULL THEN CONCAT(N'DNI de cliente inválido (debe tener 8 dígitos): ', dniTxt)
        WHEN (nombres IS NULL OR apellidos IS NULL) AND NOT EXISTS (SELECT 1 FROM stg.oltp_Cliente o WHERE o.dni = c.dni)
             THEN N'Cliente nuevo sin nombres o apellidos'
        WHEN NOT EXISTS (SELECT 1 FROM stg.Articulo a WHERE a.codigo = c.codigo) THEN CONCAT(N'Artículo no existe: ', codigo)
        WHEN cantidad IS NULL OR cantidad <= 0 THEN N'Cantidad vacía, no numérica o menor a 1'
        WHEN precio IS NULL OR precio < 0 THEN N'Precio unitario vacío, no numérico o negativo'
        WHEN canal IS NULL THEN CONCAT(N'Canal no reconocido: ', canalTxt)
        WHEN NOT EXISTS (SELECT 1 FROM stg.Trabajador t WHERE t.dni = c.dniVend) THEN N'Vendedor no registrado en el OLTP'
        WHEN comprobante IS NULL THEN N'Tipo de comprobante no reconocido'
        WHEN rnClave > 1 THEN N'Mismo pedido y artículo repetido con datos distintos'
    END,
    tipo = CASE WHEN rnExacto > 1 THEN N'DUPLICADO' ELSE N'RECHAZO' END;

    -- Todas las lineas validas de un pedido deben tener la misma cabecera
    WITH c AS (
        SELECT *, MIN(CONCAT(fecha, dni, canal, dniVend, comprobante)) OVER (PARTITION BY nro) AS mn,
                  MAX(CONCAT(fecha, dni, canal, dniVend, comprobante)) OVER (PARTITION BY nro) AS mx
        FROM #ven WHERE motivo IS NULL)
    UPDATE c SET motivo = N'Líneas del mismo pedido con fecha/cliente/canal distintos', tipo = N'RECHAZO'
    WHERE mn <> mx;

    /* ---------- 4. ALQUILERES (hoja Alquileres) ---------- */
    SELECT r.fila, x.*,
           CONCAT(r.nro_alquiler, N';', r.fecha_alquiler, N';', r.fecha_entrega, N';', r.fecha_devolucion_programada, N';', r.dni_cliente, N';', r.nombres, N';', r.apellidos, N';', r.telefono, N';', r.distrito, N';', r.codigo_articulo, N';', r.cantidad, N';', r.precio_unitario, N';', r.canal, N';', r.dni_trabajador, N';', r.tipo_evento) AS registro,
           CAST(NULL AS NVARCHAR(200)) AS motivo, CAST(NULL AS NVARCHAR(20)) AS tipo
    INTO #alq
    FROM stg.raw_alquileres r
    CROSS APPLY (SELECT etl.fn_Texto(r.nro_alquiler) AS nro,
                        etl.fn_Fecha(r.fecha_alquiler) AS fAlq, etl.fn_Texto(r.fecha_alquiler) AS fAlqTxt,
                        etl.fn_Fecha(r.fecha_entrega) AS fEnt, etl.fn_Texto(r.fecha_entrega) AS fEntTxt,
                        etl.fn_Fecha(r.fecha_devolucion_programada) AS fProg,
                        etl.fn_DNI(r.dni_cliente) AS dni, etl.fn_Texto(r.dni_cliente) AS dniTxt,
                        etl.fn_Texto(r.nombres) AS nombres, etl.fn_Texto(r.apellidos) AS apellidos,
                        etl.fn_Texto(r.telefono) AS telefono, etl.fn_Texto(r.distrito) AS distrito,
                        UPPER(etl.fn_Texto(r.codigo_articulo)) AS codigo,
                        TRY_CONVERT(INT, etl.fn_Texto(r.cantidad)) AS cantidad, etl.fn_Decimal(r.precio_unitario) AS precio,
                        etl.fn_Map(N'CANAL', r.canal) AS canal, etl.fn_Texto(r.canal) AS canalTxt,
                        etl.fn_DNI(r.dni_trabajador) AS dniTrab,
                        etl.fn_Map(N'EVENTO', r.tipo_evento) AS evento, etl.fn_Texto(r.tipo_evento) AS eventoTxt) x;

    WITH c AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY nro, fAlq, fEnt, fProg, dni, nombres, apellidos, telefono, distrito,
                                                  codigo, cantidad, precio, canal, dniTrab, evento ORDER BY fila) AS rnExacto,
                  ROW_NUMBER() OVER (PARTITION BY nro, codigo ORDER BY fila) AS rnClave
        FROM #alq)
    UPDATE c SET motivo = CASE
        WHEN rnExacto > 1 THEN N'Duplicado exacto de una línea anterior'
        WHEN nro IS NULL THEN N'Número de alquiler vacío'
        WHEN fAlq IS NULL THEN CONCAT(N'Fecha de alquiler inválida: ', fAlqTxt)
        WHEN fEnt IS NULL THEN CONCAT(N'Fecha de entrega inválida: ', fEntTxt)
        WHEN fProg IS NULL THEN N'Fecha de devolución programada inválida'
        WHEN fAlq > @FechaCorte THEN N'Fecha futura (posterior a la fecha de corte)'
        WHEN fAlq < '20250101' OR fProg > '20271231' THEN N'Fecha fuera del calendario del DW'
        WHEN fEnt < fAlq THEN N'Entrega anterior a la fecha de alquiler'
        WHEN fProg < fEnt THEN N'Devolución programada anterior a la entrega'
        WHEN dni IS NULL THEN CONCAT(N'DNI de cliente inválido (debe tener 8 dígitos): ', dniTxt)
        WHEN (nombres IS NULL OR apellidos IS NULL) AND NOT EXISTS (SELECT 1 FROM stg.oltp_Cliente o WHERE o.dni = c.dni)
             THEN N'Cliente nuevo sin nombres o apellidos'
        WHEN NOT EXISTS (SELECT 1 FROM stg.Articulo a WHERE a.codigo = c.codigo) THEN CONCAT(N'Artículo no existe: ', codigo)
        WHEN cantidad IS NULL OR cantidad <= 0 THEN N'Cantidad vacía, no numérica o menor a 1'
        WHEN precio IS NULL OR precio < 0 THEN N'Precio unitario vacío, no numérico o negativo'
        WHEN canal IS NULL THEN CONCAT(N'Canal no reconocido: ', canalTxt)
        WHEN NOT EXISTS (SELECT 1 FROM stg.Trabajador t WHERE t.dni = c.dniTrab) THEN N'Trabajador no registrado en el OLTP'
        WHEN evento IS NULL THEN CONCAT(N'Tipo de evento no reconocido: ', eventoTxt)
        WHEN rnClave > 1 THEN N'Mismo alquiler y artículo repetido con datos distintos'
    END,
    tipo = CASE WHEN rnExacto > 1 THEN N'DUPLICADO' ELSE N'RECHAZO' END;

    WITH c AS (
        SELECT *, MIN(CONCAT(fAlq, fEnt, fProg, dni, canal, dniTrab, evento)) OVER (PARTITION BY nro) AS mn,
                  MAX(CONCAT(fAlq, fEnt, fProg, dni, canal, dniTrab, evento)) OVER (PARTITION BY nro) AS mx
        FROM #alq WHERE motivo IS NULL)
    UPDATE c SET motivo = N'Líneas del mismo alquiler con fechas/cliente/canal distintos', tipo = N'RECHAZO'
    WHERE mn <> mx;

    /* ---------- 5. CLIENTES: OLTP manda; el Excel aporta clientes nuevos y el distrito ---------- */
    SELECT dni, nombres, apellidos, telefono, distrito, fecha, origen, fila
    INTO #cliArch
    FROM (SELECT dni, nombres, apellidos, telefono, distrito, fecha, 1 AS origen, fila FROM #ven WHERE motivo IS NULL
          UNION ALL
          SELECT dni, nombres, apellidos, telefono, distrito, fAlq, 2, fila FROM #alq WHERE motivo IS NULL) u;

    INSERT INTO stg.Cliente (dni, nombres, apellidos, telefono, distrito, fechaRegistro, fuente)
    SELECT etl.fn_DNI(o.dni), etl.fn_Texto(o.nombres), etl.fn_Texto(o.apellidos), etl.fn_Texto(o.telefono),
           d.distrito, o.fechaRegistro, 'OLTP'
    FROM stg.oltp_Cliente o
    OUTER APPLY (SELECT TOP (1) a.distrito FROM #cliArch a
                 WHERE a.dni = o.dni AND a.distrito IS NOT NULL ORDER BY a.fecha DESC, a.origen, a.fila DESC) d
    WHERE etl.fn_DNI(o.dni) IS NOT NULL;

    INSERT INTO stg.Cliente (dni, nombres, apellidos, telefono, distrito, fechaRegistro, fuente)
    SELECT dni, nombres, apellidos, telefono, distrito, primeraFecha, 'ARCHIVO'
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY dni ORDER BY fecha DESC, origen, fila DESC) AS rn,  -- dato mas reciente
                    MIN(fecha) OVER (PARTITION BY dni) AS primeraFecha
          FROM #cliArch WHERE NOT EXISTS (SELECT 1 FROM stg.Cliente s WHERE s.dni = #cliArch.dni)) z
    WHERE rn = 1;

    /* ---------- 6. VENTAS y ALQUILERES a staging limpio ---------- */
    INSERT INTO stg.Venta (fuente, nroDocumento, fecha, dniCliente, codigoArticulo, dniTrabajador, canal, comprobante, cantidad, precioUnitario)
    SELECT 'OLTP', CAST(v.idVenta AS NVARCHAR(20)), v.fechaVenta, etl.fn_DNI(c.dni), UPPER(etl.fn_Texto(a.codigo)),
           etl.fn_DNI(t.dni), N'Tienda física', ISNULL(etl.fn_Map(N'COMPROBANTE', v.tipoComprobante), N'Boleta'),
           d.cantidad, d.precioUnitario
    FROM stg.oltp_Venta v
    JOIN stg.oltp_DetalleVenta d ON d.idVenta = v.idVenta
    JOIN stg.oltp_Cliente c ON c.idCliente = v.idCliente
    JOIN stg.oltp_Trabajador t ON t.idTrabajador = v.idTrabajador
    JOIN stg.oltp_Articulo a ON a.idArticulo = d.idArticulo;

    INSERT INTO stg.Venta (fuente, nroDocumento, fecha, dniCliente, codigoArticulo, dniTrabajador, canal, comprobante, cantidad, precioUnitario)
    SELECT 'EXCEL', nro, fecha, dni, codigo, dniVend, canal, comprobante, cantidad, precio FROM #ven WHERE motivo IS NULL;

    INSERT INTO stg.Alquiler (fuente, nroAlquiler, fechaAlquiler, fechaEntrega, fechaProgramada, fechaReal, dniCliente,
                              codigoArticulo, dniTrabajador, canal, tipoEvento, cantidad, precioUnitario)
    SELECT 'OLTP', CAST(a.idAlquiler AS NVARCHAR(20)), a.fechaAlquiler, a.fechaEntrega, a.fechaDevolucionProgramada,
           a.fechaDevolucionReal, etl.fn_DNI(c.dni), UPPER(etl.fn_Texto(ar.codigo)), etl.fn_DNI(t.dni),
           N'Tienda física', N'No registrado', d.cantidad, d.precioUnitario
    FROM stg.oltp_Alquiler a
    JOIN stg.oltp_DetalleAlquiler d ON d.idAlquiler = a.idAlquiler
    JOIN stg.oltp_Cliente c ON c.idCliente = a.idCliente
    JOIN stg.oltp_Trabajador t ON t.idTrabajador = a.idTrabajador
    JOIN stg.oltp_Articulo ar ON ar.idArticulo = d.idArticulo;

    INSERT INTO stg.Alquiler (fuente, nroAlquiler, fechaAlquiler, fechaEntrega, fechaProgramada, fechaReal, dniCliente,
                              codigoArticulo, dniTrabajador, canal, tipoEvento, cantidad, precioUnitario)
    SELECT 'EXCEL', nro, fAlq, fEnt, fProg, NULL, dni, codigo, dniTrab, canal, evento, cantidad, precio
    FROM #alq WHERE motivo IS NULL;

    /* ---------- 7. DEVOLUCIONES: OLTP + hoja Inspeccion ---------- */
    -- OLTP: la penalidad se asigna a la primera prenda del alquiler para no duplicarla
    INSERT INTO stg.Devolucion (fuente, fuenteAlquiler, nroAlquiler, codigoArticulo, fechaDevolucion, tipoFalla, montoCargo, dniInspector, observacion)
    SELECT 'OLTP', 'OLTP', CAST(dv.idAlquiler AS NVARCHAR(20)), UPPER(etl.fn_Texto(ar.codigo)), dv.fechaDevolucion,
           CASE WHEN p.hayDanio = 1 AND x.rn = 1 THEN N'Daño no especificado' ELSE N'Ninguna' END,
           CASE WHEN x.rn = 1 THEN ISNULL(p.monto, 0) ELSE 0 END, NULL, etl.fn_Texto(dv.observaciones)
    FROM stg.oltp_Devolucion dv
    JOIN (SELECT d.*, ROW_NUMBER() OVER (PARTITION BY d.idAlquiler ORDER BY d.idDetalleAlquiler) AS rn
          FROM stg.oltp_DetalleAlquiler d) x ON x.idAlquiler = dv.idAlquiler
    JOIN stg.oltp_Articulo ar ON ar.idArticulo = x.idArticulo
    OUTER APPLY (SELECT SUM(pe.monto) AS monto, MAX(CASE WHEN pe.tipoPenalidad = N'Daño' THEN 1 ELSE 0 END) AS hayDanio
                 FROM stg.oltp_Penalidad pe WHERE pe.idDevolucion = dv.idDevolucion) p;

    SELECT r.fila, x.*, f.fuenteAlq,
           CONCAT(r.nro_alquiler, N'|', r.codigo_articulo, N'|', r.fecha_devolucion, N'|', r.tipo_falla, N'|', r.costo_reparacion, N'|', r.dni_inspector, N'|', r.observacion) AS registro,
           CAST(NULL AS NVARCHAR(200)) AS motivo, CAST(NULL AS NVARCHAR(20)) AS tipo
    INTO #ins
    FROM stg.raw_inspeccion r
    CROSS APPLY (SELECT etl.fn_Texto(r.nro_alquiler) AS nro, UPPER(etl.fn_Texto(r.codigo_articulo)) AS codigo,
                        etl.fn_Fecha(r.fecha_devolucion) AS fDev, etl.fn_Texto(r.fecha_devolucion) AS fDevTxt,
                        etl.fn_Map(N'FALLA', r.tipo_falla) AS falla, etl.fn_Texto(r.tipo_falla) AS fallaTxt,
                        etl.fn_Decimal(r.costo_reparacion) AS costo, etl.fn_Texto(r.costo_reparacion) AS costoTxt,
                        etl.fn_DNI(r.dni_inspector) AS dniInsp, etl.fn_Texto(r.observacion) AS observacion) x
    CROSS APPLY (SELECT CASE WHEN x.nro NOT LIKE N'%[^0-9]%' THEN 'OLTP'        -- numero simple = contrato del OLTP
                             WHEN x.nro LIKE N'RED-%' THEN 'EXCEL' END AS fuenteAlq) f;

    WITH c AS (
        SELECT i.*, a.fechaEntrega, a.fechaReal AS fechaRealOltp,
               ROW_NUMBER() OVER (PARTITION BY i.nro, i.codigo, i.fDev, i.falla, i.costo, i.dniInsp, i.observacion ORDER BY i.fila) AS rnExacto,
               ROW_NUMBER() OVER (PARTITION BY i.nro, i.codigo ORDER BY i.fila) AS rnClave
        FROM #ins i
        LEFT JOIN stg.Alquiler a ON a.fuente = i.fuenteAlq AND a.nroAlquiler = i.nro AND a.codigoArticulo = i.codigo)
    UPDATE c SET motivo = CASE
        WHEN rnExacto > 1 THEN N'Duplicado exacto de una línea anterior'
        WHEN nro IS NULL THEN N'Número de alquiler vacío'
        WHEN fuenteAlq IS NULL THEN CONCAT(N'Número de alquiler con formato desconocido: ', nro)
        WHEN fechaEntrega IS NULL AND NOT EXISTS (SELECT 1 FROM stg.Alquiler a2 WHERE a2.fuente = c.fuenteAlq AND a2.nroAlquiler = c.nro AND a2.codigoArticulo = c.codigo)
             THEN N'El alquiler/artículo no existe o fue rechazado'
        WHEN fechaRealOltp IS NOT NULL THEN N'La devolución ya está registrada en el OLTP'
        WHEN fDev IS NULL THEN CONCAT(N'Fecha de devolución inválida: ', fDevTxt)
        WHEN fDev > @FechaCorte THEN N'Fecha futura (posterior a la fecha de corte)'
        WHEN fDev < fechaEntrega THEN N'Devolución anterior a la fecha de entrega'
        WHEN falla IS NULL THEN CONCAT(N'Tipo de falla no catalogado: ', fallaTxt)
        WHEN costoTxt IS NOT NULL AND costo IS NULL THEN CONCAT(N'Costo no numérico: ', costoTxt)
        WHEN falla <> N'Ninguna' AND costo IS NULL THEN N'Falla registrada sin costo de reparación'
        WHEN falla = N'Ninguna' AND costo > 0 THEN N'Costo mayor a 0 con falla "Ninguna"'
        WHEN costo < 0 THEN N'Costo negativo'
        WHEN NOT EXISTS (SELECT 1 FROM stg.Trabajador t WHERE t.dni = c.dniInsp) THEN N'Inspector no registrado en el OLTP'
        WHEN rnClave > 1 THEN N'Misma prenda inspeccionada dos veces con datos distintos'
    END,
    tipo = CASE WHEN rnExacto > 1 THEN N'DUPLICADO' ELSE N'RECHAZO' END;

    INSERT INTO stg.Devolucion (fuente, fuenteAlquiler, nroAlquiler, codigoArticulo, fechaDevolucion, tipoFalla, montoCargo, dniInspector, observacion)
    SELECT 'INSPECCION', fuenteAlq, nro, codigo, fDev, falla, ISNULL(costo, 0), dniInsp, observacion
    FROM #ins WHERE motivo IS NULL;

    -- La inspeccion completa la fecha real de devolucion del alquiler
    UPDATE a SET fechaReal = d.fechaDevolucion
    FROM stg.Alquiler a
    JOIN stg.Devolucion d ON d.fuente = 'INSPECCION' AND d.fuenteAlquiler = a.fuente
                         AND d.nroAlquiler = a.nroAlquiler AND d.codigoArticulo = a.codigoArticulo
    WHERE a.fechaReal IS NULL;

    /* ---------- Filas rechazadas y duplicadas ---------- */
    INSERT INTO etl.Rechazo (hoja, fila, clave, tipo, motivo, registro)
    SELECT N'Catalogo', fila, codigo, tipo, motivo, registro FROM #cat WHERE motivo IS NOT NULL
    UNION ALL SELECT N'Ventas', fila, CONCAT(nro, N' / ', codigo), tipo, motivo, registro FROM #ven WHERE motivo IS NOT NULL
    UNION ALL SELECT N'Alquileres', fila, CONCAT(nro, N' / ', codigo), tipo, motivo, registro FROM #alq WHERE motivo IS NOT NULL
    UNION ALL SELECT N'Inspeccion', fila, CONCAT(nro, N' / ', codigo), tipo, motivo, registro FROM #ins WHERE motivo IS NOT NULL;
END;
GO

-- ===== Carga (de 04_carga.sql) =====
IF OBJECT_ID(N'dw.DimFecha') IS NULL
CREATE TABLE dw.DimFecha (
    FechaKey INT NOT NULL PRIMARY KEY, Fecha DATE NOT NULL UNIQUE, Anio INT NOT NULL, Trimestre INT NOT NULL,
    MesNumero INT NOT NULL, MesNombre NVARCHAR(20) NOT NULL, AnioMes CHAR(7) NOT NULL, DiaMes INT NOT NULL,
    DiaSemanaNumero INT NOT NULL, DiaSemanaNombre NVARCHAR(15) NOT NULL, EsFinSemana BIT NOT NULL
);
IF OBJECT_ID(N'dw.DimCliente') IS NULL
CREATE TABLE dw.DimCliente (
    ClienteKey INT IDENTITY(1,1) PRIMARY KEY, DNI CHAR(8) NOT NULL UNIQUE,
    Nombres NVARCHAR(100) NOT NULL, Apellidos NVARCHAR(100) NOT NULL, Cliente NVARCHAR(201) NOT NULL,
    Telefono VARCHAR(20) NULL, Distrito NVARCHAR(50) NOT NULL, FechaRegistro DATE NULL,
    FuenteOrigen VARCHAR(10) NOT NULL, FechaActualizacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
IF OBJECT_ID(N'dw.DimArticulo') IS NULL
CREATE TABLE dw.DimArticulo (
    ArticuloKey INT IDENTITY(1,1) PRIMARY KEY, Codigo VARCHAR(30) NOT NULL UNIQUE,
    Articulo NVARCHAR(100) NOT NULL, Categoria NVARCHAR(100) NOT NULL, Talla NVARCHAR(20) NULL,
    Color NVARCHAR(50) NULL, CostoCompra DECIMAL(12,2) NOT NULL, PrecioAlquiler DECIMAL(12,2) NOT NULL,
    PrecioVenta DECIMAL(12,2) NOT NULL, FuenteOrigen VARCHAR(10) NOT NULL,
    FechaActualizacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
IF OBJECT_ID(N'dw.DimTrabajador') IS NULL
CREATE TABLE dw.DimTrabajador (
    TrabajadorKey INT IDENTITY(1,1) PRIMARY KEY, DNI CHAR(8) NOT NULL UNIQUE,
    Trabajador NVARCHAR(201) NOT NULL, Cargo NVARCHAR(50) NOT NULL, Estado NVARCHAR(20) NOT NULL,
    FechaActualizacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
IF OBJECT_ID(N'dw.DimCanal') IS NULL
CREATE TABLE dw.DimCanal (
    CanalKey INT NOT NULL PRIMARY KEY, Canal NVARCHAR(30) NOT NULL UNIQUE, TipoCanal NVARCHAR(20) NOT NULL
);
IF OBJECT_ID(N'dw.DimFalla') IS NULL
CREATE TABLE dw.DimFalla (
    FallaKey INT NOT NULL PRIMARY KEY, TipoFalla NVARCHAR(50) NOT NULL UNIQUE,
    Gravedad NVARCHAR(20) NOT NULL, Accion NVARCHAR(20) NOT NULL
);
GO
IF OBJECT_ID(N'dw.FactVenta') IS NULL
CREATE TABLE dw.FactVenta (
    VentaKey INT IDENTITY(1,1) PRIMARY KEY,
    Fuente VARCHAR(10) NOT NULL, NroDocumento NVARCHAR(20) NOT NULL,
    FechaKey INT NOT NULL REFERENCES dw.DimFecha(FechaKey),
    ClienteKey INT NOT NULL REFERENCES dw.DimCliente(ClienteKey),
    ArticuloKey INT NOT NULL REFERENCES dw.DimArticulo(ArticuloKey),
    TrabajadorKey INT NOT NULL REFERENCES dw.DimTrabajador(TrabajadorKey),
    CanalKey INT NOT NULL REFERENCES dw.DimCanal(CanalKey),
    Comprobante NVARCHAR(20) NOT NULL,
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(12,2) NOT NULL,
    ImporteVenta DECIMAL(12,2) NOT NULL,
    CostoVenta DECIMAL(12,2) NOT NULL,
    MargenBruto DECIMAL(12,2) NOT NULL,
    CONSTRAINT UQ_FactVenta UNIQUE (Fuente, NroDocumento, ArticuloKey)
);
IF OBJECT_ID(N'dw.FactAlquiler') IS NULL
CREATE TABLE dw.FactAlquiler (
    AlquilerKey INT IDENTITY(1,1) PRIMARY KEY,
    Fuente VARCHAR(10) NOT NULL, NroAlquiler NVARCHAR(20) NOT NULL,
    FechaAlquilerKey INT NOT NULL REFERENCES dw.DimFecha(FechaKey),
    FechaEntregaKey INT NULL REFERENCES dw.DimFecha(FechaKey),
    FechaProgramadaKey INT NOT NULL REFERENCES dw.DimFecha(FechaKey),
    FechaDevolucionKey INT NULL REFERENCES dw.DimFecha(FechaKey),
    ClienteKey INT NOT NULL REFERENCES dw.DimCliente(ClienteKey),
    ArticuloKey INT NOT NULL REFERENCES dw.DimArticulo(ArticuloKey),
    TrabajadorKey INT NOT NULL REFERENCES dw.DimTrabajador(TrabajadorKey),
    CanalKey INT NOT NULL REFERENCES dw.DimCanal(CanalKey),
    TipoEvento NVARCHAR(50) NOT NULL,
    EstadoAlquiler NVARCHAR(20) NOT NULL,      -- Devuelto / En curso / Vencido
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(12,2) NOT NULL,
    ImporteAlquiler DECIMAL(12,2) NOT NULL,
    DiasRetraso INT NULL,                      -- NULL si aun no se devuelve
    CONSTRAINT UQ_FactAlquiler UNIQUE (Fuente, NroAlquiler, ArticuloKey)
);
IF OBJECT_ID(N'dw.FactDevolucion') IS NULL
CREATE TABLE dw.FactDevolucion (
    DevolucionKey INT IDENTITY(1,1) PRIMARY KEY,
    Fuente VARCHAR(10) NOT NULL,               -- OLTP o INSPECCION (hoja del Excel)
    FuenteAlquiler VARCHAR(10) NOT NULL, NroAlquiler NVARCHAR(20) NOT NULL,
    FechaDevolucionKey INT NOT NULL REFERENCES dw.DimFecha(FechaKey),
    ClienteKey INT NOT NULL REFERENCES dw.DimCliente(ClienteKey),
    ArticuloKey INT NOT NULL REFERENCES dw.DimArticulo(ArticuloKey),
    InspectorKey INT NOT NULL REFERENCES dw.DimTrabajador(TrabajadorKey),
    FallaKey INT NOT NULL REFERENCES dw.DimFalla(FallaKey),
    TipoDevolucion NVARCHAR(30) NOT NULL,      -- A tiempo / Con retraso / Con falla / Con retraso y falla
    DiasRetraso INT NOT NULL,
    MontoCargo DECIMAL(12,2) NOT NULL,         -- penalidad o costo de reparacion/reposicion
    Observacion NVARCHAR(250) NULL,
    CONSTRAINT UQ_FactDevolucion UNIQUE (FuenteAlquiler, NroAlquiler, ArticuloKey)
);
GO

IF NOT EXISTS (SELECT 1 FROM dw.DimFecha)
BEGIN
    ;WITH D AS (
        SELECT DATEADD(DAY, value, CONVERT(date, '20250101', 112)) AS fecha
        FROM GENERATE_SERIES(0, DATEDIFF(DAY, '20250101', '20271231'))
    ), F AS (
        SELECT fecha, (DATEDIFF(DAY, CONVERT(date, '19000101', 112), fecha) % 7) + 1 AS dsem FROM D  -- 1 = lunes
    )
    INSERT INTO dw.DimFecha
    SELECT YEAR(fecha)*10000 + MONTH(fecha)*100 + DAY(fecha), fecha, YEAR(fecha), DATEPART(QUARTER, fecha),
           MONTH(fecha),
           CHOOSE(MONTH(fecha), N'Enero',N'Febrero',N'Marzo',N'Abril',N'Mayo',N'Junio',N'Julio',N'Agosto',
                  N'Setiembre',N'Octubre',N'Noviembre',N'Diciembre'),
           CONVERT(CHAR(7), fecha, 120), DAY(fecha), dsem,
           CHOOSE(dsem, N'Lunes',N'Martes',N'Miércoles',N'Jueves',N'Viernes',N'Sábado',N'Domingo'),
           CASE WHEN dsem IN (6,7) THEN 1 ELSE 0 END
    FROM F;
END;

IF NOT EXISTS (SELECT 1 FROM dw.DimCanal)
    INSERT INTO dw.DimCanal (CanalKey, Canal, TipoCanal) VALUES
    (1, N'Tienda física', N'Presencial'), (2, N'WhatsApp', N'Digital'), (3, N'Instagram', N'Digital'),
    (4, N'Facebook', N'Digital'), (5, N'Web', N'Digital');

IF NOT EXISTS (SELECT 1 FROM dw.DimFalla)
    INSERT INTO dw.DimFalla (FallaKey, TipoFalla, Gravedad, Accion) VALUES
    (1, N'Ninguna', N'Sin falla', N'Ninguna'),
    (2, N'Mancha', N'Leve', N'Limpieza'),
    (3, N'Botón faltante', N'Leve', N'Reparación'),
    (4, N'Costura abierta', N'Moderada', N'Reparación'),
    (5, N'Cierre dañado', N'Moderada', N'Reparación'),
    (6, N'Rotura de tela', N'Grave', N'Reparación'),
    (7, N'Pérdida de accesorio', N'Grave', N'Reposición'),
    (8, N'Pérdida total', N'Grave', N'Reposición'),
    (9, N'Daño no especificado', N'Leve', N'Reparación');   -- penalidad 'Daño' del OLTP, sin detalle

IF NOT EXISTS (SELECT 1 FROM dw.DimTrabajador WHERE TrabajadorKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimTrabajador ON;
    INSERT INTO dw.DimTrabajador (TrabajadorKey, DNI, Trabajador, Cargo, Estado)
    VALUES (-1, '00000000', N'No registrado', N'No registrado', N'No registrado');
    SET IDENTITY_INSERT dw.DimTrabajador OFF;
END;
GO

CREATE OR ALTER PROCEDURE exp.usp_Cargar @FechaCorte DATE AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRANSACTION;
        DECLARE @acc TABLE (tabla NVARCHAR(40), accion NVARCHAR(10));

        /* ---------- DIMENSIONES ---------- */
        MERGE dw.DimTrabajador AS t
        USING (SELECT dni, CONCAT(nombres, N' ', apellidos) AS Trabajador, ISNULL(cargo, N'No registrado') AS Cargo,
                      ISNULL(estado, N'No registrado') AS Estado FROM stg.Trabajador) AS s
           ON t.DNI = s.dni
        WHEN MATCHED AND EXISTS (SELECT s.Trabajador, s.Cargo, s.Estado EXCEPT SELECT t.Trabajador, t.Cargo, t.Estado)
            THEN UPDATE SET Trabajador = s.Trabajador, Cargo = s.Cargo, Estado = s.Estado, FechaActualizacion = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (DNI, Trabajador, Cargo, Estado) VALUES (s.dni, s.Trabajador, s.Cargo, s.Estado)
        OUTPUT N'DimTrabajador', $action INTO @acc;

        MERGE dw.DimArticulo AS t
        USING stg.Articulo AS s
           ON t.Codigo = s.codigo
        WHEN MATCHED AND EXISTS (SELECT s.nombre, s.categoria, s.talla, s.color, s.costoCompra, s.precioAlquiler, s.precioVenta, s.fuente
                                 EXCEPT SELECT t.Articulo, t.Categoria, t.Talla, t.Color, t.CostoCompra, t.PrecioAlquiler, t.PrecioVenta, t.FuenteOrigen)
            THEN UPDATE SET Articulo = s.nombre, Categoria = s.categoria, Talla = s.talla, Color = s.color,
                            CostoCompra = s.costoCompra, PrecioAlquiler = s.precioAlquiler, PrecioVenta = s.precioVenta,
                            FuenteOrigen = s.fuente, FechaActualizacion = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (Codigo, Articulo, Categoria, Talla, Color, CostoCompra, PrecioAlquiler, PrecioVenta, FuenteOrigen)
                 VALUES (s.codigo, s.nombre, s.categoria, s.talla, s.color, s.costoCompra, s.precioAlquiler, s.precioVenta, s.fuente)
        OUTPUT N'DimArticulo', $action INTO @acc;

        MERGE dw.DimCliente AS t
        USING (SELECT dni, nombres, apellidos, CONCAT(nombres, N' ', apellidos) AS Cliente, telefono,
                      ISNULL(distrito, N'No registrado') AS Distrito, fechaRegistro, fuente FROM stg.Cliente) AS s
           ON t.DNI = s.dni
        WHEN MATCHED AND EXISTS (SELECT s.nombres, s.apellidos, s.telefono, s.Distrito, s.fechaRegistro, s.fuente
                                 EXCEPT SELECT t.Nombres, t.Apellidos, t.Telefono, t.Distrito, t.FechaRegistro, t.FuenteOrigen)
            THEN UPDATE SET Nombres = s.nombres, Apellidos = s.apellidos, Cliente = s.Cliente, Telefono = s.telefono,
                            Distrito = s.Distrito, FechaRegistro = s.fechaRegistro, FuenteOrigen = s.fuente,
                            FechaActualizacion = SYSDATETIME()
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (DNI, Nombres, Apellidos, Cliente, Telefono, Distrito, FechaRegistro, FuenteOrigen)
                 VALUES (s.dni, s.nombres, s.apellidos, s.Cliente, s.telefono, s.Distrito, s.fechaRegistro, s.fuente)
        OUTPUT N'DimCliente', $action INTO @acc;

        /* ---------- HECHOS ---------- */
        -- Control: ninguna fila de staging debe perderse al buscar sus claves
        IF (SELECT COUNT(*) FROM stg.Venta) <> (SELECT COUNT(*) FROM stg.Venta s
                JOIN dw.DimCliente c ON c.DNI = s.dniCliente JOIN dw.DimArticulo a ON a.Codigo = s.codigoArticulo
                JOIN dw.DimTrabajador t ON t.DNI = s.dniTrabajador JOIN dw.DimCanal k ON k.Canal = s.canal)
            THROW 52001, 'Hay ventas en staging sin clave en alguna dimensión.', 1;
        IF (SELECT COUNT(*) FROM stg.Alquiler) <> (SELECT COUNT(*) FROM stg.Alquiler s
                JOIN dw.DimCliente c ON c.DNI = s.dniCliente JOIN dw.DimArticulo a ON a.Codigo = s.codigoArticulo
                JOIN dw.DimTrabajador t ON t.DNI = s.dniTrabajador JOIN dw.DimCanal k ON k.Canal = s.canal)
            THROW 52002, 'Hay alquileres en staging sin clave en alguna dimensión.', 1;

        MERGE dw.FactVenta AS t
        USING (SELECT s.fuente, s.nroDocumento, CONVERT(INT, CONVERT(CHAR(8), s.fecha, 112)) AS FechaKey,
                      c.ClienteKey, a.ArticuloKey, tr.TrabajadorKey, k.CanalKey, s.comprobante, s.cantidad, s.precioUnitario,
                      CAST(s.cantidad * s.precioUnitario AS DECIMAL(12,2)) AS Importe,
                      CAST(s.cantidad * a.CostoCompra AS DECIMAL(12,2)) AS Costo
               FROM stg.Venta s
               JOIN dw.DimCliente c ON c.DNI = s.dniCliente
               JOIN dw.DimArticulo a ON a.Codigo = s.codigoArticulo
               JOIN dw.DimTrabajador tr ON tr.DNI = s.dniTrabajador
               JOIN dw.DimCanal k ON k.Canal = s.canal) AS s
           ON t.Fuente = s.fuente AND t.NroDocumento = s.nroDocumento AND t.ArticuloKey = s.ArticuloKey
        WHEN MATCHED AND EXISTS (SELECT s.FechaKey, s.ClienteKey, s.TrabajadorKey, s.CanalKey, s.comprobante, s.cantidad, s.precioUnitario, s.Costo
                                 EXCEPT SELECT t.FechaKey, t.ClienteKey, t.TrabajadorKey, t.CanalKey, t.Comprobante, t.Cantidad, t.PrecioUnitario, t.CostoVenta)
            THEN UPDATE SET FechaKey = s.FechaKey, ClienteKey = s.ClienteKey, TrabajadorKey = s.TrabajadorKey, CanalKey = s.CanalKey,
                            Comprobante = s.comprobante, Cantidad = s.cantidad, PrecioUnitario = s.precioUnitario,
                            ImporteVenta = s.Importe, CostoVenta = s.Costo, MargenBruto = s.Importe - s.Costo
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (Fuente, NroDocumento, FechaKey, ClienteKey, ArticuloKey, TrabajadorKey, CanalKey, Comprobante,
                         Cantidad, PrecioUnitario, ImporteVenta, CostoVenta, MargenBruto)
                 VALUES (s.fuente, s.nroDocumento, s.FechaKey, s.ClienteKey, s.ArticuloKey, s.TrabajadorKey, s.CanalKey, s.comprobante,
                         s.cantidad, s.precioUnitario, s.Importe, s.Costo, s.Importe - s.Costo)
        OUTPUT N'FactVenta', $action INTO @acc;

        MERGE dw.FactAlquiler AS t
        USING (SELECT s.fuente, s.nroAlquiler,
                      CONVERT(INT, CONVERT(CHAR(8), s.fechaAlquiler, 112)) AS FechaAlquilerKey,
                      CONVERT(INT, CONVERT(CHAR(8), s.fechaEntrega, 112)) AS FechaEntregaKey,
                      CONVERT(INT, CONVERT(CHAR(8), s.fechaProgramada, 112)) AS FechaProgramadaKey,
                      CONVERT(INT, CONVERT(CHAR(8), s.fechaReal, 112)) AS FechaDevolucionKey,
                      c.ClienteKey, a.ArticuloKey, tr.TrabajadorKey, k.CanalKey, s.tipoEvento,
                      CASE WHEN s.fechaReal IS NOT NULL THEN N'Devuelto'
                           WHEN s.fechaProgramada < @FechaCorte THEN N'Vencido'
                           ELSE N'En curso' END AS Estado,
                      s.cantidad, s.precioUnitario, CAST(s.cantidad * s.precioUnitario AS DECIMAL(12,2)) AS Importe,
                      CASE WHEN s.fechaReal IS NULL THEN NULL
                           WHEN s.fechaReal > s.fechaProgramada THEN DATEDIFF(DAY, s.fechaProgramada, s.fechaReal) ELSE 0 END AS DiasRetraso
               FROM stg.Alquiler s
               JOIN dw.DimCliente c ON c.DNI = s.dniCliente
               JOIN dw.DimArticulo a ON a.Codigo = s.codigoArticulo
               JOIN dw.DimTrabajador tr ON tr.DNI = s.dniTrabajador
               JOIN dw.DimCanal k ON k.Canal = s.canal) AS s
           ON t.Fuente = s.fuente AND t.NroAlquiler = s.nroAlquiler AND t.ArticuloKey = s.ArticuloKey
        WHEN MATCHED AND EXISTS (SELECT s.FechaAlquilerKey, s.FechaEntregaKey, s.FechaProgramadaKey, s.FechaDevolucionKey, s.ClienteKey,
                                        s.TrabajadorKey, s.CanalKey, s.tipoEvento, s.Estado, s.cantidad, s.precioUnitario, s.DiasRetraso
                                 EXCEPT SELECT t.FechaAlquilerKey, t.FechaEntregaKey, t.FechaProgramadaKey, t.FechaDevolucionKey, t.ClienteKey,
                                        t.TrabajadorKey, t.CanalKey, t.TipoEvento, t.EstadoAlquiler, t.Cantidad, t.PrecioUnitario, t.DiasRetraso)
            THEN UPDATE SET FechaAlquilerKey = s.FechaAlquilerKey, FechaEntregaKey = s.FechaEntregaKey,
                            FechaProgramadaKey = s.FechaProgramadaKey, FechaDevolucionKey = s.FechaDevolucionKey,
                            ClienteKey = s.ClienteKey, TrabajadorKey = s.TrabajadorKey, CanalKey = s.CanalKey,
                            TipoEvento = s.tipoEvento, EstadoAlquiler = s.Estado, Cantidad = s.cantidad,
                            PrecioUnitario = s.precioUnitario, ImporteAlquiler = s.Importe, DiasRetraso = s.DiasRetraso
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (Fuente, NroAlquiler, FechaAlquilerKey, FechaEntregaKey, FechaProgramadaKey, FechaDevolucionKey,
                         ClienteKey, ArticuloKey, TrabajadorKey, CanalKey, TipoEvento, EstadoAlquiler, Cantidad,
                         PrecioUnitario, ImporteAlquiler, DiasRetraso)
                 VALUES (s.fuente, s.nroAlquiler, s.FechaAlquilerKey, s.FechaEntregaKey, s.FechaProgramadaKey, s.FechaDevolucionKey,
                         s.ClienteKey, s.ArticuloKey, s.TrabajadorKey, s.CanalKey, s.tipoEvento, s.Estado, s.cantidad,
                         s.precioUnitario, s.Importe, s.DiasRetraso)
        OUTPUT N'FactAlquiler', $action INTO @acc;

        MERGE dw.FactDevolucion AS t
        USING (SELECT d.fuente, d.fuenteAlquiler, d.nroAlquiler,
                      CONVERT(INT, CONVERT(CHAR(8), d.fechaDevolucion, 112)) AS FechaDevolucionKey,
                      c.ClienteKey, ar.ArticuloKey, ISNULL(tr.TrabajadorKey, -1) AS InspectorKey, f.FallaKey,
                      CASE WHEN f.TipoFalla <> N'Ninguna' AND r.dias > 0 THEN N'Con retraso y falla'
                           WHEN f.TipoFalla <> N'Ninguna' THEN N'Con falla'
                           WHEN r.dias > 0 THEN N'Con retraso'
                           ELSE N'A tiempo' END AS TipoDevolucion,
                      r.dias AS DiasRetraso, d.montoCargo, d.observacion
               FROM stg.Devolucion d
               JOIN stg.Alquiler a ON a.fuente = d.fuenteAlquiler AND a.nroAlquiler = d.nroAlquiler AND a.codigoArticulo = d.codigoArticulo
               JOIN dw.DimCliente c ON c.DNI = a.dniCliente
               JOIN dw.DimArticulo ar ON ar.Codigo = d.codigoArticulo
               JOIN dw.DimFalla f ON f.TipoFalla = d.tipoFalla
               LEFT JOIN dw.DimTrabajador tr ON tr.DNI = d.dniInspector
               CROSS APPLY (SELECT CASE WHEN d.fechaDevolucion > a.fechaProgramada
                                        THEN DATEDIFF(DAY, a.fechaProgramada, d.fechaDevolucion) ELSE 0 END AS dias) r) AS s
           ON t.FuenteAlquiler = s.fuenteAlquiler AND t.NroAlquiler = s.nroAlquiler AND t.ArticuloKey = s.ArticuloKey
        WHEN MATCHED AND EXISTS (SELECT s.fuente, s.FechaDevolucionKey, s.ClienteKey, s.InspectorKey, s.FallaKey, s.TipoDevolucion, s.DiasRetraso, s.montoCargo, s.observacion
                                 EXCEPT SELECT t.Fuente, t.FechaDevolucionKey, t.ClienteKey, t.InspectorKey, t.FallaKey, t.TipoDevolucion, t.DiasRetraso, t.MontoCargo, t.Observacion)
            THEN UPDATE SET Fuente = s.fuente, FechaDevolucionKey = s.FechaDevolucionKey, ClienteKey = s.ClienteKey,
                            InspectorKey = s.InspectorKey, FallaKey = s.FallaKey, TipoDevolucion = s.TipoDevolucion,
                            DiasRetraso = s.DiasRetraso, MontoCargo = s.montoCargo, Observacion = s.observacion
        WHEN NOT MATCHED BY TARGET
            THEN INSERT (Fuente, FuenteAlquiler, NroAlquiler, FechaDevolucionKey, ClienteKey, ArticuloKey, InspectorKey,
                         FallaKey, TipoDevolucion, DiasRetraso, MontoCargo, Observacion)
                 VALUES (s.fuente, s.fuenteAlquiler, s.nroAlquiler, s.FechaDevolucionKey, s.ClienteKey, s.ArticuloKey, s.InspectorKey,
                         s.FallaKey, s.TipoDevolucion, s.DiasRetraso, s.montoCargo, s.observacion)
        OUTPUT N'FactDevolucion', $action INTO @acc;
    COMMIT TRANSACTION;
END;
GO

-- ===== Control del experimento =====
IF OBJECT_ID(N'exp.Resultado') IS NULL
CREATE TABLE exp.Resultado (
    id INT IDENTITY(1,1) PRIMARY KEY, volumen INT NOT NULL, repeticion INT NOT NULL,
    filas_ventas INT, filas_alquileres INT, filas_inspeccion INT, filas_leidas INT,
    limpias INT, rechazadas INT, duplicadas INT, hechos_cargados INT,
    ms_extraccion INT, ms_transformacion INT, ms_carga INT, ms_total INT,
    fecha DATETIME2(0) NOT NULL DEFAULT SYSDATETIME());
GO
-- Deja el DW del experimento vacío antes de cada corrida (no toca ModaEstilo_DW)
CREATE OR ALTER PROCEDURE exp.usp_Reiniciar AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dw.FactDevolucion; DELETE FROM dw.FactAlquiler; DELETE FROM dw.FactVenta;
    DELETE FROM dw.DimCliente; DELETE FROM dw.DimArticulo; DELETE FROM dw.DimTrabajador WHERE TrabajadorKey <> -1;
    DBCC CHECKIDENT ('dw.FactDevolucion', RESEED, 0) WITH NO_INFOMSGS; DBCC CHECKIDENT ('dw.FactAlquiler', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dw.FactVenta', RESEED, 0) WITH NO_INFOMSGS; DBCC CHECKIDENT ('dw.DimCliente', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dw.DimArticulo', RESEED, 0) WITH NO_INFOMSGS; DBCC CHECKIDENT ('dw.DimTrabajador', RESEED, 0) WITH NO_INFOMSGS;
END;
GO
-- Una corrida: reinicia, ejecuta E, T y L, y guarda tiempos y conteos
CREATE OR ALTER PROCEDURE exp.usp_Medir @Volumen INT, @Repeticion INT, @Archivo NVARCHAR(400) AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @corte DATE = '2026-11-20', @t0 DATETIME2(7), @t1 DATETIME2(7), @t2 DATETIME2(7), @t3 DATETIME2(7);
    EXEC exp.usp_Reiniciar;
    SET @t0 = SYSDATETIME(); EXEC exp.usp_Extraer @Archivo;
    SET @t1 = SYSDATETIME(); EXEC exp.usp_Transformar @corte;
    SET @t2 = SYSDATETIME(); EXEC exp.usp_Cargar @corte;
    SET @t3 = SYSDATETIME();
    DECLARE @v INT = (SELECT COUNT(*) FROM stg.raw_ventas), @a INT = (SELECT COUNT(*) FROM stg.raw_alquileres),
            @i INT = (SELECT COUNT(*) FROM stg.raw_inspeccion), @c INT = (SELECT COUNT(*) FROM stg.raw_catalogo);
    DECLARE @rech INT = (SELECT COUNT(*) FROM etl.Rechazo WHERE tipo = N'RECHAZO'),
            @dup INT = (SELECT COUNT(*) FROM etl.Rechazo WHERE tipo = N'DUPLICADO');
    INSERT INTO exp.Resultado (volumen, repeticion, filas_ventas, filas_alquileres, filas_inspeccion, filas_leidas,
                               limpias, rechazadas, duplicadas, hechos_cargados,
                               ms_extraccion, ms_transformacion, ms_carga, ms_total)
    VALUES (@Volumen, @Repeticion, @v, @a, @i, @v + @a + @i + @c, @v + @a + @i + @c - @rech - @dup, @rech, @dup,
            (SELECT COUNT(*) FROM dw.FactVenta) + (SELECT COUNT(*) FROM dw.FactAlquiler) + (SELECT COUNT(*) FROM dw.FactDevolucion),
            DATEDIFF(MILLISECOND, @t0, @t1), DATEDIFF(MILLISECOND, @t1, @t2), DATEDIFF(MILLISECOND, @t2, @t3),
            DATEDIFF(MILLISECOND, @t0, @t3));
END;
GO
PRINT N'Experimento preparado.';
