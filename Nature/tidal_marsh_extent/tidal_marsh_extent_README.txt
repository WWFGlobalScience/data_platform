1) Saltmarsh data downloaded from "TidalRasterV2" from Mabel's drive https://worldwildlifefund-my.sharepoint.com/personal/mabel_baezschon_wwfus_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fmabel%5Fbaezschon%5Fwwfus%5Forg%2FDocuments%2FDesktop%2FData%20Platform%2FTidalRasterV2&ct=1726856849700&or=Teams%2DHL&ga=1&LOF=1
  * while this raster is in WGS84, the underlying pixels are 10x10m.
  * Units are "0" not present and "1" present

2) Rasters then clipped by year to `Pilot_scapes` and projected into `EPSG:8857` (equal world area projection)

3) Total salt marsh coverage is as (sum of clipped saltmarsh pixels * 100m^2)
