# ------------------------------------------------------------------------------
# Percent of children under 5 who received five standard vaccines (BCG, DPT, TT, Measles)
# Data Link: https://globaldatalab.org/asset/600/Health%20Data%20v2.1.csv
# Indicator: vaccineage1 (mean of bcgage1:measlage1)
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

# ------------------------------------------------------------------------------
# Load production landscapes shapefiles
# ------------------------------------------------------------------------------
prod_countries_EE <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp", quiet = TRUE) %>%
  st_make_valid()

# ------------------------------------------------------------------------------
# Load health data and create vaccine variable
# ------------------------------------------------------------------------------
health <- read_csv("Health Data v2.1.csv", show_col_types = FALSE) %>%
  mutate(
    vaccineage1 = rowMeans(select(., bcgage1:measlage1), na.rm = TRUE)
  )

## Percent of children under 5 years old who have received five standard vaccines
## (tuberculosis, diptheria, pertussis, tetanus, measles)

# ------------------------------------------------------------------------------
# Wide table (one row per country) for joining to sf
# ------------------------------------------------------------------------------
vaccine <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, vaccineage1) %>%
  pivot_wider(
    names_from  = year,
    values_from = vaccineage1,
    names_glue  = "{.value}_{year}_pct_GDL"
  )

# ------------------------------------------------------------------------------
# Restrict to production countries
# ------------------------------------------------------------------------------
vaccine_prod_countries <- vaccine %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

# ------------------------------------------------------------------------------
# Left join to sf and export GeoPackage
# ------------------------------------------------------------------------------
prod_countries_vaccine <- prod_countries_EE %>%
  left_join(vaccine_prod_countries, by = c("ISO3" = "isocode3"))

st_write(
  prod_countries_vaccine,
  dsn   = "VaccinationCoverage.gpkg",
  layer = "vaccination_coverage_u5",
  driver = "GPKG",
  delete_layer = TRUE,
  quiet = TRUE
)

## ------------------------------------------------------------------------------
## Figures
## ------------------------------------------------------------------------------

# Output directory for figures
fig_dir <- "Vaccination Coverage Figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Long table derived from the SAME data (only introduced here)
vaccine_long <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, vaccineage1) %>%
  mutate(
    year = as.integer(year),
    vaccineage1 = as.numeric(vaccineage1),
    label = ifelse(is.na(vaccineage1), NA_character_, sprintf("%.1f", vaccineage1))
  ) %>%
  filter(isocode3 %in% prod_countries_EE$ISO3) %>%
  arrange(isocode3, year)

iso_list <- sort(unique(vaccine_long$isocode3))

for (iso in iso_list) {
  
  df_sub <- vaccine_long %>% filter(isocode3 == iso)
  
  # Skip countries without enough data
  if (sum(!is.na(df_sub$vaccineage1)) < 2) next
  
  country <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country) || country == "") country <- iso
  
  safe_country <- str_replace_all(country, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(fig_dir, paste0(iso, "_", safe_country, "_Vaccine_U5.png"))
  
  p <- ggplot(df_sub, aes(x = year, y = vaccineage1)) +
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
      title = paste0(
        "Percent of children under 5 vaccinated (5 standard vaccines) in ",
        country
      ),
      x = "Year",
      y = "Percent (%)"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_classic(base_size = 13) +
    theme(
      plot.title = element_text(size = 15, face = "bold", hjust = 0.5),
      axis.text  = element_text(color = "black")
    )
  
  
  ggsave(out_png, plot = p, width = 8.5, height = 5.2, dpi = 300)
}


