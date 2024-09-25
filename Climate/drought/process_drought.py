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
logging.getLogger('ecoshard.taskgraph').setLevel(logging.INFO)
logging.getLogger('ecoshard.geoprocessing').setLevel(logging.WARN)

BASE_RASTER_PATH = './geotiff_1990_2022/scPDSI.cru_ts4.07early1.1990_2022.GLOBAL.IGBP.WHC.1901.2022_from_nc.tif'
BASE_VECTOR_PATH = '../../data/Pilot_scapes'
CLIPPED_DIR = 'clipped_rasters'
OUTPUT_DIR = 'output'

for dir_path in [CLIPPED_DIR, OUTPUT_DIR]:
    os.makedirs(dir_path, exist_ok=True)

TARGET_PIXEL_SIZE = (55e3, -55e3)  # I know those rasters are half a degree resolution
NODATA = -9999


def min_max_median(base_raster_path):
    raster = gdal.OpenEx(base_raster_path)
    band = raster.GetRasterBand(1)
    array = band.ReadAsArray()
    valid_values = array[array != NODATA]
    min_value = np.min(valid_values)
    max_value = np.max(valid_values)
    median_value = np.median(valid_values)
    return min_value, max_value, median_value


def warp_raster_to_new_projection(
        base_raster_path, band_id,
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
        gdal_warp_options=None, working_dir='.',
        band_id=band_id)
    target_raster = gdal.OpenEx(target_raster_path, gdal.GA_Update)
    target_band = target_raster.GetRasterBand(1)
    target_band.SetNoDataValue(NODATA)
    target_band = None
    target_raster = None


def add_drought_stats_features(
        stats_lookup_by_year_month,
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
    for year_month in stats_lookup_by_year_month:
        for stat_id in ['min', 'max', 'median']:
            analysis_id = f'scpdsi_{year_month}_{stat_id}'
            new_field = ogr.FieldDefn(analysis_id, ogr.OFTReal)
            output_layer.CreateField(new_field)
    output_layer.ResetReading()

    for feature in layer:
        output_feature = ogr.Feature(output_layer.GetLayerDefn())
        output_feature.SetFrom(feature)
        for year_month, stats_lookup_by_feature_name in stats_lookup_by_year_month.items():
            feature_name = feature.GetField('Scape')
            for stat_value, stat_id in zip(
                    stats_lookup_by_feature_name[feature_name].get(),
                    ['min', 'max', 'median']):
                analysis_id = f'scpdsi_{year_month}_{stat_id}'
                output_feature.SetField(str(analysis_id), float(stat_value))
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
    task_graph = taskgraph.TaskGraph('.', n_workers=os.cpu_count(), reporting_interval=15)
    vector = gdal.OpenEx(BASE_VECTOR_PATH, gdal.OF_VECTOR)
    layer = vector.GetLayer()

    year_month_list = [
        f'{year}_{month}' for year in range(1990, 2023) for month in range(1, 13)]
    stats_lookup_by_year_month = defaultdict(dict)
    for band_offset, year_month in enumerate(year_month_list):
        layer.ResetReading()
        for feature in layer:
            feature_bounding_box = feature.GetGeometryRef().GetEnvelope()
            feature_bounding_box = [
                feature_bounding_box[i] for i in [0, 2, 1, 3]]
            fid = feature.GetFID()
            feature_name = feature.GetField('Scape')
            target_raster_path = os.path.join(
                CLIPPED_DIR,
                f'scPDSI_{year_month}_'
                f'{feature_name}.tif').replace(' ', '_')
            warp_task = task_graph.add_task(
                func=warp_raster_to_new_projection,
                args=(
                    BASE_RASTER_PATH,
                    band_offset + 1,  # band IDs are the offset + 1
                    feature_bounding_box,
                    BASE_VECTOR_PATH,
                    fid,
                    epsg_8857_wkt,
                    TARGET_PIXEL_SIZE,
                    target_raster_path),
                target_path_list=[target_raster_path],
                task_name=f'clip and warp {target_raster_path}')

            stats_task = task_graph.add_task(
                func=min_max_median,
                args=(target_raster_path,),
                dependent_task_list=[warp_task],
                task_name=f'stats for {feature_name} {year_month}',
                store_result=True)
            stats_lookup_by_year_month[year_month][feature_name] = stats_task

    output_gpkg_path = 'scpdsi.gpkg'
    add_drought_stats_features(
        stats_lookup_by_year_month,
        BASE_VECTOR_PATH,
        output_gpkg_path)
    task_graph.join()
    task_graph.close()


if __name__ == '__main__':
    main()
