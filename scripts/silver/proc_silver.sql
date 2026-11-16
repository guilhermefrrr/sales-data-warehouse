/*
PROJECT: Sales Data Warehouse Project
LAYER: Silver
PURPOSE:
    Convert raw Bronze sales values into typed, standardized records and refresh supporting tables.

TRANSFORMATIONS:
    - Convert order numbers, dates, times, quantities, prices, and totals to their target types.
    - Standardize selected business and product labels.
    - Trim text fields and normalize selected payment and customer-identification values.
    - Split device information into a device identifier and a serial code according to source format.
    - Derive data_evento from the date embedded in arquivo_fonte.
    - Records associated with the payment label 'Cortesía' or the business 'Varanda' are excluded
    from the relevant outputs since records under these conditions correspond to test transactions.
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
        -- CTE to remove a known separator artifact from the payment description.
        WITH dados_tratados AS (
            SELECT 
                b.*,
                REPLACE(TRIM(b.Metodo_de_pago), '· ', '') AS pagamento_limpo
            FROM bronze.vendas b
        )
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
            metodo_pagamento,
            bandeira,
            dispositivo,
            codigo_serie,
            pedido_original,
            status_venda,
            estado,
            data_evento,
            arquivo_fonte,
            data_ingestao
        )
        SELECT
            CAST(Numero_de_orden AS INT),
            --Palco,
            -- Map source business labels to consistent reporting names.
            CASE Nombre_del_comercio
                WHEN 'ESPAÇO 1' THEN 'Loja 1'
                WHEN 'ESPAÇO 2' THEN 'Loja 2'
                WHEN 'ESPAÇO 3' THEN 'Loja 3'
                WHEN 'ESPAÇO 4' THEN 'Loja 4'
                WHEN 'ESPAÇO 5' THEN 'Loja 5'
                WHEN 'ESPAÇO 6' THEN 'Loja 6'
                WHEN 'ESPAÇO 7' THEN 'Loja 7'
                WHEN 'ESPAÇO 8' THEN 'Loja 8'
                ELSE TRIM(Nombre_del_comercio)
            END,  
            --Evento,
            CAST(Fecha AS DATE),
            CAST(Fecha AS TIME(0)),
            Total,
            TRIM(Producto),
            TRIM(Categoria),
            --Talle,
            Cantidad,
            Precio_Unitario,
            Total_Producto,
            --Correo_del_Comprador,
            --Telefono_del_Comprador,
            --N_de_identificacion_del_Comprador 
            --Cantidad_restante_de_beneficio,
            CASE
                WHEN pagamento_limpo LIKE '%Credi%' THEN 'Cartão de crédito'
                WHEN pagamento_limpo LIKE '%Debi%' THEN 'Cartão de débito'
                WHEN pagamento_limpo LIKE '%Amex%' THEN 'Cartão'
                WHEN pagamento_limpo LIKE 'QR%' THEN 'Pix'
                WHEN pagamento_limpo LIKE 'Efectivo%' THEN 'Dinheiro'
                ELSE pagamento_limpo
            END metodo_pagamento,
            CASE
                WHEN pagamento_limpo LIKE '%Visa%' THEN 'Visa'
                WHEN pagamento_limpo LIKE '%Mastercard%' THEN 'Mastercard'
                WHEN pagamento_limpo LIKE '%Amex%' THEN 'Amex'
                WHEN pagamento_limpo LIKE '%Elo%' THEN 'Elo'
                WHEN pagamento_limpo LIKE 'Pix' THEN NULL
                WHEN pagamento_limpo LIKE 'QR%' THEN NULL
                WHEN pagamento_limpo LIKE 'Efectivo%' THEN NULL
                ELSE pagamento_limpo
            END bandeira,
            --Ultimos_digitos_de_la_tarjeta,
            CASE
                WHEN LEN(Dispositivo) = 22 THEN SUBSTRING(Dispositivo, 1, 5)
                WHEN LEN(Dispositivo) = 23 THEN SUBSTRING(Dispositivo, 1, 6)
                ELSE NULL
            END dispositivo,
            CASE
                WHEN LEN(Dispositivo) < 15 THEN Dispositivo
                WHEN LEN(Dispositivo) = 22 THEN SUBSTRING(Dispositivo, 9, LEN(Dispositivo))
                WHEN LEN(Dispositivo) = 23 THEN SUBSTRING(Dispositivo, 10, LEN(Dispositivo))
                ELSE NULL
            END codigo_serie,
            --Delivery,
            --Estado_de_facturacion,
            NULL,
            'Venda',
            Estado,
            --Es_pre_compra,
            -- Extract YYYYMMDD from the end of the source filename and convert it using style 112.
            CONVERT(DATE, SUBSTRING(arquivo_fonte, LEN(arquivo_fonte) - 11, 8), 112),            
            arquivo_fonte,
            data_ingestao
        FROM dados_tratados b
        WHERE Metodo_de_pago != 'Cortesía' 
        AND Nombre_del_comercio != 'Loja 8'
        AND NOT EXISTS (
            SELECT 1
            FROM silver.vendas s
            WHERE s.arquivo_fonte = b.arquivo_fonte
        );

        
        -- Identify refund records and extract the original order number.
        PRINT '>>> Identifying refunds in silver.vendas';

        UPDATE silver.vendas
        SET
            pedido_original = TRY_CONVERT(
                INT,
                LTRIM(RTRIM(
                    SUBSTRING(
                        metodo_pagamento,
                        LEN(N'Devolución de orden') + 2,
                        LEN(metodo_pagamento)
                    )
                ))
            ),
            status_venda = 'Devolução'
        WHERE metodo_pagamento LIKE N'Devolución de orden%';


        -- Identify original sales associated with a refund.
        PRINT '>>> Identifying cancelled sales in silver.vendas';

        UPDATE v
        SET status_venda = 'Cancelada'
        FROM silver.vendas v
        WHERE EXISTS (
            SELECT 1
            FROM silver.vendas d
            WHERE d.pedido_original = v.numero_pedido
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
        FROM bronze.eventos;
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

-- EXECUTING THE STORED PROCEDURE


EXEC silver.load_silver;

SELECT * FROM silver.vendas;
SELECT * FROM silver.controle_carga;
SELECT * FROM silver.eventos;