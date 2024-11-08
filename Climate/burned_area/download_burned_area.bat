@echo off
set username=%1
set password=%2

wget --recursive --no-parent --no-directories --level=1 --accept hdf --user="%username%" --password="%password%" https://e4ftl01.cr.usgs.gov/MOTA/MCD64A1.061/
