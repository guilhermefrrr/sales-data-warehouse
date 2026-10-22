/*
PROJECT: Sales Data Warehouse Project
LAYER: Bronze
PURPOSE:
    Load source sales CSV files into the raw Bronze table and maintain a file-level load log.

PROCESS OVERVIEW:
    1. Skip a file when its path is already present in bronze.controle_carga.
    2. Read the CSV header to detect whether Es_pre_compra is present.
    3. Load the file into the matching staging layout.
    4. Map the staging columns into bronze.vendas and retain the source path.
    5. Record the loaded row count and file path for traceability.

OPERATIONAL NOTES:
    - The sales CSV is expected to be pipe-delimited, UTF-8, with a header row.
    - The event loader expects a comma-delimited CSV.
    - File paths are currently local-machine paths and must be adjusted for another environment.
    - The staging table is truncated before each file load; Bronze retains previously loaded files.
    - The event loader performs a full reload of bronze.eventos.

IMPORTANT:
    The code below is commented for documentation; its SQL logic is preserved.
*/

-- STORED PROCEDURES BRONZE

-- Loads one sales file into Bronze. The input parameter is the full path accessible to SQL Server.
CREATE OR ALTER PROCEDURE bronze.load_bronze @file_path VARCHAR(500) AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME, @rows_loaded INT, @staging_table VARCHAR(50), @header VARCHAR(MAX), @sql_header NVARCHAR(MAX)
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '====================='
        PRINT 'Loading bronze layer';
        PRINT '====================='
        
        -- Prevents loading the same source path more than once according to the load log.
        IF EXISTS (SELECT 1 FROM bronze.controle_carga WHERE arquivo = @file_path)
        BEGIN
            PRINT 'File already loaded previously: ' + @file_path;
            RETURN;
        END;

        -- OPENROWSET reads the first line so the procedure can detect the source layout.
        SET @sql_header = '
            SELECT 
                @header = LEFT(BulkColumn, CHARINDEX(CHAR(10), BulkColumn) - 1)
            FROM OPENROWSET(
                BULK ''' + @file_path + ''',
                SINGLE_CLOB
            ) AS datafile;
        ';
        EXEC sp_executesql @sql_header, N'@header VARCHAR(MAX) OUTPUT', @header OUTPUT;

        -- Choose the staging schema based on whether the optional column appears in the header.
        SET @staging_table =
            CASE 
                WHEN CHARINDEX('Es pre compra', @header) > 0 
                THEN 'bronze.stg_vendas2'
                ELSE 'bronze.stg_vendas1'
            END;
        PRINT '>>> Staging table selected: ' + @staging_table;

        SET @start_time = GETDATE();
        -- Staging is reused for each file, so clear it before importing the next file.
        PRINT '>>> Truncating staging table';
        EXEC('Truncate table ' + @staging_table);
        PRINT '>>> Inserting data into ' + @staging_table;
        DECLARE @load_vendas NVARCHAR(MAX) = '
            BULK INSERT ' + @staging_table + '
            FROM ''' + @file_path + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = ''|'',
                ROWTERMINATOR = ''0x0a'',
                CODEPAGE = ''65001''
            )';
        EXEC sp_executesql @load_vendas;


        -- Map each staging layout explicitly into the shared Bronze table.
        -- The optional column is populated only when it exists in the source layout.
        PRINT '>>> Moving data from staging to bronze.vendas';
        IF @staging_table = 'bronze.stg_vendas1'
        BEGIN
            INSERT INTO bronze.vendas (
                Numero_de_orden,
                Palco,
                Nombre_del_comercio,
                Evento,
                Fecha,
                Total,
                Producto,
                Categoria,
                Talle,
                Cantidad,
                Precio_Unitario,
                Total_Producto,
                Correo_del_Comprador,
                Telefono_del_Comprador,
                N_de_identificacion_del_Comprador,
                Cantidad_restante_de_beneficio,
                Metodo_de_pago,
                Ultimos_digitos_de_la_tarjeta,
                Dispositivo_Clover,
                Delivery,
                Estado_de_facturacion,
                Estado,
                arquivo_fonte
            )
            SELECT
                Numero_de_orden,
                Palco,
                Nombre_del_comercio,
                Evento,
                Fecha,
                Total,
                Producto,
                Categoria,
                Talle,
                Cantidad,
                Precio_Unitario,
                Total_Producto,
                Correo_del_Comprador,
                Telefono_del_Comprador,
                N_de_identificacion_del_Comprador,
                Cantidad_restante_de_beneficio,
                Metodo_de_pago,
                Ultimos_digitos_de_la_tarjeta,
                Dispositivo_Clover,
                Delivery,
                Estado_de_facturacion,
                Estado,
                @file_path
            FROM bronze.stg_vendas1;
        END
        ELSE IF @staging_table = 'bronze.stg_vendas2'
        BEGIN
            INSERT INTO bronze.vendas (
                Numero_de_orden,
                Palco,
                Nombre_del_comercio,
                Evento,
                Fecha,
                Total,
                Producto,
                Categoria,
                Talle,
                Cantidad,
                Precio_Unitario,
                Total_Producto,
                Correo_del_Comprador,
                Telefono_del_Comprador,
                N_de_identificacion_del_Comprador,
                Cantidad_restante_de_beneficio,
                Metodo_de_pago,
                Ultimos_digitos_de_la_tarjeta,
                Dispositivo_Clover,
                Delivery,
                Estado_de_facturacion,
                Es_pre_compra,
                Estado,
                arquivo_fonte
            )
            SELECT
                Numero_de_orden,
                Palco,
                Nombre_del_comercio,
                Evento,
                Fecha,
                Total,
                Producto,
                Categoria,
                Talle,
                Cantidad,
                Precio_Unitario,
                Total_Producto,
                Correo_del_Comprador,
                Telefono_del_Comprador,
                N_de_identificacion_del_Comprador,
                Cantidad_restante_de_beneficio,
                Metodo_de_pago,
                Ultimos_digitos_de_la_tarjeta,
                Dispositivo_Clover,
                Delivery,
                Estado_de_facturacion,
                Es_pre_compra,
                Estado,
                @file_path
            FROM bronze.stg_vendas2;
        END

        -- Capture the number of rows inserted into bronze.vendas for this source file.
        SET @rows_loaded = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST (DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'

        -- Register the source path and inserted row count so subsequent runs can skip this file.
        SET @start_time = GETDATE();
        PRINT '>>> Inserting data into bronze.controle_carga';
        INSERT INTO bronze.controle_carga (
            arquivo,
            linhas_carregadas
        )
        VALUES (
            @file_path,
            @rows_loaded
        );
        PRINT 'File updated successfully: ' + @file_path;
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST (DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        SET @batch_end_time = GETDATE();
        PRINT '====================================='
        PRINT '>>> Bronze layer loading is complete';
        PRINT '====================================='
        PRINT '>>> Total load duration: ' + CAST (DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';

    END TRY
    BEGIN CATCH
    PRINT 'An error occurred while loading the bronze layer'
    PRINT 'Error message: ' + ERROR_MESSAGE();
    PRINT 'Error message: ' + CAST (ERROR_NUMBER() AS NVARCHAR); 
    PRINT 'Error message: ' + CAST (ERROR_STATE() AS NVARCHAR);
    THROW
    END CATCH
END;
GO

-- Fully reloads the event reference data from the configured CSV file.
CREATE OR ALTER PROCEDURE bronze.load_eventos AS
BEGIN
    BEGIN TRY
        PRINT '>>> Truncating bronze.eventos';
        TRUNCATE TABLE bronze.eventos;
        PRINT '>>> Loading bronze.eventos';

        BULK INSERT bronze.eventos
        FROM 'C:\Temp\gb\eventos.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            CODEPAGE = '65001'
        );

        PRINT '>>> Events loaded successfully';
    END TRY
    BEGIN CATCH
        PRINT 'Error loading events: ' + ERROR_MESSAGE();
    THROW;
    END CATCH
END;


-- Example execution batch for the source files used in this project.
-- Update these local paths to match the environment before running.
-- EXECUTING THE STORED PROCEDURES

EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260111.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260117.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260120.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260201.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260205.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260214.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260225.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260228.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260307.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260311.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260318.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260401.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260405.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260422.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260425.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260509.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260517.csv';
EXEC bronze.load_bronze 'C:\Temp\gb\reporte_limpo_20260530.csv';

EXEC bronze.load_eventos;

SELECT * FROM bronze.vendas