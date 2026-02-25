#!/bin/bash

# acquire data from bdc @ https://broadbandmap.fcc.gov/data-download
unzip '*.zip' -d .

# quick setup for your duckdb (linux)
curl https://install.duckdb.org | sh
echo "install spatial; load spatial; install h3 from community; load h3;" >> ~/.duckdbrc

# use duckdb to make (geo)parquet files
for tech in 10 40 50 60 61 70 71 72; do
    sed "s/\^TECHNOLOGY\^/$tech/g" script.sql | duckdb
done