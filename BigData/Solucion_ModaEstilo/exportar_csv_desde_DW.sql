-- Consultas con las que se generaron los CSV de la carpeta datos, a partir de ModaEstilo_DW.
-- No traen DNI, nombres ni teléfonos.
-- Los CSV ya están en la carpeta datos: solo hace falta ejecutar esto si se quieren volver a generar.
USE ModaEstilo_DW;
GO

-- 1. modaestilo_hechos.csv (250 filas: 125 de venta y 125 de alquiler)
SELECT 'VENTA' AS tipo_operacion,
       DENSE_RANK() OVER (ORDER BY f.Fuente, f.NroDocumento) AS id_operacion,
       f.VentaKey AS id_detalle, f.NroDocumento AS nro_documento, f.Fuente AS fuente,
       CONVERT(CHAR(10), d.Fecha, 23) AS fecha, f.ClienteKey AS id_cliente, c.Distrito AS distrito,
       f.TrabajadorKey AS id_trabajador, t.Cargo AS cargo, f.ArticuloKey AS id_articulo, a.Articulo AS articulo,
       a.Categoria AS categoria, k.Canal AS canal, f.Cantidad AS cantidad, f.PrecioUnitario AS precio_unitario,
       f.ImporteVenta AS importe, N'Vendido' AS estado
FROM dw.FactVenta f
JOIN dw.DimFecha d ON d.FechaKey = f.FechaKey
JOIN dw.DimCliente c ON c.ClienteKey = f.ClienteKey
JOIN dw.DimTrabajador t ON t.TrabajadorKey = f.TrabajadorKey
JOIN dw.DimArticulo a ON a.ArticuloKey = f.ArticuloKey
JOIN dw.DimCanal k ON k.CanalKey = f.CanalKey
UNION ALL
SELECT 'ALQUILER', 100000 + DENSE_RANK() OVER (ORDER BY f.Fuente, f.NroAlquiler),
       100000 + f.AlquilerKey, f.NroAlquiler, f.Fuente,
       CONVERT(CHAR(10), d.Fecha, 23), f.ClienteKey, c.Distrito, f.TrabajadorKey, t.Cargo, f.ArticuloKey, a.Articulo,
       a.Categoria, k.Canal, f.Cantidad, f.PrecioUnitario, f.ImporteAlquiler, f.EstadoAlquiler
FROM dw.FactAlquiler f
JOIN dw.DimFecha d ON d.FechaKey = f.FechaAlquilerKey
JOIN dw.DimCliente c ON c.ClienteKey = f.ClienteKey
JOIN dw.DimTrabajador t ON t.TrabajadorKey = f.TrabajadorKey
JOIN dw.DimArticulo a ON a.ArticuloKey = f.ArticuloKey
JOIN dw.DimCanal k ON k.CanalKey = f.CanalKey
ORDER BY tipo_operacion DESC, id_detalle;

-- 2. modaestilo_devoluciones.csv (107 filas)
SELECT f.DevolucionKey AS id_devolucion, f.FuenteAlquiler + '-' + f.NroAlquiler AS alquiler,
       CONVERT(CHAR(10), d.Fecha, 23) AS fecha_devolucion, a.Articulo AS articulo, a.Categoria AS categoria,
       x.TipoFalla AS tipo_falla, x.Gravedad AS gravedad, x.Accion AS accion, f.TipoDevolucion AS tipo_devolucion,
       f.DiasRetraso AS dias_retraso, f.MontoCargo AS monto_cargo
FROM dw.FactDevolucion f
JOIN dw.DimFecha d ON d.FechaKey = f.FechaDevolucionKey
JOIN dw.DimArticulo a ON a.ArticuloKey = f.ArticuloKey
JOIN dw.DimFalla x ON x.FallaKey = f.FallaKey
ORDER BY f.DevolucionKey;
