/*
PROJECT: Sales Data Warehouse Project
LAYER: Bronze
PURPOSE:
    Define the raw landing tables used to receive sales exports and event data.

DESIGN NOTES:
    - The staging tables keep source values as text to reduce conversion failures during ingestion.
    - Two sales staging layouts are maintained because some source files contain the optional Es_pre_compra column.
    - bronze.vendas stores the source filename and ingestion timestamp for traceability.
    - bronze.controle_carga records which source files have been loaded and how many rows were inserted.

IMPORTANT:
    This script drops and recreates its tables. Running it deletes the existing contents of those tables.
    Use it as a setup/reset script, not as a routine production load.
*/

-- DDL BRONZE

IF OBJECT_ID ('bronze.stg_vendas1', 'U') IS NOT NULL
    DROP TABLE bronze.stg_vendas1;
GO
-- Staging layout for source files without Es_pre_compra.
CREATE TABLE bronze.stg_vendas1 (
    Numero_de_orden                     VARCHAR(50),
    Palco                               VARCHAR(50),
    Nombre_del_comercio                 VARCHAR(50),
    Evento                              VARCHAR(50),
    Fecha                               VARCHAR(50),
    Total                               VARCHAR(50),
    Producto                            VARCHAR(50),
    Categoria                           VARCHAR(50),
    Talle                               VARCHAR(50),
    Cantidad                            VARCHAR(50),
    Precio_Unitario                     VARCHAR(50),
    Total_Producto                      VARCHAR(50),
    Correo_del_Comprador                VARCHAR(100),
    Telefono_del_Comprador              VARCHAR(50),
    N_de_identificacion_del_Comprador   VARCHAR(50),
    Cantidad_restante_de_beneficio      VARCHAR(50),
    Metodo_de_pago                      VARCHAR(100),
    Ultimos_digitos_de_la_tarjeta       VARCHAR(50),
    Dispositivo_Clover                  VARCHAR(100),
    Delivery                            VARCHAR(50),
    Estado_de_facturacion               VARCHAR(50),
    Estado                              VARCHAR(50)
);
GO
IF OBJECT_ID ('bronze.stg_vendas2', 'U') IS NOT NULL
    DROP TABLE bronze.stg_vendas2;
GO
-- Alternate staging layout when the optional Es_pre_compra column exists.
CREATE TABLE bronze.stg_vendas2 (
    Numero_de_orden                     VARCHAR(50),
    Palco                               VARCHAR(50),
    Nombre_del_comercio                 VARCHAR(50),
    Evento                              VARCHAR(50),
    Fecha                               VARCHAR(50),
    Total                               VARCHAR(50),
    Producto                            VARCHAR(50),
    Categoria                           VARCHAR(50),
    Talle                               VARCHAR(50),
    Cantidad                            VARCHAR(50),
    Precio_Unitario                     VARCHAR(50),
    Total_Producto                      VARCHAR(50),
    Correo_del_Comprador                VARCHAR(100),
    Telefono_del_Comprador              VARCHAR(50),
    N_de_identificacion_del_Comprador   VARCHAR(50),
    Cantidad_restante_de_beneficio      VARCHAR(50),
    Metodo_de_pago                      VARCHAR(100),
    Ultimos_digitos_de_la_tarjeta       VARCHAR(50),
    Dispositivo_Clover                  VARCHAR(100),
    Delivery                            VARCHAR(50),
    Estado_de_facturacion               VARCHAR(50),
    Es_pre_compra                       VARCHAR(50),
    Estado                              VARCHAR(50)
);
GO
IF OBJECT_ID ('bronze.vendas', 'U') IS NOT NULL
    DROP TABLE bronze.vendas;
GO
-- Raw landing table: values are preserved largely as received from the source export.
CREATE TABLE bronze.vendas (
    Numero_de_orden                     VARCHAR(50),
    Palco                               VARCHAR(50),
    Nombre_del_comercio                 VARCHAR(50),
    Evento                              VARCHAR(50),
    Fecha                               VARCHAR(50),
    Total                               VARCHAR(50),
    Producto                            VARCHAR(50),
    Categoria                           VARCHAR(50),
    Talle                               VARCHAR(50),
    Cantidad                            VARCHAR(50),
    Precio_Unitario                     VARCHAR(50),
    Total_Producto                      VARCHAR(50),
    Correo_del_Comprador                VARCHAR(100),
    Telefono_del_Comprador              VARCHAR(50),
    N_de_identificacion_del_Comprador   VARCHAR(50),
    Cantidad_restante_de_beneficio      VARCHAR(50),
    Metodo_de_pago                      VARCHAR(100),
    Ultimos_digitos_de_la_tarjeta       VARCHAR(50),
    Dispositivo_Clover                  VARCHAR(100),
    Delivery                            VARCHAR(50),
    Estado_de_facturacion               VARCHAR(50),
    Es_pre_compra                       VARCHAR(50),
    Estado                              VARCHAR(50),
    arquivo_fonte                       VARCHAR(500),
    data_ingestao                       DATETIME DEFAULT GETDATE()
);
GO
IF OBJECT_ID ('bronze.controle_carga', 'U') IS NOT NULL
    DROP TABLE bronze.controle_carga;
GO
-- One record per successfully processed sales file; used to avoid duplicate file loads.
CREATE TABLE bronze.controle_carga (
    arquivo             VARCHAR(500),
    data_carga          DATETIME DEFAULT GETDATE(),
    linhas_carregadas   INT
);
GO
IF OBJECT_ID ('bronze.eventos', 'U') IS NOT NULL
    DROP TABLE bronze.eventos;
GO
-- Raw event data; values are converted to typed fields in Silver.
CREATE TABLE bronze.eventos (
    id_evento       VARCHAR(10),
    data            VARCHAR(20),
    horario_inicio  VARCHAR(20),
    tipo_evento     VARCHAR(100)
);