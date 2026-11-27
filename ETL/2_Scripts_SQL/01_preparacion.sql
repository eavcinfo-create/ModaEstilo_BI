
USE master;
GO

SELECT @@VERSION AS Version;
SELECT SERVERPROPERTY('ProductVersion') AS ProductVersion, SERVERPROPERTY('ProductLevel') AS ProductLevel,
       SERVERPROPERTY('Edition') AS Edition, SERVERPROPERTY('Collation') AS Collation;
GO
-- Habilitar OPENROWSET y el proveedor de Excel
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'AllowInProcess', 1;
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0', N'DynamicParameters', 1;
GO
-- Prueba: leer las primeras filas de la hoja Ventas
SELECT TOP (5) *
FROM OPENROWSET('Microsoft.ACE.OLEDB.16.0',
     'Excel 12.0 Xml;HDR=YES;IMEX=1;Database=C:\Users\Gian Franco David\Documents\Proceso ETL\1_Fuentes_Excel\Fuentes_ModaEstilo.xlsx',
     'SELECT * FROM [Ventas$]');
