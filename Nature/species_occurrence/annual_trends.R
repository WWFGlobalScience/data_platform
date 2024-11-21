##This script analyses retrieved GBIF species occurrence data to calculate change in occurrence records on an annual basis within a defined spatial area. It provides two outputs - 

source("source.R")
library(ggplot2)
library(gridExtra)
library(ggspatial)
library(terra)

##Set variables
loc <- "Madagascar" #(options: Colombia, Madagascar, Pantanal, TRIDOM)
species <- "turtles" #(options: riverdolphin, jaguar, turtles)
 
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
 
##Summarize table of number of occurrences per year
annual_occ <- sp_table %>% 
  select(gbifID,species,year,indvdlC) %>%
  distinct() %>%
  count(year,species)

occ_basis <- sp_table %>%
  select(gbifID,species,bssOfRc) %>%
  distinct() %>%
  count(bssOfRc,species) %>%
  group_by(species) %>%
  mutate(perc=n/sum(n)) %>%
  mutate(labels=scales::percent(perc))

occ_basis$bssOfRc <- gsub("_"," ",occ_basis$bssOfRc)

occ_basis <- occ_basis %>%
  mutate(bssOfRc = stringr::str_to_title(bssOfRc))

##Get positions for labels with lines
# label_df <- occ_basis %>%
#   mutate(csum = rev(cumsum(rev(n))),
#          pos = n/2 + lead(csum,1),
#          pos = if_else(is.na(pos), n/2, pos))

##Plot # of occurrences per year
plot1 <- ggplot(annual_occ, aes(x=year, y=n)) +
  geom_point(aes(colour=factor(species)),size=3, alpha=0.75, position = position_jitter(width=0.2, height=0)) +
  scale_x_continuous(name="Year",limits=c(2000,2024),breaks=c(2000:2024)) +
  scale_y_continuous(name="Occurrences",limits=c(0,plyr::round_any(max(annual_occ$n),10, f=ceiling))) +
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
  ggtitle("OCCURRENCES PER YEAR", subtitle = paste0("Total occurrence records: ", n_distinct(sp_table$gbifID)))

##Plot # of occurrences per basis of record
plot2 <- ggplot(occ_basis, aes(x="",y=perc,fill=bssOfRc)) +
  geom_col(color="darkgray") +
  geom_label(aes(label=labels),
            position=position_stack(vjust=0.5),
            show.legend = FALSE) +
  coord_polar(theta="y") +
  scale_fill_brewer() +
  labs(fill="Basis of record",
       caption = "Data source: GBIF") +
  theme_void() +
  facet_grid(.~species, switch="both") +
  theme(
    text = element_text(family="sans"),
    legend.title = element_text(size="12"),
    legend.text = element_text(size="10"),
    plot.title = element_text(size="14", colour="#3d3a3a"),
    plot.subtitle = element_text(face="italic", colour="#3d3a3a"),
    strip.text.x = element_text(size="12",face="italic",vjust=1),
    panel.background = element_rect(fill="white",colour="white"),
    plot.background = element_rect(fill="white",colour="white"),
    plot.margin = margin(5,5,20,5)) +
  ggtitle ("OCCURRENCES PER BASIS OF RECORD", subtitle = paste0("Total occurrence records: ", n_distinct(sp_table$gbifID)))

# Save figures
ggsave(paste0("figures/annual_trend_",species,"_",loc,"_",Sys.Date(),".png"), 
       plot1,
       dpi = 300)

ggsave(paste0("figures/basisofrecord_",species,"_",loc,"_",Sys.Date(),".png"), 
       plot2,
       dpi = 300)

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
