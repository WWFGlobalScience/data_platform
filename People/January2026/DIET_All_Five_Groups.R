
# ------------------------------------------------------------------------------
# Proportion of the total population consuming all five food groups typically 
# recommended for daily consumption
# Source: Diet Quality Questionnaire (DQQ)
# URL: https://www.dietquality.org/indicators/all-5/table
# Indicator: DIET_2023 = Percentage consuming all 5 food groups (%)
# Years: 2023 (data collected 2021-2023)
# Note: Single time-point data - no time-series figures generated
# Output A: GeoPackage (countries layer with appended DIET_2023 column)
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)

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
# Load and process Diet Quality data
# ------------------------------------------------------------------------------
DIET_raw <- read_csv("DQQ_2021-2023_Public_Results.csv", show_col_types = FALSE)

# Filter to:
# - Production countries
# - "All-5" indicator (consuming all 5 food groups)
# - "All" subgroup (entire population)
DIET_2023 <- DIET_raw %>%
  filter(
    Country %in% country_names,
    Indicator == "All-5",
    Subgroup == "All"
  ) %>%
  mutate(year = "2023") %>%
  select(Country, year, Mean) %>%
  pivot_wider(names_from = year, values_from = Mean, names_prefix = "DIET_") %>%
  rename(country = Country)

# ------------------------------------------------------------------------------
# Join to shapefile and export GeoPackage
# ------------------------------------------------------------------------------
people_diet <- countries_sf %>%
  left_join(DIET_2023, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(people_diet, "DIET_Diet_Quality_Five_Groups.gpkg", 
         layer = "diet_quality", delete_layer = TRUE, quiet = TRUE)

message("GeoPackage exported: DIET_Diet_Quality_Five_Groups.gpkg")
message("Note: No time-series figures generated - single time point (2023)")