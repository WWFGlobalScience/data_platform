"""Script is hardcoded for scPDSI.cru_ts4.07early1.1901.2022.cal_1901_22.bams.2023.GLOBAL.IGBP.WHC.1901.2022.nc to extract 1990-2022."""
import os

from rasterio.transform import Affine
import numpy
import pandas
import rasterio
import xarray


def main():
    """Entrypoint."""
    nc_path = "scPDSI.cru_ts4.07early1.1901.2022.cal_1901_22.bams.2023.GLOBAL.IGBP.WHC.1901.2022.nc"
    if not os.path.exists(nc_path):
        raise ValueError(
            f'expected {nc_path} but is not found in current directory, download it from '
            f'https://crudata.uea.ac.uk/cru/data/drought/scPDSI.cru_ts4.07early1.1901.2022.cal_1901_22.bams.2023.GLOBAL.IGBP.WHC.1901.2022.nc.gz')

    gdm_dataset = xarray.open_dataset(nc_path)
    basename = os.path.basename(os.path.splitext(nc_path)[0])

    xres = float((gdm_dataset.longitude[-1] - gdm_dataset.longitude[0]) / len(gdm_dataset.longitude))
    yres = float((gdm_dataset.latitude[-1] - gdm_dataset.latitude[0]) / len(gdm_dataset.latitude))
    transform = Affine.translation(
        gdm_dataset.longitude[0], gdm_dataset.latitude[0]) * Affine.scale(xres, yres)

    gdm_dataset = gdm_dataset.sel(
        time=pandas.date_range(start='1990-01-01', end='2022-12-31', freq='MS'))
    with rasterio.open(
        f"{basename}_from_nc.tif",
        mode="w",
        driver="GTiff",
        height=len(gdm_dataset.latitude),
        width=len(gdm_dataset.longitude),
        count=len(gdm_dataset.time),
        dtype=numpy.float32,
        nodata=0,
        crs="+proj=latlong",
        transform=transform,
        kwargs={
            'tiled': 'YES',
            'COMPRESS': 'LZW',
            'PREDICTOR': 2}) as new_dataset:
        print(gdm_dataset)
        print(len(gdm_dataset.time))
        for date_index in range(len(gdm_dataset.time)):
            data_key = next(iter(gdm_dataset.isel(time=date_index).data_vars))
            print(f'writing band {basename} {date_index} of {len(gdm_dataset.time)}')
            new_dataset.write(gdm_dataset.isel(time=date_index)[data_key], 1+date_index)


if __name__ == '__main__':
    main()
