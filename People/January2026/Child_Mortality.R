# ------------------------------------------------------------------------------
# Child mortality under age 5 (per 1,000 live births) — National (GDL Health v2.1)
# Variable: u5mort
# Data link: https://globaldatalab.org/asset/600/Health%20Data%20v2.1.csv
# Outputs:
#  A) GeoPackage: countries layer with u5mort_{year}_rto_GDL columns
#  B) One time-series figure per country
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(scales)

# ------------------------------------------------------------------------------
# STEP 1: Load production countries
# ------------------------------------------------------------------------------
countries_sf <- st_read("Spatial Data/Prod_countries_EE/Prod_countries_EE.shp", quiet = TRUE) %>%
  st_make_valid()

# ------------------------------------------------------------------------------
# STEP 2: Load health data
# ------------------------------------------------------------------------------
health <- read_csv("Health Data v2.1.csv", show_col_types = FALSE)

# ------------------------------------------------------------------------------
# STEP 3: Create wide table (one row per country)
# ------------------------------------------------------------------------------
child_mort_wide <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, u5mort) %>%
  mutate(
    year   = as.integer(year),
    u5mort = as.numeric(u5mort)
  ) %>%
  pivot_wider(
    names_from  = year,
    values_from = u5mort,
    names_glue  = "{.value}_{year}_rto_GDL"
  )

child_mort_prod <- child_mort_wide %>%
  filter(isocode3 %in% countries_sf$ISO3)

# Optional wide CSV export
out_date <- Sys.Date()
dir.create("People", showWarnings = FALSE, recursive = TRUE)
write_csv(child_mort_prod, file.path("People", paste0("child_mort_", out_date, ".csv")))

# ------------------------------------------------------------------------------
# STEP 4: Join to sf + export GeoPackage
# ------------------------------------------------------------------------------
child_mort_sf <- countries_sf %>%
  left_join(child_mort_prod, by = c("ISO3" = "isocode3")) %>%
  st_transform(4326)

out_gpkg <- file.path("People", paste0("child_mort_", out_date, ".gpkg"))
st_write(child_mort_sf, dsn = out_gpkg, layer = "child_mort_u5", delete_layer = TRUE, quiet = TRUE)

# ------------------------------------------------------------------------------
# STEP 5: Figures (one per country)
# ------------------------------------------------------------------------------
fig_dir <- file.path("Child Mortality Figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

child_mort_long <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, u5mort) %>%
  mutate(
    year   = as.integer(year),
    u5mort = as.numeric(u5mort),
    label  = ifelse(is.na(u5mort), NA_character_, sprintf("%.1f", u5mort))
  ) %>%
  filter(isocode3 %in% countries_sf$ISO3) %>%
  arrange(isocode3, year)

iso_list <- sort(unique(child_mort_long$isocode3))

for (iso in iso_list) {
  
  df_sub <- child_mort_long %>% filter(isocode3 == iso)
  
  if (sum(!is.na(df_sub$u5mort)) < 2) next
  
  country_nm <- df_sub$country[!is.na(df_sub$country)][1]
  if (is.na(country_nm) || country_nm == "") country_nm <- iso
  
  safe_country <- str_replace_all(country_nm, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(fig_dir, paste0(iso, "_", safe_country, "_ChildMort_U5.png"))
  
  p <- ggplot(df_sub, aes(x = year, y = u5mort)) +
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
      title = paste0("Child mortality (under 5) in ", country_nm),
      x = "Year",
      y = "Deaths per 1,000 live births"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_classic(base_size = 13) +
    theme(
      plot.title = element_text(size = 15, face = "bold", hjust = 0.5),
      axis.text  = element_text(color = "black")
    )
  
  ggsave(out_png, plot = p, width = 8.5, height = 5.2, dpi = 300)
}

