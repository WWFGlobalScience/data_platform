# ------------------------------------------------------------------------------
#Extent to which countries have laws and regulations that guarantee women aged 15-49 access to 
#sexual and reproductive health care, information and education (2019 and 2022)
# Source: WHO
# Indicator: rr = Value String (%)
# Output A: GeoPackage (countries layer with appended indicator columns)
# Note: There is data either for countries either in 2019 or 2022 so no figures were created
# ------------------------------------------------------------------------------

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
# Load WHO data (keep your header + skip pattern)
# ------------------------------------------------------------------------------
rr_path <- "rr_WHO.csv"

header <- names(read_csv(rr_path, n_max = 0, show_col_types = FALSE))
rr <- read_csv(rr_path, skip = 34, col_names = header, show_col_types = FALSE)

# ------------------------------------------------------------------------------
# LONG table for figures
# ------------------------------------------------------------------------------
rr_long <- rr %>%
  rename(year = Year) %>%
  rename(isocode3 = `Country ISO 3 code`) %>%
  rename(country = Country) %>%
  rename(rr = `Value String`) %>%
  select(country, isocode3, year, rr) %>%
  mutate(
    year = as.integer(year),
    rr   = as.numeric(rr)
  ) %>%
  arrange(isocode3, year)

rr_long_prod <- rr_long %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

# ------------------------------------------------------------------------------
# WIDE table for join (production countries only)
# ------------------------------------------------------------------------------
rr_wide_prod <- rr_long_prod %>%
  pivot_wider(
    names_from  = year,
    values_from = rr,
    names_glue  = "{.value}_{year}_pct_WHO"
  )

#optional csv
write_csv(
  rr_wide_prod,
  "reprod_rights.csv"
)

# ------------------------------------------------------------------------------
# Left join to sf and export GeoPackage
# ------------------------------------------------------------------------------
rr_sf <- prod_countries_EE %>%
  left_join(rr_wide_prod %>% select(-country), by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

out_date <- Sys.Date()
out_gpkg <- file.path( paste0("reprod_rights_WHO_", out_date, ".gpkg"))
if (file.exists(out_gpkg)) file.remove(out_gpkg)

st_write(rr_sf, dsn = out_gpkg, layer = "reproductive_rights", delete_layer = TRUE, quiet = TRUE)

