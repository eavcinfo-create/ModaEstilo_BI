/* =====================================================================
   04 - CARGA
   Carga los datos limpios de ModaEstilo_Staging en la base OLAP
   ModaEstilo_DW (modelo estrella). Inserta lo nuevo y actualiza solo lo que
   cambió, así que ejecutarlo otra vez no duplica datos.
   ===================================================================== */
IF DB_ID(N'ModaEstilo_DW') IS NULL
    CREATE DATABASE ModaEstilo_DW COLLATE Modern_Spanish_CI_AS;
GO
USE ModaEstilo_DW;
GO
IF SCHEMA_ID(N'dw') IS NULL EXEC(N'CREATE SCHEMA dw');
GO
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

SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @FechaCorte DATE = '2026-11-20';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @acc TABLE (tabla NVARCHAR(40), accion NVARCHAR(10));

    /* ---------- DIMENSIONES ---------- */
    MERGE dw.DimTrabajador AS t
    USING (SELECT dni, CONCAT(nombres, N' ', apellidos) AS Trabajador, ISNULL(cargo, N'No registrado') AS Cargo,
                  ISNULL(estado, N'No registrado') AS Estado FROM ModaEstilo_Staging.stg.Trabajador) AS s
       ON t.DNI = s.dni
    WHEN MATCHED AND EXISTS (SELECT s.Trabajador, s.Cargo, s.Estado EXCEPT SELECT t.Trabajador, t.Cargo, t.Estado)
        THEN UPDATE SET Trabajador = s.Trabajador, Cargo = s.Cargo, Estado = s.Estado, FechaActualizacion = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (DNI, Trabajador, Cargo, Estado) VALUES (s.dni, s.Trabajador, s.Cargo, s.Estado)
    OUTPUT N'DimTrabajador', $action INTO @acc;

    MERGE dw.DimArticulo AS t
    USING ModaEstilo_Staging.stg.Articulo AS s
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
                  ISNULL(distrito, N'No registrado') AS Distrito, fechaRegistro, fuente FROM ModaEstilo_Staging.stg.Cliente) AS s
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
    IF (SELECT COUNT(*) FROM ModaEstilo_Staging.stg.Venta) <> (SELECT COUNT(*) FROM ModaEstilo_Staging.stg.Venta s
            JOIN dw.DimCliente c ON c.DNI = s.dniCliente JOIN dw.DimArticulo a ON a.Codigo = s.codigoArticulo
            JOIN dw.DimTrabajador t ON t.DNI = s.dniTrabajador JOIN dw.DimCanal k ON k.Canal = s.canal)
        THROW 52001, 'Hay ventas en staging sin clave en alguna dimensión.', 1;
    IF (SELECT COUNT(*) FROM ModaEstilo_Staging.stg.Alquiler) <> (SELECT COUNT(*) FROM ModaEstilo_Staging.stg.Alquiler s
            JOIN dw.DimCliente c ON c.DNI = s.dniCliente JOIN dw.DimArticulo a ON a.Codigo = s.codigoArticulo
            JOIN dw.DimTrabajador t ON t.DNI = s.dniTrabajador JOIN dw.DimCanal k ON k.Canal = s.canal)
        THROW 52002, 'Hay alquileres en staging sin clave en alguna dimensión.', 1;

    MERGE dw.FactVenta AS t
    USING (SELECT s.fuente, s.nroDocumento, CONVERT(INT, CONVERT(CHAR(8), s.fecha, 112)) AS FechaKey,
                  c.ClienteKey, a.ArticuloKey, tr.TrabajadorKey, k.CanalKey, s.comprobante, s.cantidad, s.precioUnitario,
                  CAST(s.cantidad * s.precioUnitario AS DECIMAL(12,2)) AS Importe,
                  CAST(s.cantidad * a.CostoCompra AS DECIMAL(12,2)) AS Costo
           FROM ModaEstilo_Staging.stg.Venta s
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
           FROM ModaEstilo_Staging.stg.Alquiler s
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
           FROM ModaEstilo_Staging.stg.Devolucion d
           JOIN ModaEstilo_Staging.stg.Alquiler a ON a.fuente = d.fuenteAlquiler AND a.nroAlquiler = d.nroAlquiler AND a.codigoArticulo = d.codigoArticulo
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

    /* ---------- Resultado ---------- */
    SELECT o.tabla AS Tabla,
           (SELECT COUNT(*) FROM @acc a WHERE a.tabla = o.tabla AND a.accion = N'INSERT') AS Insertados,
           (SELECT COUNT(*) FROM @acc a WHERE a.tabla = o.tabla AND a.accion = N'UPDATE') AS Actualizados
    FROM (VALUES (1, N'DimTrabajador'), (2, N'DimArticulo'), (3, N'DimCliente'),
                 (4, N'FactVenta'), (5, N'FactAlquiler'), (6, N'FactDevolucion')) o(n, tabla)
    ORDER BY o.n;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;   -- si algo falla no se carga nada
    THROW;
END CATCH;
GO

SELECT N'dw.FactVenta' AS Tabla, COUNT(*) AS Filas FROM dw.FactVenta
UNION ALL SELECT N'dw.FactAlquiler', COUNT(*) FROM dw.FactAlquiler
UNION ALL SELECT N'dw.FactDevolucion', COUNT(*) FROM dw.FactDevolucion
UNION ALL SELECT N'dw.DimCliente', COUNT(*) FROM dw.DimCliente
UNION ALL SELECT N'dw.DimArticulo', COUNT(*) FROM dw.DimArticulo
UNION ALL SELECT N'dw.DimTrabajador', COUNT(*) FROM dw.DimTrabajador
UNION ALL SELECT N'dw.DimFecha', COUNT(*) FROM dw.DimFecha
UNION ALL SELECT N'dw.DimCanal', COUNT(*) FROM dw.DimCanal
UNION ALL SELECT N'dw.DimFalla', COUNT(*) FROM dw.DimFalla;

-- Comprobación: lo que vino de la base OLTP tiene los mismos importes en el OLAP
SELECT N'Ventas' AS Dato,
       (SELECT SUM(subtotal) FROM ModaEstilo_Final.dbo.DetalleVenta) AS ImporteOLTP,
       (SELECT SUM(ImporteVenta) FROM dw.FactVenta WHERE Fuente = 'OLTP') AS ImporteOLAP
UNION ALL SELECT N'Alquileres', (SELECT SUM(subtotal) FROM ModaEstilo_Final.dbo.DetalleAlquiler),
       (SELECT SUM(ImporteAlquiler) FROM dw.FactAlquiler WHERE Fuente = 'OLTP');
