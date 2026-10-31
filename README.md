# Sales Data Warehouse

A SQL Server data warehouse project that transforms sales and event data into an analytical model using a Bronze, Silver, and Gold architecture. Python and pandas prepare the source files, while SQL Server handles data ingestion, cleaning, standardization, and the creation of dimensions and fact tables for analytical queries and reporting.

## Objectives

- Build a layered data pipeline for sales and event data.
- Separate raw ingestion, data cleaning, and analytical modeling into Bronze, Silver, and Gold layers.
- Standardize selected business and product labels and convert source values into typed columns.
- Create dimension and fact tables to support reporting and analysis.

## Technologies Used

- **SQL Server:** data ingestion, transformations, stored procedures, and dimensional modeling.
- **SQL:** table creation, data processing, and stored procedures across the Bronze, Silver, and Gold layers.
- **Python and pandas:** preprocessing of source Excel files and generation of CSV files for ingestion.

## Data Processing and Methodology

The pipeline follows this sequence:

**Source Excel files → Python preprocessing → CSV datasets → Bronze → Silver → Gold**

### 1. Python preprocessing

Source Excel files are processed with Python and pandas to generate pipe-delimited CSV files used by the SQL Server ingestion procedures. The generated files are stored in `datasets/`.

### 2. Bronze layer

Sales CSV files are loaded into staging tables and then into a raw landing table. The procedure checks the source header to choose between two staging layouts, depending on whether the optional `Es_pre_compra` column is present. The source path and row count are recorded in a load-control table.

### 3. Silver layer

Bronze values are converted to typed columns and selected business and product labels are standardized. The source filename and ingestion timestamp are retained for traceability. Sales are loaded incrementally based on whether the source filename already exists in Silver, while event and load-control tables are refreshed from Bronze.

### 4. Gold layer

The Gold layer contains dimensions for machines, products, and events, as well as fact tables for sales and payment components. The sales fact joins events by date, based on the project assumption that at most one relevant event occurs per date. Payment descriptions are split into components and normalized into method, brand, and amount fields.

**Note:** The Python preprocessing script is not included in this public repository because it contains company-specific information. The preprocessed CSV files are provided to demonstrate the input format and allow the SQL Server pipeline to be explored.

## Repository Structure

```text
sales-data-warehouse/
├── datasets/
│   └── ...
├── scripts/
│   ├── bronze/
│   │   ├── DDL_bronze.sql
│   │   └── proc_bronze.sql
│   ├── silver/
│   │   ├── DDL_silver.sql
│   │   └── proc_silver.sql
│   └── gold/
│       ├── DDL_gold.sql
│       └── proc_gold.sql
├── LICENSE
└── README.md
```
- **`datasets/`**: Contains the preprocessed source datasets used as input for the Bronze layer. It includes event reference data (`eventos.csv`) and sales reports (`reporte_limpo_*.csv`), with each sales file identified by the event date in its filename.
- **`scripts/bronze/`**: SQL scripts for raw data ingestion and storage.
- **`scripts/silver/`**: SQL scripts for data cleaning, standardization, and transformation.
- **`scripts/gold/`**: SQL scripts for building analytical dimensions and fact tables.

## Execution Order

1. Create the required schemas (`bronze`, `silver`, and `gold`) if they do not already exist.
2. Run `DDL_bronze.sql`, then `DDL_silver.sql`, and then `DDL_gold.sql`.
3. Configure the local input paths in `proc_bronze.sql`.
4. Execute the Bronze ingestion procedures for the sales files and event file.
5. Execute `silver.load_silver`.
6. Execute `gold.load_gold`.

## Assumptions and Limitations

- The file paths in the procedures are local development paths and must be updated for another environment.
- Sales CSV files are expected to use a pipe (`|`) delimiter, UTF-8 encoding, and a header row. The event CSV is expected to use a comma delimiter.
- The Bronze loader skips a source path already present in its load-control table.
- Silver incremental loading is based on source filename, not changes to file contents. Corrected files with the same name require an explicit reprocessing strategy.
- Gold loading truncates and rebuilds its tables on each execution.
- Payment fact generation selects one source row per order, assuming the relevant payment fields are consistent across all line items for that order.
- The DDL scripts drop and recreate their target tables, so they should be treated as setup/reset scripts rather than routine pipeline steps.
- These scripts are provided as a portfolio demonstration and may require environment-specific configuration before execution.

## Data Privacy

The datasets in this repository come from a real sales operation and were anonymized before publication. Location names were replaced with generic codes, and some event details were omitted. The original source files are not included in the repository, and no credentials or internal documents are published.
