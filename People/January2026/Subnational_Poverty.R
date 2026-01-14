# ------------------------------------------------------------------------------
# Subnational percentage of people below the international poverty line (GDL)
#- The International Wealth Index (IWI) is an asset-based index from 0 (no assets)
#   to 100 (all assets), designed to be comparable across places and over time.
# - iwipov35 is an IWI-based poverty proxy: the share of the population with
#   IWI < 35 in the area (i.e., below an asset-wealth threshold of 35).
#   This measure is reported by GDL as highly correlated with World Bank poverty
#   headcount ratios.
# ------------------------------------------------------------------------------
library(sf)
library(dplyr)
library(stringr)
library(readr)
library(tidyr)
library(rnaturalearth)
library(countrycode)
library(units)

install.packages("remotes")
remotes::install_github("ropensci/rnaturalearthhires")
library(rnaturalearthhires)

# ------------------------------------------------------------------------------
# Load and validate prod_scapes_EE sf object
# ------------------------------------------------------------------------------
prod_scapes_EE <- st_read(
  "Spatial Data/Prod_scapes_EE_wflags/Prod_scapes_EE.shp",
  quiet = TRUE
) %>%
  st_make_valid() %>%
  mutate(
    scape_id   = ID,     # 
    scape_name = Name    # rename now to avoid collisions later
  )


# ------------------------------------------------------------------------------
# Load admin level 1 shapefile for the entire globe
# ------------------------------------------------------------------------------
adm1 <- ne_states(returnclass = "sf") %>%
  st_transform(st_crs(prod_scapes_EE)) %>%
  st_make_valid()

# Keep only what we need and create ISO3 for joining to GDL
adm1_clean <- adm1 %>%
  transmute(
    iso_a2 = iso_a2,
    iso3   = countrycode(iso_a2, origin = "iso2c", destination = "iso3c"),
    name   = name,
    geometry = geometry
  ) %>%
  filter(!is.na(iso3))

# ------------------------------------------------------------------------------
# Load GDL subnational poverty data
# ------------------------------------------------------------------------------
iwi <- read_csv(
  "GDL-Area_Database_Data-v441.csv",
  show_col_types = FALSE
)

# Reformat the data so indicators x year each get one column
# NOTE: Use ISO3 + region name as join key to ADM1 polygons
iwi_wide <- iwi %>%
  filter(level == "Subnat") %>%
  transmute(
    iso3    = isocode3,   # country ISO3 in the GDL file
    name    = region,     # subnational region name in the GDL file
    country = country,
    year    = year,
    iwipov35 = iwipov35
  ) %>%
  mutate(
    iso3 = toupper(str_trim(iso3)),
    name = str_squish(name),
    year = as.integer(year),
    iwipov35 = as.numeric(iwipov35)
  ) %>%
  pivot_wider(
    names_from  = year,
    values_from = iwipov35,
    names_glue  = "{.value}_{year}_pct_GDL"
  )

# ------------------------------------------------------------------------------
# Join ADM1 polygons with poverty table
# ------------------------------------------------------------------------------
adm1_joined <- adm1_clean %>%
  mutate(name = str_squish(name)) %>%
  left_join(iwi_wide, by = c("iso3", "name"))

# Calculate area of each administrative unit (requires projected CRS; we used prod_scapes CRS)
adm1_joined <- adm1_joined %>%
  mutate(adm1_area = st_area(geometry))

# ------------------------------------------------------------------------------
# Intersect ADM1 with production landscapes
# ------------------------------------------------------------------------------
adm1_prod_int <- st_intersection(
  adm1_joined,
  prod_scapes_EE %>% select(scape_id, scape_name)
) %>%
  mutate(int_area = st_area(geometry))


# Percent of ADM1 that overlaps the production landscape
adm1_prod_long <- adm1_prod_int %>%
  mutate(
    pct_adm1_in_prod = as.numeric(int_area / adm1_area) * 100
  )

# ------------------------------------------------------------------------------
# Filter ADM1 units with >= 25% overlap with production landscapes
# ------------------------------------------------------------------------------
adm1_prod_25 <- adm1_prod_long %>%
  filter(pct_adm1_in_prod >= 25)

# ------------------------------------------------------------------------------
# Write output (25% only)
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")
adm1_prod_25_out <- adm1_prod_25 %>%
  st_make_valid() %>%
  st_transform(4326)

gpkg_name <- paste0("subnat_pov_25_pct_", run_date, ".gpkg")

st_write(
  adm1_prod_25_out,
  gpkg_name,
  layer = "adm1_pov25",
  delete_layer = TRUE
)
pov_cols <- names(adm1_prod_25_out) %>%
  stringr::str_detect("^iwipov35_\\d{4}_pct_GDL$")

scape_pov <- adm1_prod_25_out %>%
  st_drop_geometry() %>%
  group_by(scape_id, scape_name) %>%
  summarise(
    across(
      all_of(names(adm1_prod_25_out)[pov_cols]),
      ~ weighted.mean(.x, w = as.numeric(int_area), na.rm = TRUE)
    ),
    scape_area = sum(as.numeric(int_area), na.rm = TRUE),
    n_adm1     = n_distinct(paste(iso3, name)),
    .groups = "drop"
  )
