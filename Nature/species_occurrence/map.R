##This script analyses retrieved GBIF species occurrence data to calculate change in occurrence records on an annual basis within a defined spatial area. It provides two outputs - 

source("source.R")
library(ggplot2)
library(gridExtra)
library(ggspatial)
library(terra)

##Set variables
loc <- "Madagascar" #(options: Colombia, Madagascar, Pantanal, TRIDOM)
species <- "turtles" #(options: riverdolphin, jaguar, turtles)
baseline <- 1999 #Set baseline year to desired baseline year - 1

##Load desired species and location information
# if (loc == "Colombia"){
#   loc_shp <- col_shp
# } else if (loc == "Pantanal"){
#   loc_shp <- pant_shp
# } else if (loc == "Madagascar"){
#   loc_shp <- mada_shp
# } else if (loc == "TRIDOM"){
#   loc_shp <- tri_shp
# } else  loc_shp <- NULL

sp_shp <- st_read(paste0("clipped_data/",species,"_",loc,"_2024-11-13.shp"))
sp_table <- as.data.frame(readRDS(paste0("clipped_data/",species,"_",loc,"_2024-11-14.rds")))

#Set baseline
sp_table <- filter(sp_table, year > baseline)
sp_shp <- filter(sp_shp, year > baseline)

##Set base map
# library(geojsonio)
# spdf <- geojson_read("boundaries/custom.geo.json", what="sp")
# spdf_fortified <- sf::st_as_sf(spdf, region="iso_a3")

#map by species
map <- ggplot() +
  geom_sf(data = loc_shp, fill = NA, color = "darkblue", linewidth = 0.5) +
  geom_sf(data = sp_shp,
          aes(color = species),
          size = 2,
          alpha = 0.7) +
  scale_color_brewer(palette = "Set1") +
  annotation_scale(location = "bl") +
  annotation_north_arrow(location = "tr",
                         pad_x = unit(0.2, "in"),
                         pad_y = unit(0.2, "in")) +
  labs(title = paste0("DISTRIBUTION OF ",toupper(species)," OCCURRENCE RECORDS"),
       subtitle = paste("Total occurence records: ", n_distinct(sp_shp$gbifID)),
       color = "Species",
       caption = "Data source: GBIF") +
  theme_minimal() +
  theme(
    legend.position = "right",
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.title = element_text(face = "bold"),
    axis.title = element_text(size = 10)
  )
# Save figures
ggsave(paste0("figures/map_",species,"_",loc,"_",Sys.Date(),".png"), 
       map,
       dpi = 300)
