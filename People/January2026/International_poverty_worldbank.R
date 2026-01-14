# ------------------------------------------------------------------------------
# INTERNATIONAL POVERTY LINE (World Bank PIP)
# Indicator:% of population below the international poverty line (income-based)
# Data link: 
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
# Load production landscapes shapefile
# ------------------------------------------------------------------------------
prod_countries_EE <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp", quiet = TRUE) %>%
  st_make_valid()
# ------------------------------------------------------------------------------
# Load PIP data
# ------------------------------------------------------------------------------
## International Poverty Line
pip <- read_csv("People/pip.csv")

# ------------------------------------------------------------------------------
# Transform to national/income, keep needed fields (LONG for plotting)
# Please note that headcount is a proportion (0-1) it is also converted into a % in this code
## Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
poverty <- pip %>%
  filter(reporting_level == "national") %>%
  filter(welfare_type == "income") %>%
  rename(year = reporting_year) %>%
  rename(isocode3 = country_code) %>%
  rename(country = country_name) %>%
  select(country, isocode3, year, headcount) %>%
  mutate(headcount = as.numeric(headcount) * 100) %>%   # <-- ADD THIS LINE
  pivot_wider(
    names_from = year,
    values_from = headcount,
    names_glue = "{.value}_{year}_pct_WorldBank"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
poverty_prod_countries <- poverty %>%
  filter(isocode3 %in% prod_countries_EE$ISO3) %>% select(-country)

## optional csv output 
write_csv(poverty_prod_countries, paste0("People/poverty_",Sys.Date(),".csv"))

# ------------------------------------------------------------------------------
# Left join to sf and export GeoPackage
# ------------------------------------------------------------------------------
poverty_sf <- prod_countries_EE %>%
  left_join(poverty_prod_countries, by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

out_date <- Sys.Date()
out_gpkg <- file.path(paste0("International_Poverty_worldbank_", out_date, ".gpkg"))
if (file.exists(out_gpkg)) file.remove(out_gpkg)  # <-- add this line if you have created the gpkg more than once

st_write(
  poverty_sf,
  dsn   = out_gpkg,
  layer = "poverty_intl_line",
  delete_layer = TRUE,
  quiet = TRUE
)
# ------------------------------------------------------------------------------
# Figures: one time-series plot per country
# ------------------------------------------------------------------------------
poverty_long <- pip %>%
  filter(reporting_level == "national", welfare_type == "income") %>%
  transmute(
    country   = country_name,
    isocode3  = country_code,
    year      = as.integer(reporting_year),
    headcount = as.numeric(headcount) * 100             # <-- this line chnages the headcount ratio to %
  )
    
poverty_long_prod <- poverty_long %>%
      filter(isocode3 %in% prod_countries_EE$ISO3)
    

fig_dir <- "International Poverty Figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

iso_list <- sort(unique(poverty_long_prod$isocode3))

for (iso in iso_list) {
  
  df_sub <- poverty_long_prod %>% filter(isocode3 == iso)
  
  # Skip if there are not enough data points to draw a line
  if (sum(!is.na(df_sub$headcount)) < 2) next
  
  country <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country) || country == "") country <- iso
  
  safe_country <- str_replace_all(country, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(fig_dir, paste0("International_Poverty_", iso, "_", safe_country, ".png"))
  
  p <- ggplot(df_sub, aes(x = year, y = headcount)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 2.5) +
    labs(
      title = paste("Population below the international poverty line in", country),
      x = "Year",
      y = "Percent (%)",
      caption = "Source: World Bank"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
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