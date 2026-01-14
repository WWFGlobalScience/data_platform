# ------------------------------------------------------------------------------
# Percent of children free from stunting, wasting, and overweight (UNICEF)
# Indicator: WOWC = ANT_FREE_r
# Output A: GeoPackage (countries layer with appended indicator columns)
# Output B: One time-series figure per country
# Data link:
#
# Note on duplicates:
# The UNICEF source file can contain multiple rows for the same country-year because
# estimates may come from different survey sources, and in some cases multiple surveys
# were conducted in the same year. To produce a single national value per country-year
# for mapping and plotting, we take the mean of WOWC across duplicate country-year rows.
# ----------------------------------------------------------------------------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(scales)

# ------------------------------------------------------------------------------
# Load production landscapes shapefile
# ------------------------------------------------------------------------------
prod_countries_EE <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp", quiet = TRUE) %>%
  st_make_valid()

# ------------------------------------------------------------------------------
# Load UNICEF data
# ------------------------------------------------------------------------------
swo <- read_csv(
  "wso_UNICEF.csv",
  skip = 8,
  show_col_types = FALSE
)

# ------------------------------------------------------------------------------
# LONG table for figures
# ------------------------------------------------------------------------------
swo_long <- swo %>%
  rename(year = CMRS_year) %>%
  rename(isocode3 = ISO3Code) %>%
  rename(country = CountryName) %>%
  rename(WOWC = ANT_FREE_r) %>%
  select(country, isocode3, year, WOWC) %>%
  mutate(
    year = as.integer(year),
    WOWC = as.numeric(WOWC)
  ) %>%
  arrange(isocode3, year)

# Filter to production countries  (used for plots + wide table + join)
swo_long_prod <- swo_long %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

# De-duplicate to one value per country-year (mean across multiple survey sources)
swo_long_prod <- swo_long_prod %>%
  group_by(country, isocode3, year) %>%
  summarise(WOWC = mean(WOWC, na.rm = TRUE), .groups = "drop") %>%
  arrange(isocode3, year)

# ------------------------------------------------------------------------------
# WIDE table for joining to sf 
# ------------------------------------------------------------------------------
swo_wide_prod <- swo_long_prod %>%
  pivot_wider(
    names_from  = year,
    values_from = WOWC,
    names_glue  = "{.value}_{year}_pct_UNICEF"
  )

# Optional CSV output 
write_csv(
  swo_wide_prod,
  "WOWC.csv"
)

# ------------------------------------------------------------------------------
# Left join to sf and export GeoPackage
# ------------------------------------------------------------------------------
swo_sf <- prod_countries_EE %>%
  left_join(swo_wide_prod %>% select(-country), by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

out_date <- Sys.Date()
out_gpkg <- file.path(paste0("WOWC_UNICEF_", out_date, ".gpkg"))
if (file.exists(out_gpkg)) file.remove(out_gpkg)

st_write(
  swo_sf,
  dsn   = out_gpkg,
  layer = "wowc_free_from_stunting_wasting_overweight",
  delete_layer = TRUE,
  quiet = TRUE
)

# ------------------------------------------------------------------------------
# Figures: one time-series plot per country
# ------------------------------------------------------------------------------
fig_dir <- "Children free from SWO Figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

iso_list <- sort(unique(swo_long_prod$isocode3))

for (iso in iso_list) {
  
  df_sub <- swo_long_prod %>% filter(isocode3 == iso)
  
  # Skip if there are not enough data points to draw a line
  if (sum(!is.na(df_sub$WOWC)) < 2) next
  
  country <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country) || country == "") country <- iso
  
  safe_country <- str_replace_all(country, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(fig_dir, paste0("WOWC_", iso, "_", safe_country, ".png"))
  
  # --- Option 1: Auto-shrink title font size based on title length ---
  title_text <- paste(
    "Children free from stunting, wasting, and overweight in",
    country
  )
  
  title_size <- ifelse(
    nchar(title_text) > 70, 13,
    ifelse(nchar(title_text) > 55, 14, 16)
  )
  
  p <- ggplot(df_sub, aes(x = year, y = WOWC)) +
    geom_line(linewidth = 1.2, na.rm = TRUE) +
    geom_point(size = 2.5, na.rm = TRUE) +
    geom_text(
      aes(label = round(WOWC, 1)),
      vjust = -0.8,
      size = 3.0,
      na.rm = TRUE
    ) +
    labs(
      title = title_text,
      x = "Year",
      y = "Percent (%)",
      caption = "Source: UNICEF"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = title_size, face = "bold", hjust = 0.5),
      axis.text  = element_text(color = "black"),
      axis.line  = element_line(color = "black"),
      legend.position = "none",
      panel.grid = element_blank()
    )
  
  ggsave(out_png, p, width = 7.5, height = 4.5, dpi = 300)
}
