
CREATE DATABASE ModaEstilo_Final;
GO

USE ModaEstilo_Final;
GO

CREATE TABLE Categoria (
    idCategoria INT IDENTITY(1,1) PRIMARY KEY,
    nombreCategoria VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250)
);
GO

CREATE TABLE Trabajador (
    idTrabajador INT IDENTITY(1,1) PRIMARY KEY,
    dni VARCHAR(15) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    cargo VARCHAR(50),
    estado VARCHAR(20)
);
GO

CREATE TABLE Cliente (
    idCliente INT IDENTITY(1,1) PRIMARY KEY,
    dni VARCHAR(15) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(20),
    correo VARCHAR(100),
    direccion VARCHAR(200),
    fechaRegistro DATE
);
GO

CREATE TABLE Articulo (
    idArticulo INT IDENTITY(1,1) PRIMARY KEY,
    idCategoria INT NOT NULL,
    codigo VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    talla VARCHAR(20),
    color VARCHAR(50),
    costoCompra DECIMAL(10,2),
    precioAlquiler DECIMAL(10,2),
    precioVenta DECIMAL(10,2),
    stock INT,
    stockMinimo INT,
    estado VARCHAR(20),
    CONSTRAINT FK_Articulo_Categoria
        FOREIGN KEY (idCategoria) REFERENCES Categoria(idCategoria)
);
GO

CREATE TABLE Venta (
    idVenta INT IDENTITY(1,1) PRIMARY KEY,
    idCliente INT NOT NULL,
    idTrabajador INT NOT NULL,
    fechaVenta DATE NOT NULL,
    tipoComprobante VARCHAR(30),
    estado VARCHAR(20),
    total DECIMAL(10,2),
    CONSTRAINT FK_Venta_Cliente
        FOREIGN KEY (idCliente) REFERENCES Cliente(idCliente),
    CONSTRAINT FK_Venta_Trabajador
        FOREIGN KEY (idTrabajador) REFERENCES Trabajador(idTrabajador)
);
GO

CREATE TABLE Alquiler (
    idAlquiler INT IDENTITY(1,1) PRIMARY KEY,
    idCliente INT NOT NULL,
    idTrabajador INT NOT NULL,
    fechaAlquiler DATE NOT NULL,
    fechaEntrega DATE,
    fechaDevolucionProgramada DATE,
    fechaDevolucionReal DATE,
    estado VARCHAR(20),
    observacion VARCHAR(250),
    total DECIMAL(10,2),
    CONSTRAINT FK_Alquiler_Cliente
        FOREIGN KEY (idCliente) REFERENCES Cliente(idCliente),
    CONSTRAINT FK_Alquiler_Trabajador
        FOREIGN KEY (idTrabajador) REFERENCES Trabajador(idTrabajador)
);
GO

CREATE TABLE DetalleVenta (
    idDetalleVenta INT IDENTITY(1,1) PRIMARY KEY,
    idVenta INT NOT NULL,
    idArticulo INT NOT NULL,
    cantidad INT NOT NULL,
    precioUnitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_DetalleVenta_Venta
        FOREIGN KEY (idVenta) REFERENCES Venta(idVenta),
    CONSTRAINT FK_DetalleVenta_Articulo
        FOREIGN KEY (idArticulo) REFERENCES Articulo(idArticulo)
);
GO

CREATE TABLE DetalleAlquiler (
    idDetalleAlquiler INT IDENTITY(1,1) PRIMARY KEY,
    idAlquiler INT NOT NULL,
    idArticulo INT NOT NULL,
    cantidad INT NOT NULL,
    precioUnitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_DetalleAlquiler_Alquiler
        FOREIGN KEY (idAlquiler) REFERENCES Alquiler(idAlquiler),
    CONSTRAINT FK_DetalleAlquiler_Articulo
        FOREIGN KEY (idArticulo) REFERENCES Articulo(idArticulo)
);
GO

