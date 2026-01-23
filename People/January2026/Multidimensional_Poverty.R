# ------------------------------------------------------------------------------
# Proportion of men, women and children of all ages living in poverty in all 
# its dimensions (National)
# Source: UN Statistics Division (SDG Indicator 1.2.2)
# SD_MDP_MUHC - Proportion of population living in multidimensional poverty [1.2.2
# URL:https://unstats.un.org/sdgs/dataportal/database
# In the SDG data portal searhc for  Indicator 1.2.2, Series : Proportion of population living in multidimensional poverty (%) SD_MDP_MUHC
# Indicator: mpi_YYYY = Proportion of population living in multidimensional poverty
# Years: 2012-2021
# Note: Data availability per year per country is inconsistent
# Output A: GeoPackage (countries layer with appended mpi_YYYY columns)
# Output B: Time-series figures for each country
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(ggplot2)
library(showtext)
library(sysfonts)

# ------------------------------------------------------------------------------
# Load production countries shapefile
# ------------------------------------------------------------------------------
shp_path <- "Prod_countries_EE.shp"
countries_sf <- st_read(shp_path, quiet = TRUE)

# Extract unique country names for filtering
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% 
  unique()

# ------------------------------------------------------------------------------
# Load and process Multidimensional Poverty Index data
# ------------------------------------------------------------------------------
MPI_raw <- read_excel("poverty_data.xlsx", sheet = "Goal1")

# Filter to:
# - Production countries
# - SeriesCode SD_MDP_MUHC (multidimensional poverty)

# - All ages, all locations, both sexes
MPI_sub <- MPI_raw %>%
  filter(
    GeoAreaName %in% country_names, 
    SeriesCode == "SD_MDP_MUHC", 
    Age == "ALLAGE",
    Location == "ALLAREA", 
    Sex == "BOTHSEX"
  ) 

# Reshape to wide format with mpi_YYYY columns
MPI_wide <- MPI_sub %>%
  mutate(year = as.character(TimePeriod)) %>%
  select(country = GeoAreaName, year, Value) %>%
  pivot_wider(names_from = year, values_from = Value, names_prefix = "mpi_")

# ------------------------------------------------------------------------------
# Join to shapefile and export GeoPackage
# ------------------------------------------------------------------------------
people_mpi <- countries_sf %>%
  left_join(MPI_wide, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(people_mpi, "MPI_Multidimensional_Poverty.gpkg", 
         layer = "poverty_index", delete_layer = TRUE, quiet = TRUE)

message("GeoPackage exported: MPI_Multidimensional_Poverty.gpkg")

# ------------------------------------------------------------------------------
# FIGURES: Time-series plots for each country
# ------------------------------------------------------------------------------

# Setup custom theme with Google Fonts
font_add_google("Open Sans", "opensans")
showtext_auto()

theme_people_plot <- function() {
  theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.title.x = element_text(size = 13),
      axis.title.y = element_text(size = 13),
      axis.text = element_text(size = 12, color = "black"),
      axis.line = element_line(color = "black", linewidth = 0.4),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      plot.margin = margin(10, 10, 10, 10),
      legend.position = "none"
    )
}

# Helper function to create safe file names
safe_name <- function(x) gsub("[^a-zA-Z0-9]", "_", x)

# Create output directory
out_root <- "Figures/Multidimensional_Poverty_Index"
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

# Get all mpi columns
mpi_cols <- names(people_mpi)[str_starts(names(people_mpi), "mpi_")]

# Reshape data to long format for plotting
long_data <- people_mpi %>%
  st_drop_geometry() %>%
  select(COUNTRY, all_of(mpi_cols)) %>%
  pivot_longer(-COUNTRY, names_to = "year", values_to = "value") %>%
  mutate(
    COUNTRY = str_trim(COUNTRY),
    value   = suppressWarnings(as.numeric(value)),
    year    = suppressWarnings(as.numeric(str_extract(year, "\\d{4}")))
  ) %>%
  drop_na(year, value)

# Generate a plot for each country
for (country in unique(long_data$COUNTRY)) {
  
  df_sub <- long_data %>% filter(COUNTRY == country)
  
  # Skip if fewer than 2 observations
  if (nrow(df_sub) < 2) next
  
  # Use actual years present in the data for x-axis breaks
  year_breaks <- sort(unique(as.numeric(df_sub$year)))
  
  p <- ggplot(df_sub, aes(x = as.numeric(year), y = value)) +
    geom_line(color = "#728423", linewidth = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    scale_x_continuous(
      breaks = year_breaks,
      labels = function(x) sprintf("%04d", x)
    ) +
    labs(
      title = paste("Multidimensional poverty in population", country),
      x = "Year",
      y = "Population living in multidimensional poverty (%)"
    ) +
    theme_people_plot()
  
  # Save plot
  plot_path <- file.path(out_root, paste0(safe_name(country), "_MPI.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}

message("All figures saved to: ", out_root)
