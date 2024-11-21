##Read in WWF place boundaries (shapefiles)

library(sf)
library(dplyr)

pilot <- st_read("boundaries/Pilot_scapes/Pilot_scapes.shp")
mada_shp <- filter(pilot,Scape == "Madagascar Diana")
col_shp <- filter(pilot,Scape == "Colombian Amazon")
pant_shp <- filter(pilot,Scape == "Pantanal")
tri_shp <- filter(pilot,Scape == "TRIDOM")
