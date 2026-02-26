copy (
    select h3_res8_id
        ,technology
        ,string_agg(distinct brand_name) providers
        ,count(distinct location_id) locations
        ,max(max_advertised_download_speed) maxdown
        ,st_transform(st_geomfromwkb(h3_cell_to_boundary_wkb(h3_res8_id)),'EPSG:4326','EPSG:3857', true) geom 
    from '*.csv' 
    where technology=^TECHNOLOGY^
    group by 1,2
) to 'data_^TECHNOLOGY^.parquet';