CREATE TABLE Devolucion (
    idDevolucion INT IDENTITY(1,1) PRIMARY KEY,
    idAlquiler INT NOT NULL,
    fechaDevolucion DATE,
    estadoArticulo VARCHAR(50),
    observaciones VARCHAR(250),
    CONSTRAINT FK_Devolucion_Alquiler
        FOREIGN KEY (idAlquiler) REFERENCES Alquiler(idAlquiler)
);
GO

CREATE TABLE Penalidad (
    idPenalidad INT IDENTITY(1,1) PRIMARY KEY,
    idDevolucion INT NOT NULL,
    tipoPenalidad VARCHAR(50),
    descripcion VARCHAR(250),
    diasRetraso INT,
    monto DECIMAL(10,2),
    fechaRegistro DATE,
    estadoPenalidad VARCHAR(20),
    CONSTRAINT FK_Penalidad_Devolucion
        FOREIGN KEY (idDevolucion) REFERENCES Devolucion(idDevolucion)
);
GO

CREATE TABLE Gasto (
    idGasto INT IDENTITY(1,1) PRIMARY KEY,
    fechaGasto DATE NOT NULL,
    tipoGasto VARCHAR(50),
    descripcion VARCHAR(250),
    monto DECIMAL(10,2) NOT NULL,
    idVenta INT NULL,
    idAlquiler INT NULL,
    CONSTRAINT FK_Gasto_Venta
        FOREIGN KEY (idVenta) REFERENCES Venta(idVenta),
    CONSTRAINT FK_Gasto_Alquiler
        FOREIGN KEY (idAlquiler) REFERENCES Alquiler(idAlquiler)
);
GO

CREATE TABLE Pago (
    idPago INT IDENTITY(1,1) PRIMARY KEY,
    tipoOperacion VARCHAR(20) NOT NULL,
    idVenta INT NULL,
    idAlquiler INT NULL,
    fechaPago DATE NOT NULL,
    metodoPago VARCHAR(30),
    monto DECIMAL(10,2) NOT NULL,
    estadoPago VARCHAR(20) NOT NULL,
    CONSTRAINT FK_Pago_Venta
        FOREIGN KEY (idVenta) REFERENCES Venta(idVenta),
    CONSTRAINT FK_Pago_Alquiler
        FOREIGN KEY (idAlquiler) REFERENCES Alquiler(idAlquiler)
);
GO

INSERT INTO Categoria (nombreCategoria, descripcion)
VALUES
('Ternos', 'Ternos para eventos y ocasiones especiales'),
('Vestidos', 'Vestidos para eventos'),
('Camisas', 'Camisas formales'),
('Accesorios', 'Accesorios para complementar la vestimenta');
GO

INSERT INTO Trabajador (dni, nombres, apellidos, cargo, estado)
VALUES
('70123456', 'Carlos', 'Ramirez Torres', 'Administrador', 'Activo'),
('70234567', 'Luis', 'Mendoza Perez', 'Vendedor', 'Activo'),
('70345678', 'Andrea', 'Flores Ruiz', 'Vendedor', 'Activo'),
('70456789', 'Miguel', 'Castillo Leon', 'Almacenero', 'Activo');
GO

INSERT INTO Cliente (dni, nombres, apellidos, telefono, correo, direccion, fechaRegistro)
VALUES
('75123456', 'Mateo', 'Guzman Ponce', '999888777', 'mateo@gmail.com', 'Av. Peru 123', '2026-01-10'),
('75234567', 'Sebastian', 'Flores Campos', '934567891', 'sebastian@gmail.com', 'Jr. Lima 456', '2026-01-15'),
('75345678', 'Marco Antonio', 'Salazar Leon', '923456789', 'marco@gmail.com', 'Av. Universitaria 789', '2026-02-01'),
('75456789', 'Juan', 'Perez Gomez', '987654321', 'juan@gmail.com', 'Av. Central 321', '2026-02-10'),
('75567890', 'Diego', 'Torres Silva', '986543210', 'diego@gmail.com', 'Jr. Los Olivos 111', '2026-02-15');
GO

