/* =====================================================================
   03 - TRANSFORMACION
   Limpia los datos extraídos (espacios, fechas, decimales, DNI, valores
   escritos de distintas formas), quita duplicados y separa las filas con
   error en etl.Rechazo. Los datos limpios quedan en las tablas stg.*
   de ModaEstilo_Staging.
   ===================================================================== */
USE ModaEstilo_Staging;
GO
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

SET NOCOUNT ON;
DECLARE @FechaCorte DATE = '2026-11-20';   -- fechas posteriores se rechazan como futuras
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

/* ---------- Resultado ---------- */
SELECT hoja AS Hoja, COUNT(*) AS Leidas,
       SUM(CASE WHEN motivo IS NULL THEN 1 ELSE 0 END) AS Limpias,
       SUM(CASE WHEN tipo = N'RECHAZO' AND motivo IS NOT NULL THEN 1 ELSE 0 END) AS Rechazadas,
       SUM(CASE WHEN tipo = N'DUPLICADO' AND motivo IS NOT NULL THEN 1 ELSE 0 END) AS Duplicadas
FROM (SELECT N'Catalogo' AS hoja, motivo, tipo FROM #cat UNION ALL SELECT N'Ventas', motivo, tipo FROM #ven
      UNION ALL SELECT N'Alquileres', motivo, tipo FROM #alq UNION ALL SELECT N'Inspeccion', motivo, tipo FROM #ins) u
GROUP BY hoja;

SELECT hoja, fila AS FilaExcel, clave, tipo, motivo FROM etl.Rechazo ORDER BY hoja, fila;

SELECT N'Articulos' AS Tabla, COUNT(*) AS Filas FROM stg.Articulo
UNION ALL SELECT N'Clientes', COUNT(*) FROM stg.Cliente
UNION ALL SELECT N'Trabajadores', COUNT(*) FROM stg.Trabajador
UNION ALL SELECT N'Ventas', COUNT(*) FROM stg.Venta
UNION ALL SELECT N'Alquileres', COUNT(*) FROM stg.Alquiler
UNION ALL SELECT N'Devoluciones', COUNT(*) FROM stg.Devolucion;
