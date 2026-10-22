/*
PROJECT: Sales Data Warehouse Project
LAYER: Gold
PURPOSE:
    Rebuild the analytical dimensions and fact tables from the cleaned Silver layer.

PROCESS OVERVIEW:
    1. Rebuild the machine dimension using serial codes and a representative device identifier.
    2. Rebuild the product dimension from distinct product/category combinations.
    3. Copy the typed event data into the event dimension.
    4. Populate the sales fact by joining Silver sales to the dimensions.
    5. Split each selected order's payment description into payment components and derive method,
       card brand, and payment amount.

BUSINESS RULES:
    - Records associated with the payment label 'Cortesía' or the business 'Varanda' are excluded
      from the relevant Gold outputs.
    - Sales are associated with events by date; this assumes the business domain has at most one
      relevant event per date.
    - Payment parsing relies on the format of the source payment-description strings.

DESIGN NOTES:
    - This procedure truncates and reloads all Gold tables on each execution.
    - ROW_NUMBER() generates the surrogate IDs used by the dimensions and payment fact.
    - The payment CTE selects one source row per order. This is appropriate only if the fields used
      for payment analysis are consistent across all line items of the same order.
*/

-- STORED PROCEDURE GOLD

-- Rebuilds the dimensional model and facts from Silver.
CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '====================='
        PRINT 'Loading gold layer';
        PRINT '====================='

        SET @start_time = GETDATE();
        -- Dimension: one row per serial code, with a representative Clover identifier.
        PRINT '>>> Truncating gold.dim_maquinas';
        TRUNCATE TABLE gold.dim_maquinas;
        PRINT '>>> Inserting data into gold.dim_maquinas';
        INSERT INTO gold.dim_maquinas (
            dispositivo_id,
            codigo_serie,
            dispositivo_clover
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY codigo_serie),
            codigo_serie,
            dispositivo_clover
        FROM (
            SELECT
                codigo_serie,
                MAX(dispositivo_clover) AS dispositivo_clover
            FROM silver.vendas
        WHERE (metodo_pagamento IS NULL OR metodo_pagamento != 'Cortesía')
        AND (nome_comercio IS NULL OR nome_comercio != 'Varanda')
            GROUP BY codigo_serie
        ) maquinas;
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'


        SET @start_time = GETDATE();
        -- Dimension: unique product/category pairs used to identify sales items.
        PRINT '>>> Truncating gold.dim_produtos';
        TRUNCATE TABLE gold.dim_produtos;
        PRINT '>>> Inserting data into gold.dim_produtos';
        INSERT INTO gold.dim_produtos (
            produto_id,
            produto,
            categoria
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY produto),
            produto,
            categoria
        FROM (
            SELECT DISTINCT
                produto,
                categoria
            FROM silver.vendas
            WHERE metodo_pagamento != 'Cortesía'
              AND nome_comercio != 'Varanda'
        ) produtos;
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'


        SET @start_time = GETDATE();
        -- Dimension: copy the already-typed event reference data from Silver.
        PRINT '>>> Truncating gold.dim_evento';
        TRUNCATE TABLE gold.dim_evento;
        PRINT '>>> Inserting data into gold.dim_evento';
        INSERT INTO gold.dim_evento (
            id_evento,
            data,
            horario_inicio,
            tipo_evento
        )
        SELECT
            id_evento,
            data,
            horario_inicio,
            tipo_evento
        FROM silver.eventos;
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'


        SET @start_time = GETDATE();
        -- Fact: one row per eligible sales line, enriched with dimension identifiers.
        -- The event join uses date, based on the project's one-event-per-date assumption.
        PRINT '>>> Truncating gold.fact_vendas';
        TRUNCATE TABLE gold.fact_vendas;
        PRINT '>>> Inserting data into gold.fact_vendas';
        INSERT INTO gold.fact_vendas (
            id_evento,
            numero_pedido,
            hora,
            total,
            produto_id,
            quantidade,
            preco_unitario,
            total_produto,
            identificacao_comprador,
            metodo_pagamento,
            ultimos_digitos_cartao,
            dispositivo_id,
            estado
        )
        SELECT
            e.id_evento,
            v.numero_pedido,
            v.hora,
            v.total,
            p.produto_id,
            v.quantidade,
            v.preco_unitario,
            v.total_produto,
            v.identificacao_comprador,
            v.metodo_pagamento,
            v.ultimos_digitos_cartao,
            m.dispositivo_id,
            v.estado
        FROM silver.vendas v
        LEFT JOIN gold.dim_evento e
            ON v.data = e.data
        LEFT JOIN gold.dim_maquinas m
            ON v.codigo_serie = m.codigo_serie
        LEFT JOIN gold.dim_produtos p
            ON v.produto = p.produto
            AND v.categoria = p.categoria
        WHERE (v.metodo_pagamento IS NULL OR v.metodo_pagamento != 'Cortesía')
        AND (v.nome_comercio IS NULL OR v.nome_comercio != 'Varanda');

        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'

        SET @start_time = GETDATE();
        -- Fact: split payment descriptions into separate payment components.
        -- The CTE chooses one row per order; this relies on payment fields being consistent across its items.
        PRINT '>>> Truncating gold.fact_pagamentos';
        TRUNCATE TABLE gold.fact_pagamentos;
        PRINT '>>> Inserting data into gold.fact_pagamentos';
        WITH pedidos AS (
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY numero_pedido ORDER BY numero_pedido) AS rn
            FROM silver.vendas
            )
        INSERT INTO gold.fact_pagamentos (
            pagamento_id,
            numero_pedido,
            metodo_pagamento,
            bandeira,
            valor_pagamento
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY numero_pedido, produto),
            numero_pedido,
            CASE
                WHEN TRIM(s.value) LIKE '%Credi%' THEN 'Cartão de crédito'
                WHEN TRIM(s.value) LIKE '%Debi%' THEN 'Cartão de débito'
                WHEN TRIM(s.value) LIKE '%Amex%' THEN 'Cartão'
                WHEN TRIM(s.value) LIKE 'QR%' THEN 'Pix'
                WHEN TRIM(s.value) LIKE 'Efectivo%' THEN 'Dinheiro'
                ELSE TRIM(s.value)
            END metodo_pagamento,

            CASE
                WHEN TRIM(s.value) LIKE '%Visa%' THEN 'Visa'
                WHEN TRIM(s.value) LIKE '%Mastercard%' THEN 'Mastercard'
                WHEN TRIM(s.value) LIKE '%Amex%' THEN 'Amex'
                WHEN TRIM(s.value) LIKE '%Elo%' THEN 'Elo'
                WHEN TRIM(s.value) LIKE 'QR%' THEN NULL
                WHEN TRIM(s.value) LIKE 'Efectivo%' THEN NULL
                ELSE TRIM(s.value)
            END bandeira,

            CASE
                WHEN TRIM(s.value) LIKE '%$%'
                THEN
                    CAST(
                        REPLACE(
                            SUBSTRING(
                                s.value,
                                CHARINDEX('$', s.value),
                                LEN(s.value)
                            ),
                            '$',
                            ''
                        ) AS DECIMAL(10,2)
                    )
                ELSE CAST(total AS DECIMAL(10,2))
            END AS valor_pagamento

        FROM pedidos p
        CROSS APPLY STRING_SPLIT(metodo_pagamento, ',') s
        WHERE rn = 1
        AND (metodo_pagamento IS NULL OR metodo_pagamento != 'Cortesía')
        AND (nome_comercio IS NULL OR nome_comercio != 'Varanda')
        SET @end_time = GETDATE();
        PRINT '>>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '-------------------------------------'


        SET @batch_end_time = GETDATE();
        PRINT '====================================='
        PRINT '>>> Gold layer loading is complete';
        PRINT '====================================='
        PRINT '>>> Total load duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';

    END TRY
    BEGIN CATCH
        PRINT 'An error occurred while loading the gold layer'
        PRINT 'Error message: ' + ERROR_MESSAGE();
        PRINT 'Error message: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error message: ' + CAST(ERROR_STATE() AS NVARCHAR);
        THROW
    END CATCH
END;
GO

-- Example execution and inspection queries for development/testing.
-- EXECUTING THE STORED PROCEDURE

EXEC gold.load_gold;


SELECT * FROM gold.dim_maquinas;
SELECT * FROM gold.dim_produtos;
SELECT * FROM gold.fact_vendas;
SELECT * FROM gold.fact_pagamentos;
SELECT * FROM gold.dim_evento;

