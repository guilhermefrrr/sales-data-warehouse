/*
PROJECT: Sales Data Warehouse Project
LAYER: Silver
PURPOSE:
    Convert raw Bronze sales values into typed, standardized records and refresh supporting tables.

TRANSFORMATIONS:
    - Convert order numbers, dates, times, quantities, prices, and totals to their target types.
    - Standardize selected business and product labels.
    - Trim text fields and normalize selected payment and customer-identification values.
    - Split device information into a Clover identifier and a serial code according to source format.
    - Derive data_evento from the date embedded in arquivo_fonte.
    - Insert sales only when their source filename has not already been loaded into Silver.
    - Refresh the load-control table and event table from Bronze.

DESIGN NOTE:
    The incremental rule is file-based: a source filename already represented in Silver is skipped.
    Reprocessing a corrected file with the same filename will not update its existing Silver rows automatically.
*/

-- STORED PROCEDURE SILVER

-- Standardizes Bronze sales data and refreshes Silver support tables.
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '====================='
        PRINT 'Loading silver layer';
        PRINT '====================='

        SET @start_time = GETDATE();
        -- Insert only source files not already represented in Silver.
        -- This is file-level incremental loading, not row-by-row change detection.
        PRINT '>>> Inserting new data into silver.vendas';
        INSERT INTO silver.vendas (
            numero_pedido,
            nome_comercio,
            data,
            hora,
            total,
            produto,
            categoria,
            quantidade,
            preco_unitario,
            total_produto,
            identificacao_comprador,
            metodo_pagamento,
            ultimos_digitos_cartao,
            dispositivo_clover,
            codigo_serie,
            estado,
            Es_pre_compra,
            data_evento,
            arquivo_fonte,
            data_ingestao
        )
        SELECT
            CAST(Numero_de_orden AS INT),
            --Palco,
            -- Map source business labels to consistent reporting names.
            CASE Nombre_del_comercio
                WHEN 'GB - Ilha 1' THEN 'Ilha 1'
                WHEN 'GB - Ilha 2' THEN 'Ilha 2'
                WHEN 'GB - Ilha 3' THEN 'Ilha 3'
                WHEN 'GB - Ilha 4' THEN 'Ilha 4'
                WHEN 'GB - HAMBURGUERIA' THEN 'Hamburgueria'
                WHEN 'GB - TERRAÇO' THEN 'Terraço'
                WHEN 'GB - KIDS' THEN 'Espaço Kids'
                ELSE TRIM(Nombre_del_comercio)
            END,  
            --Evento,
            CAST(Fecha AS DATE),
            CAST(Fecha AS TIME(0)),
            Total,
            -- Normalize selected product labels; retain trimmed source text for other products.
            CASE Producto
                WHEN 'Cerveja Itaipava Pilsen 350ml'    THEN 'Itaipava Pilsen 350ml'
                WHEN 'Black Princess'                   THEN 'Black Princess 350ml'
                ELSE TRIM(Producto)
            END,
            TRIM(Categoria),
            --Talle,
            Cantidad,
            Precio_Unitario,
            Total_Producto,
            --Correo_del_Comprador,
            --Telefono_del_Comprador,
            CASE N_de_identificacion_del_Comprador 
                WHEN '-' THEN NULL
                ELSE N_de_identificacion_del_Comprador
            END,
            --Cantidad_restante_de_beneficio,
            -- Remove a known separator artifact from the payment description.
            REPLACE(TRIM(Metodo_de_pago),'· ', ''),
            CASE Ultimos_digitos_de_la_tarjeta 
                WHEN ' ' THEN NULL
                ELSE Ultimos_digitos_de_la_tarjeta
            END,
            CASE
                WHEN LEN(Dispositivo_Clover) > 14 THEN SUBSTRING(Dispositivo_Clover, 1, 7)
                ELSE NULL
            END,
            CASE
                WHEN LEN(Dispositivo_Clover) < 15 THEN Dispositivo_Clover
                ELSE SUBSTRING(Dispositivo_Clover, 18, LEN(Dispositivo_Clover))
            END,
            --Delivery,
            --Estado_de_facturacion,
            Estado,
            Es_pre_compra,
            -- Extract YYYYMMDD from the end of the source filename and convert it using style 112.
            CONVERT(DATE, SUBSTRING(arquivo_fonte, LEN(arquivo_fonte) - 11, 8), 112),            
            arquivo_fonte,
            data_ingestao
        FROM bronze.vendas b
        WHERE NOT EXISTS (
            SELECT 1
            FROM silver.vendas s
            WHERE s.arquivo_fonte = b.arquivo_fonte
        );

        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST (DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'


        SET @start_time = GETDATE();
        -- Refresh the control log from Bronze so it reflects the files recorded there.
        PRINT '>>> Truncating silver.controle_carga';
        TRUNCATE TABLE silver.controle_carga;
        PRINT '>>> Inserting data into silver.controle_carga';
        INSERT INTO silver.controle_carga (
            arquivo,
            data_carga,
            linhas_carregadas
            )
        SELECT
            arquivo,
            data_carga,
            linhas_carregadas
        FROM bronze.controle_carga;
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST (DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'


        SET @start_time = GETDATE();
        -- Events are fully refreshed rather than incrementally merged.
        PRINT '>>> Truncating silver.eventos';
        TRUNCATE TABLE silver.eventos;
        PRINT '>>> Inserting data into silver.eventos';
        INSERT INTO silver.eventos (
            id_evento,
            data,
            horario_inicio,
            tipo_evento
        )
        SELECT
            CAST(id_evento AS INT),
            CAST(data AS DATE),
            CAST(horario_inicio AS TIME(0)),
            tipo_evento
        FROM bronze.eventos
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST (DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @batch_end_time = GETDATE();
        PRINT '====================================='
        PRINT '>>> Silver layer loading is complete';
        PRINT '====================================='
        PRINT '>>> Total load duration: ' + CAST (DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';

    END TRY
    BEGIN CATCH
    PRINT 'An error occurred while loading the silver layer'
    PRINT 'Error message: ' + ERROR_MESSAGE();
    PRINT 'Error message: ' + CAST (ERROR_NUMBER() AS NVARCHAR); 
    PRINT 'Error message: ' + CAST (ERROR_STATE() AS NVARCHAR);
    THROW
    END CATCH
END;

-- Example execution and inspection queries for development/testing.
-- EXECUTING THE STORED PROCEDURE


EXEC silver.load_silver;

SELECT * FROM silver.vendas;
SELECT * FROM silver.controle_carga;
SELECT * FROM silver.eventos;