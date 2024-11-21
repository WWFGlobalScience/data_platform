source("source.R")
library(rgbif)
library(sf)
library(dplyr)

pilot <- st_read("~/Downloads/Pilot_scapes/Pilot_scapes.shp")

# Set variables
loc <- "Madagascar" #(options: Colombia, Madagascar, Pantanal, TRIDOM)
species <- "allspecies" #(options: riverdolphin, jaguar, turtles)

##Load desired species and location information
if (loc == "Colombia"){
  loc_shp <- col_shp
} else if (loc == "Pantanal"){
  loc_shp <- pant_shp
} else if (loc == "Madagascar"){
  loc_shp <- mada_shp
} else if (loc == "TRIDOM"){
  loc_shp <- tri_shp
} else  loc_shp <- NULL

species_sf <- st_read(paste0("processed_data/current_wwf/",species,"_occurrences_2024-11-20.shp"))

#crop data
sf_cropped <- st_intersection(species_sf, loc_shp)

#Write to shape file
st_write(sf_cropped, paste0("clipped_data/",species,"_",loc,"_",Sys.Date(),".shp"))

#Write to attributes to RDS
saveRDS(sf_cropped, paste0("clipped_data/",species,"_",loc,"_",Sys.Date(),".rds"))
