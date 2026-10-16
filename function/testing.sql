with e as (
    select st_tileenvelope(13,2172,3129) geom
), t as (
    select st_xmin(geom) xmin
        ,st_xmax(geom) xmax
        ,st_ymin(geom) ymin
        ,st_ymax(geom) ymax
        ,geom
    from e
)
select st_asmvt({
            "geometry": st_asmvtgeom(d.geom,st_extent(t.geom))
    },'overture_2026_buildings') mvt
from t,read_parquet('az://azduckmvtcontainer/overture_2026_buildings',hive_partitioning=true) d
where d.countyfips='21117'
    and d.xmin >= t.xmin
    and d.xmax <= t.xmax
    and d.ymin >= t.ymin
    and d.ymax >= t.ymax;