1) Peatland database downloaded from here: https://gee-community-catalog.org/projects/peatland/
  * unit of 1 means "peat dominated", 2 "peat in soil mosaic"
  * while this raster is in WGS84, the underlying pixels are 1k x 1k

2) Rasters then clipped by year to `Pilot_scapes` and projected into `EPSG:8857` (equal world area projection)

3) Total peat coverage in hectares the geopackage is calculated as (sum of clipped peatland pixels * 1km^2 / 1e4)
