load azure;
load spatial;
set azure_storage_connection_string = '';
set azure_transport_option_type = 'curl';

select st_asmvt({
         "attribute1": d.attribute1
        ,"attribute2": d.attribute2
        ,"geometry": st_asmvtgeom(d.geom,st_extent(e.geom))
    },'mvt_layer_name') mvt
from 'az://azduckmvtcontainer/data.parquet' d
join (
    select st_tileenvelope(0,0,0) geom
) e on st_intersects(e.geom,d.geom)=true;

