# ------------------------------------------------------------------------------
# % of children (0–59 months) Underweight - below −3 SD weight-for-age — National (GDL Health v2.1)
# Variable: underweightsev
#
# Outputs:
#  A) Wide country table (CSV) with columns: underweightsev_{year}_per_GDL
#  B) GeoPackage of WWF country boundaries joined with the same indicator columns
#  C) One time-series figure per country
#
# Data link:
# Downloaded:
# ------------------------------------------------------------------------------

# ---- Libraries ----
# sf: spatial data I/O + operations
# dplyr/tidyr: wrangling + reshaping (wide/long)
# readr: fast CSV read/write
# stringr: safe filenames (remove special characters)
# ggplot2/scales: plotting + pretty axis breaks
library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(scales)

# ------------------------------------------------------------------------------
# Load WWF production country boundaries
# - This shapefile provides the ISO3 codes used to filter the indicator dataset
# - st_make_valid() repairs invalid geometries that can cause downstream errors
# ------------------------------------------------------------------------------
countries_sf <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp", quiet = TRUE) %>%
  st_make_valid()

# ------------------------------------------------------------------------------
# Load GDL Health data (v2.1)
# - show_col_types = FALSE suppresses readr's column type printing
# ------------------------------------------------------------------------------
health <- read_csv("Health Data v2.1.csv", show_col_types = FALSE)

# ------------------------------------------------------------------------------
# Create a WIDE country table:
# - Filter to National level values only
# - Keep only ISO3, year, and the indicator variable
# - Ensure year is integer and values are numeric
# - Pivot wider so each year becomes its own column
#   underweightsev_YYYY_per_GDL
# ------------------------------------------------------------------------------
under_wide <- health %>%
  filter(level == "National") %>%
  select(isocode3, year, underweightsev) %>%
  mutate(
    year = as.integer(year),
    underweightsev = as.numeric(underweightsev)
  ) %>%
  pivot_wider(
    names_from  = year,
    values_from = underweightsev,
    names_glue  = "{.value}_{year}_per_GDL"
  )

# ------------------------------------------------------------------------------
# Restrict to the countries in the WWF boundaries layer (Prod_countries_EE)
# - Uses ISO3 match: health$isocode3 vs countries_sf$ISO3
# ------------------------------------------------------------------------------
under_prod <- under_wide %>%
  filter(isocode3 %in% countries_sf$ISO3)

# ------------------------------------------------------------------------------
# Export the wide country table as a dated CSV
# - Creates "People/" if it does not exist
# ------------------------------------------------------------------------------
out_date <- Sys.Date()
dir.create("People", showWarnings = FALSE, recursive = TRUE)

write_csv(
  under_prod,
  file.path("People", paste0("underweightsev_", out_date, ".csv"))
)

# ------------------------------------------------------------------------------
# Join indicator columns onto the country boundaries and write a GeoPackage
# - left_join keeps all WWF countries, filling indicator columns with NA when missing
# - st_transform(4326) writes in WGS84 (generally the safest CRS for GeoPackage export)
# ------------------------------------------------------------------------------
under_sf <- countries_sf %>%
  left_join(under_prod, by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

# GeoPackage output file name (dated)
out_gpkg <- file.path(paste0("underweightsev_", out_date, ".gpkg"))

# Write layer to GeoPackage
# - delete_layer = TRUE overwrites the layer if it already exists in the gpkg
st_write(
  under_sf,
  dsn = out_gpkg,
  layer = "underweight_severe_u5",
  delete_layer = TRUE,
  quiet = TRUE
)

# ------------------------------------------------------------------------------
# Figures output directory
# ------------------------------------------------------------------------------
fig_dir <- file.path("Severely Underweight Children Figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# Create a LONG table for plotting:
# - Keep country name for plot titles (not used in GeoPackage join)
# - Convert year/value to numeric
# - Create a point label (formatted to 1 decimal place)
# - Restrict to production countries and sort by ISO/year
# ------------------------------------------------------------------------------
under_long <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, underweightsev) %>%
  mutate(
    year           = as.integer(year),
    underweightsev = as.numeric(underweightsev),
    label          = ifelse(
      is.na(underweightsev),
      NA_character_,
      sprintf("%.1f", underweightsev)
    )
  ) %>%
  filter(isocode3 %in% countries_sf$ISO3) %>%
  arrange(isocode3, year)

# ------------------------------------------------------------------------------
# Loop over each ISO3 and generate one plot per country
# ------------------------------------------------------------------------------
iso_list <- sort(unique(under_long$isocode3))

for (iso in iso_list) {
  
  # Subset to a single country
  df_sub <- under_long %>% filter(isocode3 == iso)
  
  # Skip countries without enough non-missing values to draw a line
  if (sum(!is.na(df_sub$underweightsev)) < 2) next
  
  # Pull a country name for labeling (fallback to ISO3 if missing)
  country_nm <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country_nm) || country_nm == "") country_nm <- iso
  
  # Safe filename: replace non-alphanumeric characters with underscores
  safe_country <- str_replace_all(country_nm, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  # Output image path
  out_png <- file.path(
    fig_dir,
    paste0(iso, "_", safe_country, "_UnderweightSevere_U5.png")
  )
  
  # Build plot:
  # - line + points for the time series
  # - text labels above points (check_overlap reduces label clutter)
  # - pretty_breaks controls the number of x-axis tick marks
  p <- ggplot(df_sub, aes(x = year, y = underweightsev)) +
    geom_line(linewidth = 1.1, na.rm = TRUE) +
    geom_point(size = 2.2, na.rm = TRUE) +
    geom_text(
      aes(label = label),
      vjust = -0.8,
      size = 2.6,
      na.rm = TRUE,
      check_overlap = TRUE
    ) +
    labs(
      title = paste0("Severely underweight children (0–59 months) in ", country_nm),
      x = "Year",
      y = "Percent (%)",
      caption = "Source: Global Data Lab"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_classic(base_size = 13) +
    theme(
      plot.title = element_text(size = 15, face = "bold", hjust = 0.5),
      axis.text  = element_text(color = "black")
    )
  
  # Save figure
  ggsave(out_png, plot = p, width = 8.5, height = 5.2, dpi = 300)
}