INSERT INTO Articulo
(idCategoria, codigo, nombre, talla, color, costoCompra, precioAlquiler, precioVenta, stock, stockMinimo, estado)
VALUES
(1, 'TER001', 'Terno Clasico', 'M', 'Negro', 250.00, 150.00, 450.00, 10, 2, 'Disponible'),
(1, 'TER002', 'Terno Ejecutivo', 'L', 'Azul', 280.00, 170.00, 500.00, 8, 2, 'Disponible'),
(2, 'VES001', 'Vestido Elegante', 'M', 'Rojo', 180.00, 120.00, 350.00, 6, 2, 'Disponible'),
(3, 'CAM001', 'Camisa Formal', 'M', 'Blanco', 50.00, 30.00, 90.00, 20, 5, 'Disponible'),
(4, 'ACC001', 'Corbata Clasica', 'Unica', 'Negro', 20.00, 10.00, 40.00, 30, 5, 'Disponible');
GO

INSERT INTO Venta
(idCliente, idTrabajador, fechaVenta, tipoComprobante, estado, total)
VALUES
(1, 2, '2026-07-07', 'Boleta', 'Pagado', 450.00),
(2, 3, '2026-07-07', 'Boleta', 'Pagado', 300.00),
(3, 2, '2026-07-07', 'Factura', 'Pagado', 583.00),
(4, 3, '2026-07-06', 'Boleta', 'Pagado', 250.00);
GO

INSERT INTO Alquiler
(idCliente, idTrabajador, fechaAlquiler, fechaEntrega, fechaDevolucionProgramada, fechaDevolucionReal, estado, observacion, total)
VALUES
(1, 2, '2026-07-01', '2026-07-02', '2026-07-05', '2026-07-05', 'Devuelto', 'Alquiler completado', 200.00),
(2, 3, '2026-07-02', '2026-07-03', '2026-07-06', NULL, 'Pendiente', 'Pendiente de devolución', 188.00),
(3, 2, '2026-07-03', '2026-07-04', '2026-07-07', NULL, 'Pendiente', 'Pendiente de devolución', 225.00),
(4, 3, '2026-07-04', '2026-07-05', '2026-07-08', '2026-07-08', 'Devuelto', 'Sin observaciones', 150.00),
(5, 2, '2026-07-05', '2026-07-06', '2026-07-09', '2026-07-09', 'Devuelto', 'Alquiler completado', 175.00),
(1, 3, '2026-07-06', '2026-07-07', '2026-07-10', '2026-07-10', 'Devuelto', 'Sin observaciones', 210.00),
(3, 2, '2026-07-07', '2026-07-08', '2026-07-11', NULL, 'Pendiente', 'Pendiente de devolución', 225.00),
(2, 3, '2026-07-08', '2026-07-09', '2026-07-12', NULL, 'Pendiente', 'Pendiente de devolución', 188.00),
(4, 2, '2026-07-09', '2026-07-10', '2026-07-13', '2026-07-13', 'Devuelto', 'Sin observaciones', 160.00),
(5, 3, '2026-07-10', '2026-07-11', '2026-07-14', '2026-07-14', 'Devuelto', 'Sin observaciones', 190.00),
(1, 2, '2026-07-11', '2026-07-12', '2026-07-15', NULL, 'Pendiente', 'Pendiente de pago', 310.00);
GO

INSERT INTO DetalleVenta
(idVenta, idArticulo, cantidad, precioUnitario, subtotal)
VALUES
(1, 1, 1, 450.00, 450.00),
(2, 2, 1, 300.00, 300.00),
(3, 3, 1, 350.00, 350.00),
(3, 4, 2, 90.00, 180.00),
(3, 5, 1, 53.00, 53.00),
(4, 2, 1, 250.00, 250.00);
GO

INSERT INTO DetalleAlquiler
(idAlquiler, idArticulo, cantidad, precioUnitario, subtotal)
VALUES
(1, 1, 1, 200.00, 200.00),
(2, 2, 1, 188.00, 188.00),
(3, 3, 1, 225.00, 225.00),
(4, 1, 1, 150.00, 150.00),
(5, 2, 1, 175.00, 175.00),
(6, 1, 1, 210.00, 210.00),
(7, 3, 1, 225.00, 225.00),
(8, 2, 1, 188.00, 188.00),
(9, 1, 1, 160.00, 160.00),
(10, 2, 1, 190.00, 190.00),
(11, 1, 1, 310.00, 310.00);
GO

