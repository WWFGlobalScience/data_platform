# ------------------------------------------------------------------------------
# RED LIST INDEX (RLI) MAPPING SCRIPT
# Author: [Your Name]
# Date: 2026-01-09
# Description: Joins RLI time series to country boundaries, saves as GeoPackage,
# and creates country-specific plots with World trend lines.
# Data Source: https://w3.unece.org/SDG/en/Indicator?id=69
#An RLI of 1 indicates that all species have a status of Least Concerned, while 0 indicates Extinct. If the RLI value is constant over time, the overall extinction risk remains unchanged. 
#An upward trend shows a reduction in the rate of biodiversity loss.
# --------------
# 📦 Load required libraries
library(tidyverse)
library(countrycode)
library(sf)
library(readxl)
library(ggplot2)

#set your working directory to the folder that contains both your place spatial data and the CSV downloaded

# ------------------------------------------------------------------------------
# STEP 1: Load spatial data
# ------------------------------------------------------------------------------

# Path to your cleaned EE shapefile with ISO3 codes
shapefile_path <- "YOUSHAPEFILE.shp" ##ADD SHAPEFILE PATH
countries_sf <- st_read(shapefile_path)

# Extract valid ISO3 codes from the shapefile for filtering later
shapefile_iso3 <- countries_sf %>%
  st_drop_geometry() %>%
  pull(ISO3) %>%
  unique()

# ------------------------------------------------------------------------------
# STEP 2: Load and clean RLI data (from 2nd tab of Excel file)
# ------------------------------------------------------------------------------

# Load RLI from Excel, sheet 2
RLI_data <- read_excel("RLI_2026.xlsx", sheet = 2)

# Convert GeoAreaCode to ISO3 (safest and most consistent way)
RLI_data <- RLI_data %>%
  mutate(ISO3 = case_when(
    GeoAreaCode == 1 ~ "WLD",  # Add "World" manually if needed
    TRUE ~ countrycode(GeoAreaCode, origin = "un", destination = "iso3c")
  ))

# ------------------------------------------------------------------------------
# STEP 3: Filter and reshape RLI data to match shapefile
# ------------------------------------------------------------------------------

# Keep only countries that exist in the spatial file
processed_data <- RLI_data %>%
  filter(ISO3 %in% shapefile_iso3 | ISO3 == "WLD") %>% #WLD is there for graphs at step 6
  select(ISO3, TimePeriod, Value) %>%
  pivot_wider(names_from = TimePeriod, values_from = Value, names_prefix = "RLI_")

# ------------------------------------------------------------------------------
# STEP 4: Join RLI data back to spatial data (by ISO3 code)
# ------------------------------------------------------------------------------

# Left join adds RLI columns to spatial country data
joined_sf <- countries_sf %>%
  left_join(processed_data, by = "ISO3")

# ------------------------------------------------------------------------------
# STEP 5: Save as GeoPackage (recommended over .shp)
# ------------------------------------------------------------------------------

# Save the joined spatial data with RLI columns as GeoPackage
st_write(joined_sf, "RLI_2020_2024.gpkg", layer = "RLI", delete_dsn = TRUE)




# ------------------------------------------------------------------------------
# STEP 6: Prepare data for plotting
# ------------------------------------------------------------------------------
plot_data <- processed_data %>%
  pivot_longer(
    cols = starts_with("RLI_"),
    names_to = "Year",
    values_to = "RLI"
  ) %>%
  mutate(
    Year = as.integer(str_replace(Year, "^RLI_", "")),
    RLI  = suppressWarnings(as.numeric(RLI))
  ) %>%
  filter(!is.na(Year))

# ------------------------------------------------------------------------------
# STEP 7: Extract World-level RLI data (time series)
# ------------------------------------------------------------------------------
world_data <- plot_data %>%
  filter(ISO3 == "WLD") %>%
  select(Year, RLI) %>%
  arrange(Year)
# ------------------------------------------------------------------------------
# STEP 8: Generate and save country-specific plots
# ------------------------------------------------------------------------------
fig_dir <- "YOURDIRECTORYFILEPATH/Figures"  ##ADD THE FILE PATH YOU WISH YOUR FIGURES FOLDER TO GO TO
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

country_codes <- setdiff(unique(plot_data$ISO3), "WLD")

for (country_code in country_codes) {
  
  country_name <- countries_sf %>%
    st_drop_geometry() %>%
    filter(ISO3 == country_code) %>%
    pull(COUNTRY) %>%
    unique()
  country_name <- if (length(country_name) == 0) country_code else country_name[1]
  
  country_data <- plot_data %>%
    filter(ISO3 == country_code) %>%
    arrange(Year)
  
  if (sum(!is.na(country_data$RLI)) < 2) next
  p <- ggplot() +
    geom_line(
      data = world_data,
      aes(Year, RLI, color = "World"),
      linewidth = 1,
      na.rm = TRUE
    ) +
    geom_point(
      data = world_data,
      aes(Year, RLI, color = "World"),
      size = 1.2,
      na.rm = TRUE
    ) +
    geom_line(
      data = country_data,
      aes(Year, RLI, color = "Country"),
      linewidth = 1,
      na.rm = TRUE
    ) +
    geom_point(
      data = country_data,
      aes(Year, RLI, color = "Country"),
      size = 1.2,
      na.rm = TRUE
    ) +
    scale_color_manual(
      name = NULL,
      values = c(
        "Country" = "steelblue",
        "World"   = "black"
      )
    ) +
    labs(
      title = paste("Annual Red List Index In", country_name),
      x = "Year",
      y = "RLI Index (0–1)"
    ) +
    scale_y_continuous(limits = c(0, 1)) +
    theme_classic() +
    theme(
      plot.title = element_text(hjust = 0.5)
    )
  out_file <- file.path(fig_dir, paste0("RLI_", country_code, ".png"))
  ggsave(out_file, plot = p, width = 8, height = 6, dpi = 300)
}

