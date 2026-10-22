/*
PROJECT: Sales Data Warehouse Project
LAYER: Gold
PURPOSE:
    Define the dimensional model used for analytics and reporting.

MODEL OVERVIEW:
    - Dimensions: machines/devices, products, and events.
    - Fact tables: sales line items and payment-method breakdowns.
    - Surrogate identifiers are stored in dimensions and referenced by the sales fact.

IMPORTANT:
    This script drops and recreates the Gold tables, deleting existing data. Use it for setup/reset only.
    The current DDL declares primary keys on dimension identifiers and pagamento_id; foreign-key
    constraints between facts and dimensions are not declared in this version.
*/

-- DDL GOLD

IF OBJECT_ID ('gold.dim_maquinas', 'U') IS NOT NULL
    DROP TABLE gold.dim_maquinas;
GO
CREATE TABLE gold.dim_maquinas (
    dispositivo_id      INT PRIMARY KEY,
    codigo_serie        VARCHAR(50),
    dispositivo_clover  VARCHAR(50)
);
GO

IF OBJECT_ID ('gold.dim_produtos', 'U') IS NOT NULL
    DROP TABLE gold.dim_produtos;
GO
CREATE TABLE gold.dim_produtos (
    produto_id  INT PRIMARY KEY,
    produto     VARCHAR(50),
    categoria   VARCHAR(50)
);
GO

IF OBJECT_ID ('gold.dim_evento', 'U') IS NOT NULL
    DROP TABLE gold.dim_evento;
GO
CREATE TABLE gold.dim_evento (
    id_evento       INT PRIMARY KEY,
    data            DATE,
    horario_inicio  TIME(0),
    tipo_evento     VARCHAR(100)
);
GO

IF OBJECT_ID ('gold.fact_vendas', 'U') IS NOT NULL
    DROP TABLE gold.fact_vendas;
GO
CREATE TABLE gold.fact_vendas (
    id_evento               INT,
    numero_pedido           INT,
    hora                    TIME(0),
    total                   DECIMAL(10,2),
    produto_id              INT,
    quantidade              INT,
    preco_unitario          DECIMAL(10,2),
    total_produto           DECIMAL(10,2),
    identificacao_comprador VARCHAR(100),
    metodo_pagamento        VARCHAR(100),
    ultimos_digitos_cartao  VARCHAR(50),
    dispositivo_id          INT,
    estado                  INT
);
GO

IF OBJECT_ID ('gold.fact_pagamentos', 'U') IS NOT NULL
    DROP TABLE gold.fact_pagamentos;
GO
CREATE TABLE gold.fact_pagamentos (
    pagamento_id        INT PRIMARY KEY,
    numero_pedido       INT,
    metodo_pagamento    VARCHAR(100),
    bandeira            VARCHAR(50),
    valor_pagamento     DECIMAL(10,2)
);


