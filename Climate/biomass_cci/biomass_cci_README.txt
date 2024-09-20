1) Aboveground biomass data downloaded from `https://data.ceda.ac.uk/neodc/esacci/biomass/data/agb/maps/v5.0/geotiff` with this command: `echo https://dap.ceda.ac.uk/neodc/esacci/biomass/data/agb/maps/v5.0/geotiff/{2010/,2015/,2016/,2017/,2018/,2019/,2020/,2021/} | \
  tr ' ' '\n' | xargs -n 1 -P 8 wget -e robots=off --mirror --no-parent -r`
 * Note: Units of these raster are biomass metric tons per hectare

2) Rasters then clipped by year to `Pilot_scapes` and projected into `EPSG:8857` (equal world area projection)

3) Total biomass is calculated as (sum of clipped biomass * area of valid pixels in hectares)
