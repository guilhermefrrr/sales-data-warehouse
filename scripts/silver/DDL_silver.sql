/*
PROJECT: Sales Data Warehouse Project
LAYER: Silver
PURPOSE:
    Define typed and standardized tables for cleaned sales data, load-control metadata,
    and event data.

DESIGN NOTES:
    - Sales columns use numeric and date/time types where appropriate.
    - Source-specific or non-analytical columns are intentionally not carried into silver.vendas.
    - arquivo_fonte and data_ingestao are retained for lineage and troubleshooting.
    - Event fields are converted to typed values during the Silver load.

IMPORTANT:
    This script drops and recreates its tables, deleting existing data. Use it for setup/reset only.
*/

-- DDL SILVER

IF OBJECT_ID ('silver.vendas', 'U') IS NOT NULL
    DROP TABLE silver.vendas;
GO
-- Cleaned sales table with typed fields and retained source lineage.
CREATE TABLE silver.vendas (
    numero_pedido                       INT,
    --Palco                             VARCHAR(50),
    nome_comercio                       VARCHAR(50),
    --Evento                            VARCHAR(50),
    data                                DATE,
    hora                                TIME(0),
    total                               DECIMAL(10,2),
    produto                             VARCHAR(50),
    categoria                           VARCHAR(50),
    --Talle                             VARCHAR(50),
    quantidade                          INT,
    preco_unitario                      DECIMAL(10,2),
    total_produto                       DECIMAL(10,2),
    --Correo_del_Comprador              VARCHAR(100),
    --Telefono_del_Comprador            VARCHAR(50),
    identificacao_comprador             VARCHAR(100),
    --Cantidad_restante_de_beneficio    VARCHAR(50),
    metodo_pagamento                    VARCHAR(500),
    ultimos_digitos_cartao              VARCHAR(50),
    dispositivo_clover                  VARCHAR(50),
    codigo_serie                        VARCHAR(50),
    --Delivery                          VARCHAR(50),
    --Estado_de_facturacion             VARCHAR(50),
    estado                              INT,
    es_pre_compra                       VARCHAR(50),
    data_evento                         DATE,
    arquivo_fonte                       VARCHAR(1000),
    data_ingestao                       DATETIME2
);
GO
IF OBJECT_ID ('silver.controle_carga', 'U') IS NOT NULL
    DROP TABLE silver.controle_carga;
GO
-- Mirrors the Bronze file-load log for visibility at the Silver layer.
CREATE TABLE silver.controle_carga (
    arquivo             VARCHAR(500),
    data_carga          DATETIME,
    linhas_carregadas   INT
);
GO
IF OBJECT_ID ('silver.eventos', 'U') IS NOT NULL
    DROP TABLE silver.eventos;
GO
-- Typed event reference data used by the Gold model.
CREATE TABLE silver.eventos (
    id_evento       INT,
    data            DATE,
    horario_inicio  TIME(0),
    tipo_evento     VARCHAR(100)
);