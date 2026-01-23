# ------------------------------------------------------------------------------
# Perceived levels of public sector corruption at the national scale
# Source: Transparency International
# URL: https://www.transparency.org/en/cpi
# Indicator: CPI_YYYY = Corruption Perceptions Index score (0-100)
# Years: 2012-2024
# Scale: 0 = highly corrupt; 100 = very clean
# Output A: GeoPackage (countries layer with appended CPI_YYYY columns)
# Output B: Time-series figures for each country
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(janitor)
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
# Load and process Corruption Perceptions Index data
# ------------------------------------------------------------------------------
# Note: Skip first row which contains header info
cpi_raw <- read_excel("CPI2024-Results-and-trends.xlsx", 
                      sheet = "CPI Timeseries 2012 - 2024", 
                      skip = 1)

# Clean column names and rename country column
cpi_clean <- cpi_raw %>%
  clean_names() %>%
  rename(country = country_territory)

# Filter to production countries only
cpi_filtered <- cpi_clean %>%
  filter(country %in% country_names)

# Reshape to long format for visualization
cpi_long <- cpi_filtered %>%
  select(country, iso3, starts_with("cpi_score_")) %>%
  pivot_longer(
    cols = starts_with("cpi_score_"),
    names_to = "year",
    names_prefix = "cpi_score_",
    values_to = "cpi_score"
  ) %>%
  mutate(year = as.integer(year)) %>%
  arrange(country, year)

# Reshape to wide format for GeoPackage join
cpi_wide <- cpi_long %>%
  pivot_wider(names_from = year, values_from = cpi_score, names_prefix = "CPI_")

# ------------------------------------------------------------------------------
# Join to shapefile and export GeoPackage
# ------------------------------------------------------------------------------
governance_cpi <- countries_sf %>%
  left_join(cpi_wide, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(governance_cpi, "CPI_Corruption_Perceptions_Index.gpkg", 
         layer = "corruption_index", delete_layer = TRUE, quiet = TRUE)

message("GeoPackage exported: CPI_Corruption_Perceptions_Index.gpkg")

# ------------------------------------------------------------------------------
# FIGURES: Time-series plots for each country
# ------------------------------------------------------------------------------

# Setup custom theme with Google Fonts
font_add_google("Open Sans", "opensans")
showtext_auto()

theme_governance_plot <- function() {
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
out_root <- "Figures/Corruption_Perceptions_Index"
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

# Use long format data for plotting
plot_data <- cpi_long %>%
  drop_na(cpi_score)

# Generate a plot for each country
for (country in unique(plot_data$country)) {
  
  df_sub <- plot_data %>% filter(country == !!country)
  
  # Skip if fewer than 2 observations
  if (nrow(df_sub) < 2) next
  
  # Use actual years present in the data for x-axis breaks
  year_breaks <- sort(unique(as.numeric(df_sub$year)))
  
  p <- ggplot(df_sub, aes(x = as.numeric(year), y = cpi_score)) +
    geom_line(color = "#728423", linewidth = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    scale_x_continuous(
      breaks = year_breaks,
      labels = function(x) sprintf("%04d", x)
    ) +
    labs(
      title = paste("Corruption Perceptions Index in", country),
      x = "Year",
      y = "CPI Score (0–100)"
    ) +
    theme_governance_plot()
  
  # Save plot
  plot_path <- file.path(out_root, paste0(safe_name(country), "_CPI.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}

message("All figures saved to: ", out_root)
