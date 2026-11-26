USE ModaEstilo_DW;
SELECT
  (SELECT SUM(ImporteVenta) FROM dw.FactVenta)       AS IngresoVentas,
  (SELECT SUM(ImporteAlquiler) FROM dw.FactAlquiler) AS IngresoAlquileres,
  (SELECT COUNT(DISTINCT CONCAT(Fuente,'-',NroDocumento)) FROM dw.FactVenta)   AS NVentas,
  (SELECT COUNT(DISTINCT CONCAT(Fuente,'-',NroAlquiler)) FROM dw.FactAlquiler) AS NAlquileres,
  (SELECT SUM(Cantidad) FROM dw.FactVenta)           AS Unidades,
  (SELECT SUM(MargenBruto) FROM dw.FactVenta)        AS MargenBruto,
  (SELECT COUNT(DISTINCT CONCAT(Fuente,'-',NroAlquiler)) FROM dw.FactAlquiler WHERE EstadoAlquiler = 'Devuelto') AS Devueltos,
  (SELECT COUNT(DISTINCT CONCAT(Fuente,'-',NroAlquiler)) FROM dw.FactAlquiler WHERE EstadoAlquiler = 'Vencido')  AS Vencidos,
  (SELECT COUNT(DISTINCT CONCAT(Fuente,'-',NroAlquiler)) FROM dw.FactAlquiler WHERE DiasRetraso > 0)             AS ConRetraso,
  (SELECT SUM(MontoCargo) FROM dw.FactDevolucion)    AS Penalidades;