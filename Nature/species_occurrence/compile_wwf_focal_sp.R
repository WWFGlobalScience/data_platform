##Generate compiled file for all WWF focal species

library(sf)
library(dplyr)
library(stringr)
library(purrr)

# Read in any existing species information
shp_files <- list.files(path = "processed_data/current_wwf", pattern = "*.shp$", full.names=TRUE)
rds_files <- list.files(path = "processed_data/current_wwf", pattern = "*.rds$", full.names=TRUE)

shp_names <- str_replace_all(shp_files,"_occurrences_\\d+-\\d+-\\d+\\.shp$","_shp")
shp_names <- str_replace_all(shp_names,"processed_data/current_wwf/","")

rds_names <- str_replace_all(rds_files,"_occurrences_\\d+-\\d+-\\d+\\.rds$","_rds")
rds_names <- str_replace_all(rds_names,"processed_data/current_wwf/","")

dat_shp <- list()

for (x in unique(shp_files)){
  dat_shp[[x]] <- st_read(x)
}

dat_shp <- dat_shp %>% set_names(shp_names)

dat_rds <- list()

for (x in unique(rds_files)){
  dat_rds[[x]] <- as.data.frame(readRDS(x))
}

dat_rds <- dat_rds %>% set_names(rds_names)

all_wwf_rds <- data.frame(data.table::rbindlist(dat_rds, fill=TRUE))
all_wwf <- sf::st_as_sf(data.table::rbindlist(dat_shp))

#Save full species shapefile
st_write(all_wwf, paste0("processed_data/current_wwf/allspecies_occurrences_",Sys.Date(),".shp"))
# Save the full species data to a RDS file
saveRDS(all_wwf_rds, paste0("processed_data/current_wwf/allspecies_occurrences_",Sys.Date(),".rds"))