INSERT INTO Devolucion
(idAlquiler, fechaDevolucion, estadoArticulo, observaciones)
VALUES
(1, '2026-07-05', 'Bueno', 'Sin daños'),
(4, '2026-07-08', 'Bueno', 'Sin daños'),
(5, '2026-07-09', 'Bueno', 'Sin daños'),
(6, '2026-07-10', 'Bueno', 'Sin daños'),
(9, '2026-07-13', 'Bueno', 'Sin daños'),
(10, '2026-07-14', 'Bueno', 'Sin daños');
GO

INSERT INTO Penalidad
(idDevolucion, tipoPenalidad, descripcion, diasRetraso, monto, fechaRegistro, estadoPenalidad)
VALUES
(1, 'Ninguna', 'Sin penalidad', 0, 0.00, '2026-07-05', 'Aplicada'),
(2, 'Retraso', 'Entrega fuera de fecha', 1, 50.00, '2026-07-08', 'Pendiente'),
(3, 'Ninguna', 'Sin penalidad', 0, 0.00, '2026-07-09', 'Aplicada'),
(4, 'Daño', 'Daño menor en prenda', 0, 75.00, '2026-07-10', 'Pendiente'),
(5, 'Ninguna', 'Sin penalidad', 0, 0.00, '2026-07-13', 'Aplicada'),
(6, 'Retraso', 'Entrega fuera de fecha', 1, 40.00, '2026-07-14', 'Pendiente');
GO

INSERT INTO Gasto
(fechaGasto, tipoGasto, descripcion, monto, idVenta, idAlquiler)
VALUES
('2026-07-07', 'Operativo', 'Compra de materiales', 100.00, NULL, NULL),
('2026-07-07', 'Transporte', 'Traslado de prendas', 75.00, NULL, NULL),
('2026-07-07', 'Mantenimiento', 'Mantenimiento de equipos', 75.00, NULL, NULL),
('2026-07-06', 'Operativo', 'Materiales de oficina', 50.00, NULL, NULL),
('2026-07-05', 'Transporte', 'Servicio de movilidad', 40.00, NULL, NULL);
GO

INSERT INTO Pago
(tipoOperacion, idVenta, idAlquiler, fechaPago, metodoPago, monto, estadoPago)
VALUES
('VENTA', 1, NULL, '2026-07-07', 'Efectivo', 450.00, 'Pagado'),
('VENTA', 2, NULL, '2026-07-07', 'Yape', 300.00, 'Pagado'),
('VENTA', 3, NULL, '2026-07-07', 'Tarjeta', 583.00, 'Pagado'),
('VENTA', 4, NULL, '2026-07-06', 'Efectivo', 250.00, 'Pagado'),
('ALQUILER', NULL, 11, '2026-07-07', 'Efectivo', 150.00, 'Pagado'),
('ALQUILER', NULL, 8, '2026-07-07', 'Yape', 50.00, 'Parcial'),
('ALQUILER', NULL, 7, '2026-07-07', 'Efectivo', 100.00, 'Parcial'),
('ALQUILER', NULL, 1, '2026-07-05', 'Efectivo', 200.00, 'Pagado'),
('ALQUILER', NULL, 4, '2026-07-08', 'Yape', 150.00, 'Pagado'),
('ALQUILER', NULL, 5, '2026-07-09', 'Efectivo', 175.00, 'Pagado'),
('ALQUILER', NULL, 6, '2026-07-10', 'Tarjeta', 210.00, 'Pagado'),
('ALQUILER', NULL, 9, '2026-07-13', 'Efectivo', 160.00, 'Pagado'),
('ALQUILER', NULL, 10, '2026-07-14', 'Yape', 190.00, 'Pagado'),
('VENTA', 1, NULL, '2026-07-07', 'Efectivo', 300.00, 'Devoluto');
GO
