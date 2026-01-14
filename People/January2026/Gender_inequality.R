# ------------------------------------------------------------------------------
# Gender Inequality Index (GII) — National (UNDP HDR)
# Minimal-change, annotated script based on Mabel’s original draft
# ------------------------------------------------------------------------------
# What this script does:
#  1) Loads WWF country boundaries (Prod_countries_EE.shp) and pulls ISO3 codes
#  2) Reads the UNDP HDR CSV and filters to indicatorCode == "gii" for those ISO3s
#  3) Pivots to a wide country table (GII_YYYY columns)
#  4) Exports:
#       - Wide table as CSV
#       - Countries layer joined with GII columns as a GeoPackage
#  5) (Optional) Creates one time-series plot per country
#
# Source:
#  https://hdr.undp.org/data-center/documentation-and-downloads
# Indicator:
#  Gender Inequality Index (0–1), higher = more inequality
# Years:
#  Typically 2012–2022 (varies by download/version)
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)
library(janitor)
library(stringr)
library(ggplot2)

# ───────────────────────────────────────────────────────────────────────────────
# STEP 1: Load country boundaries and ISO3 codes used to filter the HDR dataset
# ───────────────────────────────────────────────────────────────────────────────
countries_sf <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp")

country_ISO <- countries_sf %>%
  st_drop_geometry() %>%
  pull(ISO3)

# ───────────────────────────────────────────────────────────────────────────────
# STEP 2: Load HDR CSV and filter to GII (indicatorCode == "gii") for your ISO3s
# ───────────────────────────────────────────────────────────────────────────────
# NOTE: This assumes the CSV has columns: indicatorCode, countryIsoCode, country, year, value
GII <- read_csv("GII_data.csv")

GII_country <- GII %>%
  filter(indicatorCode == "gii", countryIsoCode %in% country_ISO) %>%
  select(country, countryIsoCode, year, value) %>%
  # Keep year as character for pivot_wider() column names; ensure value is numeric for plotting
  mutate(
    year  = as.character(year),
    value = as.numeric(value)
  )

# ───────────────────────────────────────────────────────────────────────────────
# STEP 3: Pivot to wide format (one row per country, columns GII_YYYY)
# ───────────────────────────────────────────────────────────────────────────────
GII_COUNTRY_ISOWIDE <- GII_country %>%
  pivot_wider(
    names_from   = year,
    values_from  = value,
    names_prefix = "GII_"
  )

# ───────────────────────────────────────────────────────────────────────────────
# STEP 4: Export wide-format table to CSV
# ───────────────────────────────────────────────────────────────────────────────
# IMPORTANT: write_csv() must happen AFTER GII_COUNTRY_ISOWIDE is created
write_csv(GII_COUNTRY_ISOWIDE, "GII_COUNTRY_01_13_2026.csv")

# ───────────────────────────────────────────────────────────────────────────────
# STEP 5: Left-join wide GII columns into the country shapefile
# ───────────────────────────────────────────────────────────────────────────────
countries_gii_sf <- countries_sf %>%
  left_join(GII_COUNTRY_ISOWIDE, by = c("ISO3" = "countryIsoCode"))

# ───────────────────────────────────────────────────────────────────────────────
# STEP 6: Export as GeoPackage
# ───────────────────────────────────────────────────────────────────────────────
# NOTE: If you hit PROJ/WKT conversion errors (e.g., Equal Earth), writing in EPSG:4326 is safest.
# If your input is already geographic, this is typically harmless.
countries_gii_sf_out <- countries_gii_sf %>%
  st_make_valid() %>%
  st_transform(4326)

st_write(
  countries_gii_sf_out,
  "GII_country_data_01_13_2026.gpkg",
  layer = "GII_national",
  delete_layer = TRUE
)

# ───────────────────────────────────────────────────────────────────────────────
# STEP 7 (Optional): Generate one plot per country (your preferred style)
# ───────────────────────────────────────────────────────────────────────────────
# Output folder for figures
fig_dir <- "Figures/GII"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Recast year to numeric for plotting (we kept it character for pivoting)
GII_plot <- GII_country %>%
  mutate(
    year  = as.numeric(year),
    value = as.numeric(value)
  ) %>%
  arrange(countryIsoCode, year)

country_codes <- unique(GII_plot$countryIsoCode)

for (iso in country_codes) {
  
  df_sub <- GII_plot %>% filter(countryIsoCode == iso)
  
  # Skip if there are not enough data points to draw a line
  if (sum(!is.na(df_sub$value)) < 2) next
  
  country <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country) || country == "") country <- iso
  
  # Safe filename (avoid special characters)
  safe_country <- str_replace_all(country, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  out_png <- file.path(fig_dir, paste0("GII_", iso, "_", safe_country, ".png"))
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    labs(
      title = paste("Gender Inequality Index in", country),
      x = "Year",
      y = "Index (0–1)"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      legend.position = "none"
    ) +
    # Every five years on the x-axis (standardized ticks across plots)
    scale_x_continuous(
      breaks = function(x) {
        yrs <- sort(unique(x))
        seq(floor(min(yrs) / 5) * 5, ceiling(max(yrs) / 5) * 5, by = 5)
      }
    )
  
  ggsave(out_png, p, width = 7.5, height = 4.5, dpi = 300)
}
