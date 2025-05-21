library(sf)
library(dplyr)
library(ggplot2)
library(lubridate)
library(scatterpie)
library(plotly) # For interactive plots
library(htmlwidgets) # To save interactive plots as HTML

Scapes <- st_read(dsn = "ESSFUseCase/ESSFUseCase.gdb", layer = "Prod_scapes_EE")
print(st_crs(Scapes))
plot(st_geometry(Scapes), main = "Scape")

flood_Sf <- st_read(dsn = "FloodData/FloodData.gdb", layer = "FloodArchive_region__Project")
plot(st_geometry(flood_Sf),main = "Flood Events")
print(st_crs(flood_Sf))

# Check CRS of both layers
crs_landscape <- st_crs(Scapes)
crs_flood <- st_crs(flood_Sf)

print(paste("Landscape CRS:", crs_landscape$input))
print(paste("Flood Data CRS:", crs_flood$input))

scape_sf <- st_make_valid(Scapes)
flood_sf <- st_make_valid(flood_Sf)

#Clip the flood data to the landscape
Scapes_flood <- st_intersection(flood_sf,scape_sf)

# Prepare data for plotting: drop geometry, convert types, handle dates
plot_data <- Scapes_flood %>%
  st_drop_geometry() %>% # We don't need spatial geometry for the timeline plot itself
  as_tibble() %>%
  mutate(
    # Ensure BEGAN is a date object. Adjust parsing as needed.
    # Common formats: ymd_hms, ymd. Check class(Scapes_flood$BEGAN)
    BEGAN_Date = as_date(BEGAN),
    # Ensure the area column is numeric. Coerce and warn if NAs are introduced.
    Plot_Size_Variable = as.numeric(Area_ha),
    # Ensure the cause column is a factor for discrete coloring
    Plot_Color_Variable = as.factor(CAUSE),
    # Ensure other numeric columns are numeric
    DEAD = as.numeric(DEAD),
    DISPLACED = as.numeric(DISPLACED),
    Total_Affected = as.numeric(DEAD+DISPLACED),
    # SEVERITY might be numeric or categorical, adjust as needed:
    SEVERITY = as.factor(SEVERITY),
    Plot_Radius = sqrt(Total_Affected),
    y= 0
  ) %>%
  filter(!is.na(BEGAN_Date)& (DEAD > 0 | DISPLACED > 0)) # Remove rows with no date or no affected people for pie slices

unique_scapes <- unique(plot_data$Name)


output_dir <- "FloodData_Plots"  

#Create plot
for (OPScape in unique_scapes){
  
  message(paste("\n---Processing Scape:",OPScape,"----"))
  
  scape_specific_data <- plot_data %>%
    filter(Name == OPScape)
  
  timeline_plot <- ggplot(scape_specific_data) +
    geom_scatterpie(
      aes(x = BEGAN_Date, y = y, r = Plot_Radius, color = Plot_Color_Variable),
      # Correctly specify 'cols' outside aes() as a character vector of column names
      cols = c("DEAD", "DISPLACED"),
      alpha = 0.15) +coord_equal()+
    theme_minimal(base_size = 11) +
    labs(
      title = paste("",OPScape), # Improved title
      x = "Year",
      y = "",
      fill = "Affected" # Legend title for pie slices (DEAD, DISPLACED)
    ) +
    scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
    theme(axis.text.y=element_blank(),
          axis.ticks.y = element_blank(),
          axis.line.y = element_blank(),
          legend.position = "bottom")+
    # Optional: customize colors for pie slices if needed
    #scale_fill_manual(values = c("DEAD" = "red", "DISPLACED" = "blue")) +
    guides(color = guide_legend(title = "Main Cause"), # Legend title for border color
           size = guide_legend(title = "Radius (Total Affected scaled)")) # Legend for radius if r is mapped

  print(timeline_plot)
  
  # Sanitize scape name for filename
  sane_scape_name <- gsub("[^a-zA-Z0-9_.-]", "_", OPScape)
  plot_filename <- file.path(output_dir, paste0("timeline_", sane_scape_name, ".png"))
  
  ggsave(filename = plot_filename, plot = timeline_plot, width = 12, height = 7, dpi = 300)
  message(paste("Saved plot:", plot_filename))
  
}


