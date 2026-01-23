# ------------------------------------------------------------------------------
# Proportion and number of children aged 5-17 years engaged in child labour, 
# by sex and age
# Source: UNICEF Data Portal
# URL: https://data.unicef.org/topic/child-protection/child-labour/
# Indicator: CL_YYYY = Proportion of children aged 5-17 engaged in child labour (%)
# Years: 2014-2022 (single timestep per country, varying collection years)
# Note: Data typically reported once per country with varying collection years
# Output A: GeoPackage (countries layer with appended CL_YYYY columns)
# Output B: Time-series figures for each country (if multiple years available)
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
# Load and process Child Labour data
# ------------------------------------------------------------------------------
CHILD_LABOUR_raw <- read_csv(
  "fusion_GLOBAL_DATAFLOW_UNICEF_1.0_.PT_CHLD_5-17_LBR_ECON._T.csv", 
  show_col_types = FALSE
)

# Parse geographic area to extract country name
# Format is typically "CODE: Country Name"
CHILD_LABOUR_wide <- CHILD_LABOUR_raw %>%
  separate(`REF_AREA:Geographic area`, 
           into = c("code", "country"), 
           sep = ": ", 
           remove = FALSE) %>%
  select(country, 
         year = 'TIME_PERIOD:Time period', 
         value = 'OBS_VALUE:Observation Value') %>%
  filter(country %in% country_names) %>%
  pivot_wider(names_from = year, values_from = value, names_prefix = "CL_")

# ------------------------------------------------------------------------------
# Join to shapefile and export GeoPackage
# ------------------------------------------------------------------------------
people_cl <- countries_sf %>%
  left_join(CHILD_LABOUR_wide, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(people_cl, "CL_Child_Labour_Prevalence.gpkg", 
         layer = "child_labour", delete_layer = TRUE, quiet = TRUE)

message("GeoPackage exported: CL_Child_Labour_Prevalence.gpkg")

# ------------------------------------------------------------------------------
# FIGURES: Time-series plots for each country (if applicable)
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
out_root <- "Figures/Child_Labour_Prevalence"
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

# Get all CL columns
cl_cols <- names(people_cl)[str_starts(names(people_cl), "CL_")]

# Reshape data to long format for plotting
long_data <- people_cl %>%
  st_drop_geometry() %>%
  select(COUNTRY, all_of(cl_cols)) %>%
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
      title = paste("Child Labour Prevalence in", country),
      x = "Year",
      y = "Child Labour Prevalence (%)"
    ) +
    theme_people_plot()
  
  # Save plot
  plot_path <- file.path(out_root, paste0(safe_name(country), "_CL.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}

message("All figures saved to: ", out_root)
message("Note: Most countries have single time-point data, so few time-series plots may be generated")