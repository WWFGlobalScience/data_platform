# ------------------------------------------------------------------------------
# Mortality rate attributed to unsafe water, unsafe sanitation and lack of hygiene
# Source: WHO Global Health Observatory
# URL: https://www.who.int/data/gho/data/indicators/indicator-details/GHO/mortality-rate-attributed-to-exposure-to-unsafe-wash-services-(per-100-000-population)-(sdg-3-9-2)
# Indicator: MWASH_YYYY = Mortality rate per 100,000 population
# Years: 2012, 2015, 2019
# Note: 2012 and 2015 data not comparable to 2019 due to methodology changes so only using 2019 here
# Note: Single time-point data per country - no time-series figures generated
# Output A: GeoPackage (countries layer with appended MWASH_YYYY columns)
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(readxl)
library(lubridate)
library(janitor)
library(stringr)
library(showtext)

# Optional: Add font for cleaner plots
font_add_google("Open Sans", "opensans")
showtext_auto()

# Read shapefile and extract country list
shp_path <- "Prod_countries_EE.shp"
countries_sf <- st_read(shp_path)
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% unique()

# Load and clean WASH data
people_data_mwash <- read_csv("WASH.csv") %>%
  rename(country = Location) %>%
  mutate(year = as.character(Period)) %>%
  filter(country %in% country_names, Dim1 == "Both sexes", year == "2019") %>%
  select(country, value = Value)

MWASH_wide <- read_csv("WASH.csv") %>%
  rename(country = Location) %>%
  mutate(year = as.character(Period)) %>%
  filter(country %in% country_names, Dim1 == "Both sexes") %>%
  pivot_wider(names_from = year, values_from = Value, names_prefix = "MWASH_") %>%
  select(country, starts_with("MWASH_"))

# Clean country names for matching if needed
#people_data_mwash <- people_data_mwash %>%
#  mutate(country = str_trim(country))
 ------------------------------------------------------------------------------
# Join to shapefile and export GeoPackage
# ------------------------------------------------------------------------------
people_mwash <- countries_sf %>%
  left_join(MWASH_wide, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(people_mwash, "MWASH_Mortality_Water_Sanitation.gpkg", 
         layer = "wash_mortality", delete_layer = TRUE, quiet = TRUE)
# Create output folder
dir.create("MWASH_Plots", showWarnings = FALSE)

# Plot one dot per country
for (i in 1:nrow(people_data_mwash)) {
  df_sub <- people_data_mwash[i, ]
  
  p <- ggplot(df_sub, aes(x = country, y = value)) +
    geom_point(color = "#728423", size = 4.5) +
    geom_text(aes(label = round(value, 1)), vjust = -1, size = 5) +
    labs(
      title = paste("Mortality from Unsafe Water & Sanitation in", df_sub$country, "(2019)"),
      x = NULL,
      y = "Deaths per 100,000 people"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.line.y = element_line(color = "black"),
      axis.line.x = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "none"
    )
  
  plot_path <- file.path("MWASH_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", df_sub$country), "_MWASH_2019.png"))
  ggsave(plot_path, plot = p, width = 6, height = 5, dpi = 300)
}

