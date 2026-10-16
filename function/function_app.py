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
        layer = str(req.route_params.get('layer'))
        z = int(req.route_params.get('z'))
        x = int(req.route_params.get('x'))
        y = int(req.route_params.get('y'))
        if z < 10:
            raise
    except:
        return func.HttpResponse(status_code=400)

    sql = f"select string_agg(''''||countyfips||'''',',') from 'index.parquet' where st_intersects(geom,st_tileenvelope({z},{x},{y}))"
    countyfips = dbcn.execute(sql).fetchone()[0]
    
    sql = f"""
        with e as (
            select st_tileenvelope({z},{x},{y}) geom
        ), t as (
            select st_xmin(geom) xmin
                ,st_xmax(geom) xmax
                ,st_ymin(geom) ymin
                ,st_ymax(geom) ymax
                ,geom
            from e
        )
        select st_asmvt(f, '{layer}', 4096, 'mvt') mvt
        from (
            select d.* exclude (geom)
                ,st_asmvtgeom(d.geom, st_extent(t.geom)) mvt
            from t,read_parquet('az://azduckmvtcontainer/{layer}',hive_partitioning=true) d
            where d.countyfips in ({countyfips})
            and d.xmax >= t.xmin
            and d.xmin <= t.xmax
            and d.ymax >= t.ymin
            and d.ymin <= t.ymax
        ) f;
    """
    # ky z/x/y 13/2172/3129
    try:
        result = dbcn.execute(sql).fetchone()
        tile = result[0]
    except:
        logging.error('error', exc_info=True)
        return func.HttpResponse(status_code=204)
    return func.HttpResponse(status_code=200, body=tile, mimetype="application/vnd.mapbox-vector-tile")