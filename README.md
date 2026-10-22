# Sales Data Warehouse Project

## Overview

This project organizes sales and event data into a SQL Server data warehouse using a layered architecture:

- **Bronze** — raw source data and file-level load tracking.
- **Silver** — typed, standardized data with selected business and product labels normalized.
- **Gold** — dimensions and fact tables prepared for analytical queries and reporting.

Python/pandas is used in the initial source-file preparation step; SQL Server handles ingestion, transformations, and analytical modeling.

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

- **datasets/**: Source datasets used in the project.
- **scripts/bronze/**: SQL scripts for raw data ingestion and storage.
- **scripts/silver/**: SQL scripts for data cleaning, standardization, and transformation.
- **scripts/gold/**: SQL scripts for building analytical dimensions and fact tables.
- **LICENSE**: Defines the terms under which the repository can be used.
- **README.md**: Project overview, architecture, data processing workflow, and execution instructions.

## Layer responsibilities

### Bronze

Sales CSV files are loaded into staging tables and then into a raw landing table. The procedure checks the source header to choose between two staging layouts, depending on whether the optional `Es_pre_compra` column is present. The source path and row count are recorded in a load-control table.

### Silver

Bronze values are converted to typed columns and selected business/product labels are standardized. The source filename and ingestion timestamp are retained for traceability. Sales are loaded incrementally based on whether the source filename already exists in Silver; event and load-control tables are refreshed from Bronze.

### Gold

The Gold layer contains dimensions for machines, products, and events, plus facts for sales and payment components. The sales fact joins events by date, relying on the project assumption that at most one relevant event occurs per date. Payment descriptions are split into components and normalized into method, brand, and amount fields.

## Important assumptions and limitations

- File paths in the procedures are local development paths and must be updated for another environment.
- Sales CSV files are expected to use a pipe (`|`) delimiter, UTF-8 encoding, and a header row. The event CSV is expected to use a comma delimiter.
- The Bronze loader skips a source path already present in its load-control table.
- Silver incremental loading is based on source filename, not on changes to file contents. Corrected files with the same name require an explicit reprocessing strategy.
- Gold loading truncates and rebuilds its tables on each execution.
- Payment fact generation selects one source row per order. This assumes the relevant payment fields are consistent across all line items for that order.
- These scripts are provided as a portfolio demonstration and may require environment-specific configuration before execution.

## Execution order

1. Create the required schemas (`bronze`, `silver`, `gold`) if they do not already exist.
2. Run `DDL_bronze.sql`, then `DDL_silver.sql`, then `DDL_gold.sql`.
3. Configure the local input paths in `proc_bronze.sql`.
4. Execute the Bronze ingestion procedures for the sales files and event file.
5. Execute `silver.load_silver`.
6. Execute `gold.load_gold`.

The DDL scripts drop and recreate their target tables, so they should be treated as setup/reset scripts rather than routine pipeline steps.

## Privacy

The public version of this repository should not contain source exports, customer identifiers, credentials, or internal documents. Use approved, anonymized, or synthetic sample data for demonstrations.
