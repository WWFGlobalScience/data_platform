Data all downlaoded from

https://data.ceda.ac.uk/neodc/esacci/biomass/data/agb/maps/v5.0/geotiff

with this command

echo https://dap.ceda.ac.uk/neodc/esacci/biomass/data/agb/maps/v5.0/geotiff/{2010/,2015/,2016/,2017/,2018/,2019/,2020/,2021/} | \
  tr ' ' '\n' | xargs -n 1 -P 8 wget -e robots=off --mirror --no-parent -r

Rasters then clipped by year to `Pilot_scapes` and projected into `EPSG:8857`



Project to EPSG:8857 (equal world area projection)