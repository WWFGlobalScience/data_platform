"""Description of processing `tidal_marsh_extent_README.txt`."""
from collections import defaultdict
import logging
import os

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
CLIPPED_DIR = 'clipped_rasters'
OUTPUT_DIR = 'output'

for dir_path in [CLIPPED_DIR, OUTPUT_DIR]:
    os.makedirs(dir_path, exist_ok=True)

# I know those rasters are 10m because Mabel told me the area was 100m^2
TARGET_PIXEL_SIZE = (10, -10)
NODATA = 2


def sum_salt_marsh(salt_marsh_raster_path):
    nodata = geoprocessing.get_raster_info(
        salt_marsh_raster_path)['nodata'][0]
    salt_marsh_array = gdal.OpenEx(
        salt_marsh_raster_path).ReadAsArray().astype(float)
    valid_mask = salt_marsh_array != nodata
    salt_marsh_valid_pixels = np.sum(salt_marsh_array[valid_mask])
    salt_marsh_array = None

    # raster units are categorical (1) present / (0) not present
    # / 1e4 to convert to hectares
    total_salt_marsh_valid_pixels = (
        salt_marsh_valid_pixels *
        abs(numpy.multiply(*TARGET_PIXEL_SIZE)) /
        1e4)
    return total_salt_marsh_valid_pixels


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
            'mask_vector_where_filter': f'id={clipping_vector_fid}',
            'target_mask_value': NODATA},
        gdal_warp_options=None, working_dir='.')
    target_raster = gdal.OpenEx(target_raster_path, gdal.GA_Update)
    target_band = target_raster.GetRasterBand(1)
    target_band.SetNoDataValue(NODATA)
    target_band = None
    target_raster = None


def add_sum_to_features(
        tidal_marsh_area_lookup_by_feature,
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
    analysis_id = 'tidal_marsh_area_ha'
    new_field = ogr.FieldDefn(analysis_id, ogr.OFTReal)
    output_layer.CreateField(new_field)

    output_layer.ResetReading()
    for feature in layer:
        output_feature = ogr.Feature(output_layer.GetLayerDefn())
        output_feature.SetFrom(feature)
        feature_name = feature.GetField('Scape')
        tidal_marsh_area = tidal_marsh_area_lookup_by_feature[feature_name]
        output_feature.SetField(str(analysis_id), float(tidal_marsh_area.get()))
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
        '.', n_workers=layer.GetFeatureCount(),
        reporting_interval=15)
    salt_marsh_lookup_by_feature = dict()
    raster_path = os.path.join(
        BASE_DATA_DIR, 'TidalRasterV2', 'TidalRasterV2.vrt')
    for feature in layer:
        feature_bounding_box = feature.GetGeometryRef().GetEnvelope()
        # swizzle to get to xmin, ymin, xmax ymax
        feature_bounding_box = [
            feature_bounding_box[i] for i in [0, 2, 1, 3]]
        fid = feature.GetFID()
        feature_name = feature.GetField('Scape')
        target_raster_path = os.path.join(
            CLIPPED_DIR,
            f'tidal_marsh_{os.path.basename(os.path.splitext(raster_path)[0])}_'
            f'{feature_name}.tif').replace(' ', '_')
        warp_task = task_graph.add_task(
            func=warp_raster_to_new_projection,
            args=(
                raster_path,
                feature_bounding_box,
                vector_path,
                fid,
                epsg_8857_wkt,
                TARGET_PIXEL_SIZE,
                target_raster_path),
            target_path_list=[target_raster_path],
            task_name=f'clip and warp {target_raster_path}')
        sum_task = task_graph.add_task(
            func=sum_salt_marsh,
            args=(target_raster_path,),
            store_result=True,
            dependent_task_list=[warp_task],
            task_name=f'sum up {target_raster_path}')
        salt_marsh_lookup_by_feature[feature_name] = sum_task
        feature = None
    layer = None
    vector = None
    task_graph.join()
    output_gpkg_path = os.path.join(
        OUTPUT_DIR,
        f'{os.path.basename(os.path.splitext(vector_path)[0])}_'
        'tidal_marsh.gpkg')
    add_sum_to_features(
        salt_marsh_lookup_by_feature,
        vector_path,
        output_gpkg_path)
    task_graph.close()


if __name__ == '__main__':
    main()
