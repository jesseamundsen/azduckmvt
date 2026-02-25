# azduckmvt

This project shows how to build a serverless tile API by using DuckDB, GeoParquet, and Azure Storage + Functions.

**Folders**
* `data` is used for ETL to prepare data.
* `function` contains the Azure Function code as well as a mini demo client.
  * The function will deliver the mini demo client when called at `/api/demo`.

**Scripts**
* `data/script.sh` will act upon downloaded zip files from the [Broadband Map](https://broadbandmap.fcc.gov/data-download/) to create GeoParquet files.
* `function/script.sh` shows how to setup and deploy resources to Azure.