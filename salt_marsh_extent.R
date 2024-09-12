setwd("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Final_Rasters")

# Load required libraries
library(raster)
library(sf)
library(exactextractr)
library(tidyverse)
library(rgdal)##need newer r version


####READ IN TIF FILES ######
#directory to tiff files
raster_dir<- "C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Final_Rasters"
# Get list of TIF files in the directory
tif_files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)
  
#import all raster files in folder using lapply
raster_list <- lapply(tif_files, raster)

#test if it worked
plot(raster_list[[1]]) #yes
raster_list[[1]]#YES
summary(raster_list[[1]])
lapply(raster_list, summary) #checking to see the raster values should only be one
#one raster has 1 as the scientific notion ?? double check it doesnt ruin calculations $tidal_marsh_80W_50N_v2_6
#tidal_marsh_80W_50N_v2_6

# Name each raster in the list with its filename (without extension)
 names(raster_list) <- tools::file_path_sans_ext(basename(tif_files))


## Load country boundaries
#ADM0 is country downloaded from GADM version 4.1
 #note that they dont have ISO code 
countries <- st_read("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/gadm_410-gpkg/gadm_410.gpkg")

#code example to extract countries of interest 
#pilot_countries<- adm0[which(
#adm0$NAME_0=="Zimbabwe" | adm0$NAME_0=="Zambia" | 
 # adm0$NAME_0=="Western Sahara" | adm0$NAME_0=="Uganda" | 
  #adm0$NAME_0=="Algeria"
#),]

## or another code
#pilot_countries <- countries %>%
 # filter(NAME_0 %in% c("Zimbabwe", "Zambia", "Western Sahara", "Uganda", "Algeria")) %>%
 # select(NAME_0, GID_0) 

## Load the 5 specific places
pilots <- st_read("xxxxxx.shp")

# Combine pilot countries and pilots into a single sf object for clipping b/c the rasters are large so this saves space
areas_of_interest <- rbind(
  pilot_countries %>% mutate(type = "country"),
  pilots %>% mutate(type = "pilot", GID_0 = NA_character_) %>% select(NAME_0 = NAME, GID_0, type) #mbs GID_0 = NA_character_ bc pilots dont have that
)

# Function to clip and mask raster
clip_raster <- function(raster, areas) {
  clipped <- crop(raster, areas)
  masked <- mask(clipped, areas)
  return(masked)
}

# Clip all rasters to countries AND pilots
clipped_rasters <- map(raster_list, ~clip_raster(.x, areas_of_interest))


#### FUNCTION TO calculate the extent from the RASTERS ##### please double check my thinking is right here
process_raster <- function(raster, areas) {
  # Calculate area for each area of interest
  stats <- exact_extract(raster, areas, fun = function(values, coverage_fraction) {
    sum(values == 1, na.rm = TRUE) * 100  # Each value close to 1 represents 100m² of tidal marsh extent
  })
  # if the one raster thats funky gives us toruble use this  sum(abs(values - 1) < 1e-6, na.rm = TRUE)
  
  # Convert area to km2
  stats <- stats / 1e6  # Convert m2 to km2
  
  return(stats)
}

#apply function for extent all clipped raster files
results <- map(clipped_rasters, ~process_raster(.x, areas_of_interest)) %>%
  do.call(cbind, .)
colnames(results) <- names(raster_list)

# Add results to dataframe
areas_of_interest <- cbind(areas_of_interest, results)

# Calculate total area across all rasters
areas_of_interest$total_area <- rowSums(results, na.rm = TRUE)

# Split results back into countries and pilots ##if this doesnt run take it away its splitting things back itno coutnry and shp
pilot_countries_results <- areas_of_interest %>% 
  filter(type == "country") %>%
  select(-type)

pilots_results <- areas_of_interest %>% 
  filter(type == "pilot") %>%
  select(-type, -GID_0) %>%
  rename(NAME = NAME_0)

# Print results
print("Pilot Countries:")
print(pilot_countries_results %>% st_drop_geometry() %>% select(NAME_0, GID_0, total_area)) ###st_drop_geometry is to turn it from shp to csv if this doesnt work then do the longer version which is I think st>drop_geometry and as.dataframe 

print("Pilot Areas:")
print(pilots_results %>% st_drop_geometry() %>% select(NAME, total_area))

# Save results to CSV files
write.csv(pilot_countries_results %>% st_drop_geometry() %>% select(NAME_0, GID_0, total_area, everything()), 
          "country_tidal_marsh_extent.csv", row.names = FALSE)

write.csv(pilots_results %>% st_drop_geometry() %>% select(NAME, total_area, everything()), 
          "pilot_tidal_marsh_extent.csv", row.names = FALSE)

###unsure if this will work but to turn into shp do I need driver= ?
# For pilot countries
st_write(pilot_countries_results, "pilot_tidal_marsh_extent.shp", driver = "ESRI Shapefile")

# For pilot areas
st_write(pilots_results, "country_tidal_marsh_extent.shp", driver = "ESRI Shapefile")