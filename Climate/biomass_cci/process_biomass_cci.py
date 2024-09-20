"""Description of processing `biomass_cci_README.txt`."""
from collections import defaultdict
import glob
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
logging.getLogger('ecoshard.taskgraph').setLevel(logging.WARN)
logging.getLogger('ecoshard.geoprocessing').setLevel(logging.WARN)

BASE_DATA_DIR = '../data'
CLIPPED_DIR = 'clipped_rasters'
OUTPUT_DIR = 'output'

for dir_path in [CLIPPED_DIR, OUTPUT_DIR]:
    os.makedirs(dir_path, exist_ok=True)

TARGET_PIXEL_SIZE = (90, -90)  # I know those rasters are 90m
NODATA = 65535


def sum_biomass(biomass_raster):
    nodata = geoprocessing.get_raster_info(biomass_raster)['nodata'][0]
    biomass_array = gdal.OpenEx(biomass_raster).ReadAsArray().astype(float)
    valid_mask = biomass_array != nodata
    biomass_sum = np.sum(biomass_array[valid_mask])
    valid_pixel_count = float(np.sum(valid_mask))
    # raster units are t / hectare
    total_biomass_sum = (
        biomass_sum *
        valid_pixel_count *
        abs(numpy.multiply(*TARGET_PIXEL_SIZE)) / 1e4)

    biomass_array = None
    return total_biomass_sum


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


def add_biomass_sum_to_features(
        biomass_sum_lookup_by_year,
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
    for year in biomass_sum_lookup_by_year:
        analysis_id = f'biomass_t_sum_{year}'
        new_field = ogr.FieldDefn(analysis_id, ogr.OFTReal)
        output_layer.CreateField(new_field)

    output_layer.ResetReading()
    for feature in layer:
        output_feature = ogr.Feature(output_layer.GetLayerDefn())
        output_feature.SetFrom(feature)
        for year, biomass_sum_by_feature_name in biomass_sum_lookup_by_year.items():
            analysis_id = f'biomass_t_sum_{year}'
            feature_name = feature.GetField('Scape')
            biomass_sum = biomass_sum_by_feature_name[feature_name]
            output_feature.SetField(str(analysis_id), float(biomass_sum.get()))
        output_layer.CreateFeature(output_feature)
        output_feature = None

    vector = None
    output_vector = None


def main():
    """Entry point."""
    # Emily says to use this projection:
    epsg_8857 = osr.SpatialReference()
    epsg_8857.ImportFromEPSG(8857)
    epsg_8857_wkt = epsg_8857.ExportToWkt()
    task_graph = taskgraph.TaskGraph('.', n_workers=os.cpu_count())
    vector_path = os.path.join(
        BASE_DATA_DIR, "Biomass_cci_geotiffs/Pilot_scapes")
    vector = gdal.OpenEx(vector_path, gdal.OF_VECTOR)
    layer = vector.GetLayer()
    biomass_sum_lookup_by_year = defaultdict(lambda: defaultdict(float))
    for raster_path in glob.glob('Biomass_cci_geotiffs/geotiff/*/*.vrt'):
        # the file format is YYYY.vrt
        year = os.path.basename(os.path.splitext(raster_path)[0])
        layer.ResetReading()
        for feature in layer:
            feature_bounding_box = feature.GetGeometryRef().GetEnvelope()
            # swizzle to get to xmin, ymin, xmax ymax
            feature_bounding_box = [
                feature_bounding_box[i] for i in [0, 2, 1, 3]]
            fid = feature.GetFID()
            feature_name = feature.GetField('Scape')
            target_raster_path = os.path.join(
                CLIPPED_DIR,
                f'biomass_cci_{os.path.basename(os.path.splitext(raster_path)[0])}_'
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
                func=sum_biomass,
                args=(target_raster_path,),
                store_result=True,
                dependent_task_list=[warp_task],
                task_name=f'sum up {target_raster_path}')
            biomass_sum_lookup_by_year[year][feature_name] = sum_task

    task_graph.join()
    output_gpkg_path = f'{os.path.basename(os.path.splitext(vector_path)[0])}_biomass_cci.gpkg'
    add_biomass_sum_to_features(
        biomass_sum_lookup_by_year,
        vector_path,
        output_gpkg_path)
    task_graph.close()


if __name__ == '__main__':
    main()
