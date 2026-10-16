# azduckmvt

This project shows how to build a serverless tile API by using DuckDB, GeoParquet, and Azure Storage + Functions.

**Folders**
* `data` is used for ETL to prepare data.
* `function` contains the Azure Function code as well as a mini demo client.
* `web` contains the demo single page application that accesses the function for tile display.

**Scripts**
* `data/data.sql` contains the ETL steps and sbusequent building of GeoParquet files.
* `function/script.sh` shows how to setup and deploy resources to Azure as well as publishing the GeoParquet data to Azure Storage.
* `web/publish.sh` to publish the single page app to the static web storage and view the delivery URL.