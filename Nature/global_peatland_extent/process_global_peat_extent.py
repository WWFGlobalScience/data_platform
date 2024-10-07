"""Description of processing `glclu_2000_2020.txt`."""
import logging
import os

from collections import defaultdict
import numpy as np
from ecoshard import taskgraph
from osgeo import gdal
from osgeo import osr
from osgeo import ogr
import numpy
import ecoshard.geoprocessing as geoprocessing


gdal.SetCacheMax(2**27)

logging.basicConfig(
    level=logging.DEBUG,
    format=(
        '%(asctime)s (%(relativeCreated)d) %(processName)s %(levelname)s '
        '%(name)s [%(funcName)s:%(lineno)d] %(message)s'))
LOGGER = logging.getLogger(__name__)
logging.getLogger('ecoshard.taskgraph').setLevel(logging.INFO)
logging.getLogger('ecoshard.geoprocessing').setLevel(logging.INFO)

BASE_DATA_DIR = '../../data'
RASTER_BASE = 'peatGPA22WGS_2cl'
RASTER_PATH = f'{RASTER_BASE}.tif'
CLIPPED_DIR = 'clipped_rasters'
OUTPUT_DIR = 'output'

for dir_path in [CLIPPED_DIR, OUTPUT_DIR]:
    os.makedirs(dir_path, exist_ok=True)

# I know those rasters are 1km because the website says so
TARGET_PIXEL_SIZE = (1000, -1000)
NODATA = 255

RASTER_ID_TO_TYPE = {
    1: 'peat dominated',
    2: 'peat in soil mosaic',
}


def sum_area_types(valid_mask_raster_path):
    nodata = geoprocessing.get_raster_info(
        valid_mask_raster_path)['nodata'][0]
    raster_array = gdal.OpenEx(
        valid_mask_raster_path).ReadAsArray().astype(float)
    valid_mask = raster_array != nodata
    total_mask_area = {}
    # raster units are defiend in RASTER_ID_TO_TYPE
    for raster_id in RASTER_ID_TO_TYPE:
        mask_pixel_count = np.sum(raster_array[valid_mask & (raster_array == raster_id)])
        # / 1e4 to convert to hectares
        total_mask_area[raster_id] = (
            mask_pixel_count *
            abs(numpy.multiply(*TARGET_PIXEL_SIZE)) /
            1e4)
    raster_array = None
    return total_mask_area


def warp_raster_to_new_projection(
        base_raster_path,
        target_bounding_box,
        clipping_vector_path,
        clipping_vector_fid,
        target_projection_wkt,
        target_pixel_size,
        target_raster_path):
    raster_info = geoprocessing.get_raster_info(base_raster_path)
    projected_target_bounding_box = geoprocessing.transform_bounding_box(
        target_bounding_box,
        raster_info['projection_wkt'],
        target_projection_wkt)

    geoprocessing.warp_raster(
        base_raster_path, target_pixel_size, target_raster_path,
        'near',
        target_bb=projected_target_bounding_box,
        target_projection_wkt=target_projection_wkt,
        vector_mask_options={
            'mask_vector_path': clipping_vector_path,
            'mask_vector_where_filter': f'fid={clipping_vector_fid}',
            'target_mask_value': NODATA},
        gdal_warp_options=None, working_dir='.')
    target_raster = gdal.OpenEx(target_raster_path, gdal.GA_Update)
    target_band = target_raster.GetRasterBand(1)
    target_band.SetNoDataValue(NODATA)
    target_band = None
    target_raster = None


def add_coverage_area_to_features(
        area_lookup_by_feature_by_type,
        base_vector_path,
        output_gpkg_path):
    vector = gdal.OpenEx(base_vector_path, gdal.OF_VECTOR)
    layer = vector.GetLayer()
    driver = gdal.GetDriverByName("GPKG")
    if os.path.exists(output_gpkg_path):
        os.remove(output_gpkg_path)
    output_vector = driver.Create(output_gpkg_path, 0, 0, 0, gdal.GDT_Unknown)
    output_layer = output_vector.CreateLayer(
        layer.GetName(), geom_type=layer.GetGeomType())
    layer_defn = layer.GetLayerDefn()
    for i in range(layer_defn.GetFieldCount()):
        field_defn = layer_defn.GetFieldDefn(i)
        output_layer.CreateField(field_defn)
    for peat_type_str in RASTER_ID_TO_TYPE.values():
        new_field = ogr.FieldDefn(peat_type_str, ogr.OFTReal)
        output_layer.CreateField(new_field)

    output_layer.ResetReading()
    layer.ResetReading()
    for feature in layer:
        output_feature = ogr.Feature(output_layer.GetLayerDefn())
        output_feature.SetFrom(feature)
        feature_name = feature.GetField('Scape')
        for peat_type_id, area_ha in area_lookup_by_feature_by_type[feature_name].get().items():
            peat_type_str = RASTER_ID_TO_TYPE[peat_type_id]
            output_feature.SetField(str(peat_type_str), float(area_ha))
        output_layer.CreateFeature(output_feature)
        output_feature = None
        feature = None

    output_layer = None
    output_vector = None
    layer = None
    vector = None


def main():
    """Entry point."""
    # Emily says to use this projection:
    epsg_8857 = osr.SpatialReference()
    epsg_8857.ImportFromEPSG(8857)
    epsg_8857_wkt = epsg_8857.ExportToWkt()
    vector_path = os.path.join(BASE_DATA_DIR, "Pilot_scapes")
    vector = gdal.OpenEx(vector_path, gdal.OF_VECTOR)
    layer = vector.GetLayer()
    task_graph = taskgraph.TaskGraph(
        '.', -1)#n_workers=layer.GetFeatureCount(),
        #reporting_interval=15)
    peat_coverage_area_by_feature_by_type = defaultdict(dict)

    for feature in layer:
        feature_bounding_box = feature.GetGeometryRef().GetEnvelope()
        # swizzle to get to xmin, ymin, xmax ymax
        feature_bounding_box = [
            feature_bounding_box[i] for i in [0, 2, 1, 3]]
        fid = feature.GetFID()
        feature_name = feature.GetField('Scape')
        target_raster_path = os.path.join(
            CLIPPED_DIR,
            f'{RASTER_BASE}_{feature_name}.tif')
        warp_task = task_graph.add_task(
            func=warp_raster_to_new_projection,
            args=(
                RASTER_PATH,
                feature_bounding_box,
                vector_path,
                fid,
                epsg_8857_wkt,
                TARGET_PIXEL_SIZE,
                target_raster_path),
            target_path_list=[target_raster_path],
            task_name=f'clip and warp {target_raster_path}')
        sum_task = task_graph.add_task(
            func=sum_area_types,
            args=(target_raster_path,),
            store_result=True,
            dependent_task_list=[warp_task],
            task_name=f'sum up {target_raster_path}')
        peat_coverage_area_by_feature_by_type[feature_name] = sum_task
        feature = None
    layer = None
    vector = None
    output_gpkg_path = os.path.join(
        OUTPUT_DIR,
        f'{os.path.basename(os.path.splitext(vector_path)[0])}_'
        f'{RASTER_BASE}.gpkg')
    add_coverage_area_to_features(
        peat_coverage_area_by_feature_by_type,
        vector_path,
        output_gpkg_path)
    task_graph.join()
    task_graph.close()


if __name__ == '__main__':
    main()
