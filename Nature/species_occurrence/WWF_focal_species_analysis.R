##This script identifies which of WWF's focal species exist in a defined spatial area and the number of species with reported occurences on an annual basis. Additional information can be viewed about specific focal species.

source("source.R")
library(sf)
library(dplyr)
library(ggplot2)
library(gridExtra)
library(ggspatial)
library(terra)
library(tidyr)

# Set variables
loc <- "Pantanal" #(options: Colombia, Madagascar, Pantanal, TRIDOM)
baseline <- 1999 #set to one year before baseline

# Read in common names
species_list <- read.csv("WWF Focal Species_11-19-2024.csv",header=TRUE)
common_names <- species_list %>% select(Common.Name,Scientific.Name)

# Load desired species and location information
if (loc == "Colombia"){
  loc_shp <- col_shp
} else if (loc == "Pantanal"){
  loc_shp <- pant_shp
} else if (loc == "Madagascar"){
  loc_shp <- mada_shp
} else if (loc == "TRIDOM"){
  loc_shp <- tri_shp
} else  loc_shp <- NULL

sp_shp <- st_read(paste0("clipped_data/",species,"_",loc,"_2024-11-21.shp"))

#filter data
sp_filt <- filter(sp_shp, year > baseline) %>%
  left_join(common_names, by=c("species" = "Scientific.Name"))

# Generate summary statistics
## Number of focal species sighted in the area
area <- as.data.frame(sp_filt) %>% 
  select(gbifID, species, indvdlC, eventDt, day, month, year, bssOfRc, mediTyp,Common.Name) %>%
  distinct()

sum_in_area <- n_distinct(area$species)

tot_in_area <- area %>% count(Common.Name,year)

table <- tot_in_area %>% spread(year,n)

# Visualize
## Annual occurence reports of focal species
plot <- ggplot(tot_in_area, aes(x=year, y=n)) +
  geom_point(aes(colour=factor(Common.Name)),size=3, alpha=0.75, position = position_jitter(width=0.2, height=0)) +
  scale_x_continuous(name="Year",limits=c(2000,2024),breaks=c(2000:2024)) +
  scale_y_continuous(name="Occurrences",limits=c(0,plyr::round_any(max(tot_in_area$n),5, f=ceiling))) +
  labs(colour="Species",
       caption = "Data source: GBIF") +
  theme_minimal() +
  theme(
    text = element_text(family="sans"),
    axis.text.x = element_text(angle=45, hjust=1),
    panel.border = element_rect(colour="darkgray",fill=NA,size=0.5),
    legend.text = element_text(face="italic"),
    axis.title.x = element_text(size="12"),
    axis.title.y = element_text(size="12"),
    plot.title = element_text(size="14", colour="#3d3a3a"),
    plot.subtitle = element_text(face="italic", colour="#3d3a3a"),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill="white"),
    plot.background = element_rect(fill="white")) +
  ggtitle("OCCURRENCES PER YEAR", subtitle = paste0("Total occurrence records: ", n_distinct(area$gbifID)))

## Map of focal species
map <- ggplot() +
  geom_sf(data = loc_shp, fill = NA, color = "darkblue", linewidth = 0.5) +
  geom_sf(data = sp_filt,
          aes(color = Common.Name),
          size = 2,
          alpha = 0.7) +
  scale_color_brewer(palette = "Set1") +
  annotation_scale(location = "bl") +
  annotation_north_arrow(location = "tr",
                         pad_x = unit(0.2, "in"),
                         pad_y = unit(0.2, "in")) +
  labs(title = paste0("DISTRIBUTION OF OCCURRENCE RECORDS OF WWF FOCAL SPECIES"),
       subtitle = paste("Total occurence records: ", n_distinct(sf_cropped$gbifID)),
       color = "Common.Name",
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
