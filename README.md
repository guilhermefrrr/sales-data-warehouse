# Sales Data Warehouse

A SQL Server data warehouse project that transforms sales and event data into an analytical model using Bronze, Silver, and Gold layers. Python and pandas prepare the source files, while SQL Server handles ingestion, cleaning, and dimensional modeling. Also available in an interactive website.

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
├── index.html
├── index-standalone.html
├── data.json
├── datasets/
│   └── ...
├── scripts/
│   ├── bronze/
│   │   ├── DDL_bronze.sql
│   │   └── proc_bronze.sql
│   ├── silver/
│   │   ├── DDL_silver.sql
│   │   └── proc_silver.sql
│   ├── gold/
│   │   ├── DDL_gold.sql
│   │   └── proc_gold.sql
│   └── ssms_to_json_colab.ipynb
├── LICENSE
└── README.md
```

- **`index.html`**: Light version of the website (web). It has no data inside and loads `data.json` with `fetch()`. For GitHub Pages / server. It does not work with double-click (`file://`), because the browser blocks `fetch()` in `file://`.
- **`index-standalone.html`**: Standalone version of the website (1 file only). It has the data embedded inside it. For sending by WhatsApp / e-mail and opening with double-click, without needing `data.json` next to it.
- **`data.json`**: Calculated numbers used by the light version (revenue, orders, products, payments, machines). It must stay in the repository root, next to `index.html`.
- **`datasets/`**: Contains the preprocessed source datasets used as input for the Bronze layer. It includes event reference data (`eventos.csv`) and sales reports (`reporte_limpo_*.csv`), with each sales file identified by the event date in its filename.
- **`scripts/bronze/`**: SQL scripts for raw data ingestion and storage.
- **`scripts/silver/`**: SQL scripts for data cleaning, standardization, and transformation.
- **`scripts/gold/`**: SQL scripts for building analytical dimensions and fact tables.
- **`scripts/ssms_to_json_colab.ipynb`**: Google Colab notebook that generates `data.json`, `index.html`, and `index-standalone.html` from a new SSMS dump.

## Execution Order

1. Create the required schemas (`bronze`, `silver`, and `gold`) if they do not already exist.
2. Run `DDL_bronze.sql`, then `DDL_silver.sql`, and then `DDL_gold.sql`.
3. Configure the local input paths in `proc_bronze.sql`.
4. Execute the Bronze ingestion procedures for the sales files and event file.
5. Execute `silver.load_silver`.
6. Execute `gold.load_gold`.

## How to update the website

When new data arrives, regenerate the 3 website files together, from the same dump. Do not update only one of them.

1. Open `scripts/ssms_to_json_colab.ipynb` in Google Colab.
2. In Cell 1, upload the new `.sql` dump from SSMS.
3. Run the cells in order. Cell 3 runs quick checks and stops if the base is incomplete.
4. In Cell 5, upload the current `index.html` (light or standalone, either works). The notebook recreates both versions from the same `data.json`.
5. In Cell 6, download the 3 updated files: `data.json`, `index.html`, and `index-standalone.html`.
6. Upload the 3 files to the repository root, replacing the old ones.

Notes:
- The 2 HTML versions have exactly the same data, charts, filters, and visual. The only difference is where the data lives: in the light version, in `data.json` next to it; in the standalone version, embedded inside the HTML.
- If you update `index.html` but forget to update `data.json`, the light version will keep showing the old data. The standalone version does not have this problem, because it already carries its data inside.
- If the light version is opened with double-click (`file://`), it shows a warning because the browser blocks `fetch()`. In that case, use `index-standalone.html`, or open the light version with a server / GitHub Pages, with `data.json` in the same folder. As a last resort, the warning box lets you select `data.json` manually.

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
