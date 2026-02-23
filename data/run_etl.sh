#!/bin/bash

# acquire data from bdc @ https://broadbandmap.fcc.gov/data-download
unzip '*.zip' -d .

# quick setup for your duckdb (linux)
curl https://install.duckdb.org | sh
echo "install spatial; load spatial; install h3 from community; load h3;" >> ~/.duckdbrc

# use duckdb to make (geo)parquet files
duckdb < data_40.sql
duckdb < data_50.sql

# write query that returns a vector tile for a given x/y/z
# tile.sql