#
#Indicator: Number of people requiring interventions against neglected tropical diseases(WHO)
#INTD_YYYY
# Data link:https://www.who.int/data/gho/data/indicators/indicator-details/GHO/reported-number-of-people-requiring-interventions-against-ntds?bookmarkId=148f1bf9-876a-40ee-8ed2-97d3e376a86e
# Output A: GeoPackage (countries layer with appended indicator columns)
# Output B: One time-series figure per country
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(scales)
library(countrycode)

# ------------------------------------------------------------------------------
# Load production landscapes shapefile
# ------------------------------------------------------------------------------
prod_countries_EE <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp", quiet = TRUE) %>%
  st_make_valid()
# ------------------------------------------------------------------------------
# Load disease data, keep COUNTRY rows only
# ------------------------------------------------------------------------------
disease <- read_csv("disease.csv", show_col_types = FALSE) %>%
  filter(DIM_GEO_CODE_TYPE == "COUNTRY") %>%     # <-- so that the M49 is only country level keep the World if you want to add world line
  rename(COUNTRY = GEO_NAME_SHORT)

# Note that this dataset uses the UN M49 code system, here we are adding a step to convert to ISO3 so we can filter and left join by that rather
# Than country name which can lead to dropped countries if there are any discrepencies in the naming

# ------------------------------------------------------------------------------
# Translate M49 -> ISO3 (replace the old merge-by-name step)
# ------------------------------------------------------------------------------
disease <- disease %>%
  mutate(
    # DIM_GEO_CODE_M49 is usually numeric; coerce safely
    m49 = suppressWarnings(as.numeric(DIM_GEO_CODE_M49)),
    ISO3 = countrycode(m49, origin = "un", destination = "iso3c")
  )
disease_long <- disease %>%
  rename(year = DIM_TIME) %>%
  rename(isocode3 = ISO3) %>%
  rename(country = COUNTRY) %>%
  rename(INTD = COUNT_N) %>%
  select(country, isocode3, year, INTD) %>%
  mutate(
    year = as.integer(year),
    INTD = as.numeric(INTD)
  ) %>%
  arrange(isocode3, year)

# ------------------------------------------------------------------------------
#  Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
#The LONG format is for figures and the wide format is for joining to SF
# ------------------------------------------------------------------------------
#
disease_long <- disease %>%
  rename(year = DIM_TIME) %>%
  rename(isocode3 = ISO3) %>%
  rename(country = COUNTRY) %>%
  rename(INTD = COUNT_N) %>%
  select(country, isocode3, year, INTD) %>%
  mutate(
    year = as.integer(year),
    INTD = as.numeric(INTD)
  ) %>%
  arrange(isocode3, year)

disease <- disease_long %>%
  pivot_wider(
    names_from  = year,
    values_from = INTD,
    names_glue  = "{.value}_{year}_ct_WHO"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
disease_prod_countries <- disease %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(disease_prod_countries, paste0("People/INTD_",Sys.Date(),".csv")) #optional export csv for your data

# ------------------------------------------------------------------------------
# Left join to sf and export GeoPackage 
# ------------------------------------------------------------------------------
disease_sf <- prod_countries_EE %>%
  left_join(disease_prod_countries %>% select(-country), by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

out_date <- Sys.Date()
out_gpkg <- file.path(paste0("INTD_WHO_", out_date, ".gpkg"))
if (file.exists(out_gpkg)) file.remove(out_gpkg)

st_write(
  disease_sf,
  dsn   = out_gpkg,
  layer = "intd_people_requiring_intervention",
  delete_layer = TRUE,
  quiet = TRUE
)

# ------------------------------------------------------------------------------
# Figures: one time-series plot per country
# ------------------------------------------------------------------------------
disease_long_prod <- disease_long %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

fig_dir <- "Neglected Tropical Diseases Figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

iso_list <- sort(unique(disease_long_prod$isocode3))

for (iso in iso_list) {
  
  df_sub <- disease_long_prod %>% filter(isocode3 == iso)
  
  # Skip if there are not enough data points to draw a line
  if (sum(!is.na(df_sub$INTD)) < 2) next
  
  country <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country) || country == "") country <- iso
  
  safe_country <- str_replace_all(country, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(fig_dir, paste0("INTD_", iso, "_", safe_country, ".png"))
  
  p <- ggplot(df_sub, aes(x = year, y = INTD)) +
    geom_line(linewidth = 1.2, na.rm = TRUE) +
    geom_point(size = 2.5, na.rm = TRUE)  +
    labs(
      title = paste("People requiring interventions against NTDs in", country),
      x = "Year",
      y = "People (count)",
      caption = "Source: WHO"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    scale_y_continuous(labels = scales::comma) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text  = element_text(color = "black"),
      axis.line  = element_line(color = "black"),
      legend.position = "none",
      panel.grid = element_blank()
    )
  
  ggsave(out_png, p, width = 7.5, height = 4.5, dpi = 300)
}


