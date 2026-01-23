# ------------------------------------------------------------------------------
# Prevalence of moderate or severe food insecurity in the population, based on 
# the Food Insecurity Experience Scale (FIES)
# Source: FAO FAOSTAT
# URL: https://www.fao.org/faostat/en/#data/FS
# Indicator: FIS_YYYY = Prevalence of food insecurity (%)
# Years: Variable by country
# Item Code: 210091 (total population, not gender-disaggregated)
# Output A: GeoPackage (countries layer with appended FIS_YYYY columns)
# Output B: Time-series figures for each country
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
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
# Load and process Food Insecurity data
# ------------------------------------------------------------------------------
FIS_raw <- read_csv("FAOSTAT_data_en_6-17-2025.csv", show_col_types = FALSE)

# Filter to:
# - Item Code 210091 (total population)
#   210091M = male, 210091F = female (not used here)
# - Element "Value" (percentage values)
# - Production countries
FIS_wide <- FIS_raw %>%
  filter(`Item Code` == 210091, Element == "Value") %>%
  rename(country = Area) %>%
  filter(country %in% country_names) %>%
  select(country, Value, Year) %>%
  pivot_wider(names_from = Year, values_from = Value, names_prefix = "FIS_")

# ------------------------------------------------------------------------------
# Join to shapefile and export GeoPackage
# ------------------------------------------------------------------------------
people_fis <- countries_sf %>%
  left_join(FIS_wide, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(people_fis, "FIS_Food_Insecurity_Prevalence.gpkg", 
         layer = "food_insecurity", delete_layer = TRUE, quiet = TRUE)

message("GeoPackage exported: FIS_Food_Insecurity_Prevalence.gpkg")

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
out_root <- "Figures/Food_Insecurity_Prevalence"
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

# Get all FIS columns
fis_cols <- names(people_fis)[str_starts(names(people_fis), "FIS_")]

# Reshape data to long format for plotting
long_data <- people_fis %>%
  st_drop_geometry() %>%
  select(COUNTRY, all_of(fis_cols)) %>%
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
      title = paste("Food Insecurity Prevalence in", country),
      x = "Year",
      y = "Food Insecurity Prevalence (%)"
    ) +
    theme_people_plot()
  
  # Save plot
  plot_path <- file.path(out_root, paste0(safe_name(country), "_FIS.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}

message("All figures saved to: ", out_root)

