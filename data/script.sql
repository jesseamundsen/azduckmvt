-- use duckdb for etl
/*
cd data
rm data.duckdb
duckdb data.duckdb
*/



-- extensions / setup
install spatial; load spatial;
install httpfs; load httpfs;
install st_read_multi from community; load st_read_multi;
.timer on
-- hope your machine is better than my old laptop
set memory_limit='4gb';
set threads=4;



/*
rm -rf tiger_2026_counties
mkdir tiger_2026_counties
cd tiger_2026_counties
lftp -u anonymous:anonymous -e "mget /geo/tiger/TIGER2026/COUNTY/tl_*; quit;" ftp.census.gov
unzip '*.zip'
*/
drop table if exists counties;
create table counties as
with d as (
    select GEOID countyfips
        ,st_transform(st_setcrs(geom,'EPSG:4269'),'EPSG:3857',always_xy:=true) geom
    from st_read('tiger_2026_counties/tl_2026_us_county.shp')
    where statefp='21'
)
select countyfips
    ,st_xmin(geom) xmin
    ,st_xmax(geom) xmax
    ,st_ymin(geom) ymin
    ,st_ymax(geom) ymax
    ,geom
from d;



/*
rm -rf tiger_2026_roads
mkdir tiger_2026_roads
cd tiger_2026_roads
lftp -u anonymous:anonymous -e "mget /geo/tiger/TIGER2026/ROADS/tl_2026_21*; quit;" ftp.census.gov
unzip '*.zip'
*/
drop table if exists roads;
create table roads as
with d as (
    select right(left(".filename",30),5) countyfips
        ,* exclude (geometry)
        ,st_transform(st_setcrs(st_geomfromwkb(geometry),'EPSG:4269'),'EPSG:3857',always_xy:=true) geom 
    from st_read_multi('tiger_2026_roads/*.shp')
), e as (
    select st_extent(st_extent_agg(geom)) extent
    from d
)
select d.*
    ,st_xmin(geom) xmin
    ,st_xmax(geom) xmax
    ,st_ymin(geom) ymin
    ,st_ymax(geom) ymax
    ,row_number() over (order by st_hilbert(d.geom,e.extent)) rnk
from d,e;



/*
rm -rf nad_2026_addresses
mkdir nad_2026_addresses
cd nad_2026_addresses
curl -L -o nad_2026_addresses.zip "https://data.transportation.gov/download/fc2s-wawr/application%2Fx-z
ip-compressed"
unzip '*.zip'
*/
drop table if exists addresses;
create table addresses as
with d as (
    select a.* exclude (DateUpdate)
        ,st_transform(st_setcrs(st_point(longitude,latitude),'EPSG:4326'),'EPSG:3857',always_xy:=true) geom
    from read_csv('nad_2026_addresses/NAD_r24.txt', types={'Floor': 'VARCHAR'}) a 
    where a.State='KY'
), e as (
    select st_extent(st_extent_agg(geom)) extent
    from d
)
select c.countyfips
    ,d.*
    ,st_xmin(d.geom) xmin
    ,st_xmax(d.geom) xmax
    ,st_ymin(d.geom) ymin
    ,st_ymax(d.geom) ymax
    ,row_number() over (order by st_hilbert(d.geom,e.extent)) rnk
from d,e
join counties c on st_intersects(d.geom,c.geom);



-- buildings
set variable xmin = (select min(st_xmin(st_transform(st_setcrs(geom,'EPSG:3857'),'EPSG:4326',always_xy:=true))) from counties);
set variable xmax = (select max(st_xmax(st_transform(st_setcrs(geom,'EPSG:3857'),'EPSG:4326',always_xy:=true))) from counties);
set variable ymin = (select min(st_ymin(st_transform(st_setcrs(geom,'EPSG:3857'),'EPSG:4326',always_xy:=true))) from counties);
set variable ymax = (select max(st_ymax(st_transform(st_setcrs(geom,'EPSG:3857'),'EPSG:4326',always_xy:=true))) from counties);
set s3_region='us-west-2';
drop table if exists buildings;
create table buildings as
with d as (
    select id
        ,st_transform(geometry,'EPSG:3857') geom
    from read_parquet('s3://overturemaps-us-west-2/release/2026-09-23.1/theme=buildings/type=building/*', hive_partitioning=1)
    where bbox.xmin>=getvariable('xmin')
        and bbox.xmax<=getvariable('xmax')
        and bbox.ymin>=getvariable('ymin')
        and bbox.ymax<=getvariable('ymax')
), e as (
    select st_extent(st_extent_agg(geom)) extent
    from d
)
select c.countyfips
    ,d.id
    ,st_xmin(d.geom) xmin
    ,st_xmax(d.geom) xmax
    ,st_ymin(d.geom) ymin
    ,st_ymax(d.geom) ymax
    ,d.geom
    ,row_number() over (order by st_hilbert(d.geom,e.extent)) rnk
from d,e
join counties c on st_intersects(d.geom,c.geom);



/*
rm -rf parquet
mkdir parquet
*/
copy (
    select countyfips
        ,xmin
        ,xmax
        ,ymin
        ,ymax
        ,st_envelope(geom) geom
    from counties
) to '../function/index.parquet';

copy (
    select *
        ,(row_number() over (partition by countyfips order by rnk) // 100000)+1 filenum
    from buildings
)
to 'parquet/overture_2026_buildings/' (format 'parquet',partition_by (countyfips,filenum),row_group_size '20000');

copy (
    select *
        ,(row_number() over (partition by countyfips order by rnk) // 100000)+1 filenum
    from roads
)
to 'parquet/tiger_2026_roads/' (format 'parquet',partition_by (countyfips,filenum),row_group_size '20000');

copy (
    select *
        ,(row_number() over (partition by countyfips order by rnk) // 100000)+1 filenum
    from addresses
)
to 'parquet/nad_2026_addresses/' (format 'parquet',partition_by (countyfips,filenum),row_group_size '20000');