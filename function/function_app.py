import azure.functions as func
import datetime
import json
import logging
import duckdb
import os

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

def connection():
    cn = duckdb.connect(config={'extension_directory': os.path.join(os.getcwd(), 'extensions')})
    cn.execute(f"""load azure; load spatial;
        set azure_storage_connection_string = '{os.getenv("AZURE_STORAGE_CONNECTION_STRING")}';
        set azure_transport_option_type = 'curl';
    """)
    return cn
dbcn = connection()

@app.route(route="tiles/{layer}/{z}/{x}/{y}")
def tiles(req: func.HttpRequest) -> func.HttpResponse:
    try:
        layer = int(req.route_params.get('layer'))
        z = int(req.route_params.get('z'))
        x = int(req.route_params.get('x'))
        y = int(req.route_params.get('y'))
    except:
        return func.HttpResponse(status_code=400)
    sql = f"""
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
        select st_asmvt({{
                    "geometry": st_asmvtgeom(d.geom,st_extent(t.geom))
            }},'{layer}') mvt
        from t,read_parquet('az://azduckmvtcontainer/{layer}',hive_partitioning=true) d
        where d.countyfips in ('{countyfips}')
            and d.xmin >= t.xmin
            and d.xmax <= t.xmax
            and d.ymin >= t.ymin
            and d.ymax >= t.ymax;
    """
    # ky z/x/y 13/2172/3129
    try:
        result = dbcn.execute(sql, [z, x, y, countyfips]).fetchone()
        tile = result[0]
    except:
        return func.HttpResponse(status_code=204)
    return func.HttpResponse(status_code=200, body=tile, mimetype="application/vnd.mapbox-vector-tile")