# ------------------------------------------------------------------------------
# MATERNAL MORTALITY (WHO)
# Indicator: Maternal mortality ratio (per 100,000 live births)
# Field: RATE_PER_100000_N
# Output A: GeoPackage (countries layer with appended indicator columns)
# Output B: One time-series figure per country
#Data link: 
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
# Load maternal mortality data, keep COUNTRY rows only
# ------------------------------------------------------------------------------
maternal <- read_csv("maternal_WHO.csv", show_col_types = FALSE) %>%
  filter(DIM_GEO_CODE_TYPE == "COUNTRY") %>%
  rename(COUNTRY = GEO_NAME_SHORT)

# ------------------------------------------------------------------------------
# Translate M49 -> ISO3
# ------------------------------------------------------------------------------
maternal <- maternal %>%
  mutate(
    m49  = suppressWarnings(as.numeric(DIM_GEO_CODE_M49)),
    ISO3 = countrycode(m49, origin = "un", destination = "iso3c")
  )

# ------------------------------------------------------------------------------
# LONG table for figures
# ------------------------------------------------------------------------------
maternal_long <- maternal %>%
  rename(year = DIM_TIME) %>%
  rename(isocode3 = ISO3) %>%
  rename(country = COUNTRY) %>%
  rename(MM = RATE_PER_100000_N) %>%
  select(country, isocode3, year, MM) %>%
  mutate(
    year = as.integer(year),
    MM   = as.numeric(MM)
  ) %>%
  arrange(isocode3, year)

# ------------------------------------------------------------------------------
# WIDE table for joining to sf
# ------------------------------------------------------------------------------
maternal <- maternal_long %>%
  pivot_wider(
    names_from  = year,
    values_from = MM,
    names_glue  = "{.value}_{year}_rto_WHO"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
maternal_prod_countries <- maternal %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(maternal_prod_countries, paste0("People/MM_", Sys.Date(), ".csv")) #OPTIONAL CSV

# ------------------------------------------------------------------------------
# Left join to sf and export GeoPackage
# ------------------------------------------------------------------------------
maternal_sf <- prod_countries_EE %>%
  left_join(maternal_prod_countries %>% select(-country), by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

out_date <- Sys.Date()
out_gpkg <- file.path(paste0("MM_WHO_", out_date, ".gpkg"))
if (file.exists(out_gpkg)) file.remove(out_gpkg)

st_write(
  maternal_sf,
  dsn   = out_gpkg,
  layer = "maternal_mortality_ratio",
  delete_layer = TRUE,
  quiet = TRUE
)

# ------------------------------------------------------------------------------
# Figures: one time-series plot per country
# ------------------------------------------------------------------------------
maternal_long_prod <- maternal_long %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

fig_dir <- "Maternal Mortality Figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

iso_list <- sort(unique(maternal_long_prod$isocode3))

for (iso in iso_list) {
  
  df_sub <- maternal_long_prod %>% filter(isocode3 == iso)
  
  # Skip if there are not enough data points to draw a line
  if (sum(!is.na(df_sub$MM)) < 2) next
  
  country <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country) || country == "") country <- iso
  
  safe_country <- str_replace_all(country, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(fig_dir, paste0("MM_", iso, "_", safe_country, ".png"))
  
  p <- ggplot(df_sub, aes(x = year, y = MM)) +
    geom_line(linewidth = 1.2, na.rm = TRUE) +
    geom_point(size = 2.5, na.rm = TRUE) +
    labs(
      title = paste("Maternal mortality in", country),
      x = "Year",
      y = "Deaths per 100,000 live births",
      caption = "Source: WHO"
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