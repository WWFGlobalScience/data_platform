"""Description of processing `biomass_cci_README.txt`."""
import sys
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


def sum_area(mask_raster):
    mask_array = gdal.OpenEx(mask_raster).ReadAsArray().astype(float)
    pixel_count = np.sum(mask_array > 0).astype(float)
    total_area_ha = (
        pixel_count *
        abs(numpy.multiply(*TARGET_PIXEL_SIZE)) / 1e4)

    mask_array = None
    return total_area_ha


def warp_raster_to_new_projection(
        base_raster_path,
        target_bounding_box,
        clipping_vector_path,
        clipping_vector_fid,
        target_projection_wkt,
        target_pixel_size,
        target_raster_path):
    vector_info = geoprocessing.get_vector_info(clipping_vector_path)
    projected_target_bounding_box = geoprocessing.transform_bounding_box(
        target_bounding_box,
        vector_info['projection_wkt'],
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


def burned_area_ha_to_features(
        burned_area_ha_lookup_by_year_mm_dd,
        base_vector_path,
        output_gpkg_path):
    try:
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
        for yyyy_mm_dd in burned_area_ha_lookup_by_year_mm_dd:
            analysis_id = f'burned_area_ha_{yyyy_mm_dd}'
            new_field = ogr.FieldDefn(analysis_id, ogr.OFTReal)
            output_layer.CreateField(new_field)

        output_layer.ResetReading()
        for feature in layer:
            print(feature)
            output_feature = ogr.Feature(output_layer.GetLayerDefn())
            output_feature.SetFrom(feature)
            for yyyy_mm_dd, biomass_sum_by_feature_name in burned_area_ha_lookup_by_year_mm_dd.items():
                analysis_id = f'burned_area_ha_{yyyy_mm_dd}'
                feature_name = feature.GetField('Scape')
                area_sum_task = biomass_sum_by_feature_name[feature_name]
                area_sum = area_sum_task.get()
                print(f'{yyyy_mm_dd} {feature_name} {area_sum}')
                output_feature.SetField(str(analysis_id), float(area_sum))
            print(f'creating {output_feature}')
            output_layer.CreateFeature(output_feature)
            output_feature = None

        vector = None
        output_vector = None
    except Exception as e:
        print(f'{e}')
    finally:
        print('all done')


def main():
    """Entry point."""
    # Emily says to use this projection:
    epsg_8857 = osr.SpatialReference()
    epsg_8857.ImportFromEPSG(8857)
    epsg_8857_wkt = epsg_8857.ExportToWkt()
    task_graph = taskgraph.TaskGraph('.', n_workers=os.cpu_count())
    vector_path = "../../data/Pilot_scapes"
    vector = gdal.OpenEx(vector_path, gdal.OF_VECTOR)
    layer = vector.GetLayer()
    burned_area_ha_lookup_by_year_mm_dd = defaultdict(lambda: defaultdict(float))
    for raster_path in glob.glob('burned_area/*.tif'):
        print(raster_path)
        # the file format is YYYY.mm.dd.tif
        yyyy_mm_dd = os.path.basename(os.path.splitext(raster_path)[0])
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
                f'burned_area_{os.path.basename(os.path.splitext(raster_path)[0])}_'
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
                func=sum_area,
                args=(target_raster_path,),
                store_result=True,
                dependent_task_list=[warp_task],
                task_name=f'sum up {target_raster_path}')
            burned_area_ha_lookup_by_year_mm_dd[yyyy_mm_dd][feature_name] = sum_task

    output_gpkg_path = f'{os.path.basename(os.path.splitext(vector_path)[0])}_burned_area_ha.gpkg'
    print('process features')
    burned_area_ha_to_features(
        burned_area_ha_lookup_by_year_mm_dd,
        vector_path,
        output_gpkg_path)
    task_graph.close()


if __name__ == '__main__':
    main()
