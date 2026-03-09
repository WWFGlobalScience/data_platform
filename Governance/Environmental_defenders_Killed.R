# ==============================================================================
# Environmental defenders killed (Global Witness) — Country-year totals + maps + plots
# ==============================================================================
# Data source:
#   Global Witness, "In numbers: lethal attacks against defenders since 2012"
#   https://globalwitness.org/en/campaigns/land-and-environmental-defenders/in-numbers-lethal-attacks-against-defenders-since-2012/
#
# Date accessed: January 08, 2026
#
# Assumptions about the CSV:
#   - Each row represents ONE victim (i.e., count rows to get victims)
#   - Relevant columns include: year, latitude, longitude
#   - Coordinates are in WGS84 lat/long (EPSG:4326)
#
# Outputs:
#   1) GeoPackage with a country polygon layer containing PS_YYYY columns
#   2) One PNG time-series plot per country (victims by year)
#
# Notes:
#   - Missing country-year combinations remain NA (we do NOT fill missing with 0)
#   - Spatial join uses st_within (strict). For coastal/border issues, consider st_intersects.
# ==============================================================================

# ------------------------------------------------------------------------------
# Libraries
# ------------------------------------------------------------------------------
library(readr)     # read_csv()
library(dplyr)     # mutate(), filter(), group_by(), summarise(), left_join()
library(tidyr)     # pivot_wider()
library(ggplot2)   # plotting
library(sf)        # spatial data handling: st_read(), st_join(), st_write()
library(janitor)   # clean_names()
library(stringr)   # str_replace_all()
library(scales)    # label formatting for axes

# ------------------------------------------------------------------------------
# Step 1: Load country boundaries (polygons)
# ------------------------------------------------------------------------------
# This shapefile must contain a country name field called "COUNTRY".
# We transform to EPSG:4326 to match the point coordinates (lat/long).
shapefile_path <- "YOURNAMEHERE.shp"

countries_sf <- st_read(shapefile_path, quiet = TRUE) %>%
  st_make_valid() %>%     # fixes invalid geometries that can break spatial ops
  st_transform(4326)      # WGS84 lat/long

# ------------------------------------------------------------------------------
# Step 2: Load defenders victim point data (CSV)
# ------------------------------------------------------------------------------
# read_csv() will guess column types. If latitude contains any non-numeric characters
# (e.g., symbols, stray text, unicode minus), it may import as character.
# We normalize unicode minus and use parse_number() to coerce safely to numeric. 
# It will drop bad lat/long (~190 as of this time) and filter to murders only
victims_data <- read_csv(
  "defenders-data.csv",
  show_col_types = FALSE
) %>%
  clean_names() %>%
  mutate(
    latitude  = parse_number(str_replace_all(latitude,  "\u2212", "-")),
    longitude = parse_number(str_replace_all(longitude, "\u2212", "-"))
  ) %>%
  filter(act_type == "Murder") %>%
  filter(!is.na(latitude), !is.na(longitude))

# ------------------------------------------------------------------------------
# Step 2b: Convert CSV rows into an sf point layer
# ------------------------------------------------------------------------------
# - We drop rows missing coordinates (cannot be mapped or spatially joined)
# - coords = c("longitude", "latitude") is the required order for st_as_sf()
victims_pts <- victims_data %>%
  filter(!is.na(latitude), !is.na(longitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

# ------------------------------------------------------------------------------
# Step 2c: Spatial join points to country polygons
# ------------------------------------------------------------------------------
# Purpose: assign each victim point the COUNTRY name from the boundary layer.
# join = st_within is strict: point must fall inside polygon.
# If you find many missing COUNTRY values for coastal/border points, try st_intersects.
victims_joined <- st_join(
  victims_pts,
  countries_sf %>% select(COUNTRY),  # keep only the join attribute to avoid extra columns
  join = st_within,
  left = TRUE                        # keep points even if they do not match a country
)

# ------------------------------------------------------------------------------
# Step 3: Summarize victims by country and year
# ------------------------------------------------------------------------------
# Each row is a victim, so PS = n() counts victims.
# We drop geometry because the summary is an attribute table used for plots/joins.
ps_long <- victims_joined %>%
  sf::st_drop_geometry() %>%         # prevents accidental sf propagation into joins later
  filter(!is.na(COUNTRY), !is.na(year)) %>%   # keep only points assigned to a country and year
  group_by(COUNTRY, year) %>%
  summarise(PS = n(), .groups = "drop") %>%    # victims per country-year
  arrange(COUNTRY, year)

# Create a wide table with one row per country and columns PS_YYYY.
# NOTE: We intentionally do NOT use values_fill = 0; missing stays NA.
ps_wide <- ps_long %>%
  pivot_wider(
    names_from = year,
    values_from = PS,
    names_prefix = "PS_"
  )

# Join the wide attributes back to the country polygons.
countries_ps <- countries_sf %>%
  left_join(ps_wide, by = "COUNTRY")

# ------------------------------------------------------------------------------
# Step 3b: Export to GeoPackage (country layer with PS_YYYY fields)
# ------------------------------------------------------------------------------
gpkg_out <- "YOURPATHHERE.gpkg"
dir.create(dirname(gpkg_out), recursive = TRUE, showWarnings = FALSE)

# Writes (or overwrites) a layer called "defenders_killed_country" in the GeoPackage.
sf::st_write(countries_ps, gpkg_out, layer = "defenders_killed_country", delete_layer = TRUE)

# ------------------------------------------------------------------------------
# Step 4: Generate and save one time-series plot per country (from ps_long)
# ------------------------------------------------------------------------------
# These plots show victims per year for each country.
# We keep missing years as missing (NA). The x-axis breaks are restricted to observed years
# for that country to avoid implying continuity where data are absent.
fig_dir <- "yourpath/Figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Helper to convert country names into filenames that are safe across operating systems
# (replaces spaces/punctuation with underscores).
safe_name <- function(x) gsub("[^A-Za-z0-9]+", "_", x)

for (ctry in sort(unique(ps_long$COUNTRY))) {
  
  # Subset to a single country
  df_sub <- ps_long %>% filter(COUNTRY == ctry)
  if (nrow(df_sub) < 1) next  # safety check
  
  # Build plot
  p <- ggplot(df_sub, aes(x = year, y = PS)) +
    geom_line(na.rm = TRUE, linewidth = 1.2) +
    geom_point(na.rm = TRUE, size = 2.5) +
    geom_text(aes(label = PS), vjust = -0.8, size = 3, na.rm = TRUE) +
    scale_x_continuous(breaks = sort(unique(df_sub$year))) +
    # Ensure y-axis labels appear as whole numbers (victims are individuals)
    scale_y_continuous(labels = scales::label_number(accuracy = 1)) +
    labs(
      title = paste("Environmental Defenders Killed in", ctry),
      x = "Year",
      y = "Number of victims"
    ) +
    theme_classic() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank()
    )
  
  # Save PNG
  ggsave(
    filename = file.path(fig_dir, paste0(safe_name(ctry), "_DefendersKilled.png")),
    plot = p,
    width = 9,
    height = 5.5,
    dpi = 300
  )
}

