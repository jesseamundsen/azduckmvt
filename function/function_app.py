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

@app.route(route="tiles/{technology}/{z}/{x}/{y}")
def tiles(req: func.HttpRequest) -> func.HttpResponse:
    try:
        technology = int(req.route_params.get('technology'))
        z = int(req.route_params.get('z'))
        x = int(req.route_params.get('x'))
        y = int(req.route_params.get('y'))
    except:
        return func.HttpResponse(status_code=400)
    sql = """
        select st_asmvt({
                "h3_8": d.h3_8
                "locations": d.locations
                ,"providers": d.providers
                ,"geometry": st_asmvtgeom(d.geom,st_extent(e.geom))
            },'default') mvt
        from 'az://azduckmvtcontainer/data_*.parquet' d
        join (
            select st_tileenvelope(?,?,?) geom
        ) e on st_intersects(e.geom,d.geom)=true
        where d.technology=?;
    """
    try:
        result = dbcn.execute(sql, [z, x, y, technology]).fetchone()
        tile = result[0]
    except:
        return func.HttpResponse(status_code=204)
    return func.HttpResponse(status_code=200, body=tile, mimetype="application/vnd.mapbox-vector-tile")

@app.route(route="demo")
def demo(req: func.HttpRequest) -> func.HttpResponse:
    with open('azduckmvt.html') as f:
        html = f.read()
    return func.HttpResponse(body=html, mimetype="text/html")