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

# ------------------------------------------------------------------------------
# figures ADM1 poverty % of households within each Scape
# ------------------------------------------------------------------------------
fig_dir <- "Scapes_ADM1_Trends"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Pivot wide -> long for plotting
poverty_long_scape <- adm1_prod_25_out %>%
  st_drop_geometry() %>%
  # De-duplicate potential multipart intersections
  distinct(
    scape_id, scape_name, iso3, name,
    across(starts_with("iwipov35_")),
    .keep_all = TRUE
  ) %>%
  pivot_longer(
    cols = starts_with("iwipov35_"),
    names_to = "year",
    values_to = "poverty_pct"
  ) %>%
  mutate(
    year = as.integer(str_extract(year, "\\d{4}")),
    poverty_pct = as.numeric(poverty_pct),
    adm1_name = str_squish(name)
  )

scape_list <- sort(unique(poverty_long_scape$scape_id))

for (sid in scape_list) {
  
  df_sub <- poverty_long_scape %>%
    filter(scape_id == sid)
  
  # Skip scapes without enough non-missing values to draw a line
  if (sum(!is.na(df_sub$poverty_pct)) < 2) next
  
  scape_nm <- df_sub$scape_name[!is.na(df_sub$scape_name)][1]
  if (is.na(scape_nm) || scape_nm == "") scape_nm <- as.character(sid)
  
  safe_scape <- str_replace_all(scape_nm, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(
    fig_dir,
    paste0("IWI_Poverty_ADM1_Trends_Scape_", sid, "_", safe_scape, ".png")
  )
  
  # Drop NAs for line drawing and ensure correct ordering
  df_line <- df_sub %>%
    filter(!is.na(poverty_pct)) %>%
    arrange(adm1_name, year)
  
 
  p <- ggplot() +
    geom_line(
      data = df_line,
      aes(
        x = year,
        y = poverty_pct,
        group = adm1_name,
        color = adm1_name,
        linetype = adm1_name
      ),
      linewidth = 1.0,
      alpha = 0.8
    ) +
    geom_point(
      data = df_line,
      aes(
        x = year,
        y = poverty_pct,
        color = adm1_name
      ),
      size = 1.6,
      alpha = 0.8
    ) +
    labs(
      title = paste("Subnational Poverty Trends in", scape_nm),
      subtitle = "Administrative Level 1 (ADM1) units overlapping the production landscape by ≥25%",
      x = "Year",
      y = "Percent (%) of households",
      color = "ADM1 unit",
      linetype = "ADM1 unit",
      caption = "Source: Global Data Lab (GDL). IWI-based poverty proxy (% of households with IWI < 35)."
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title    = element_text(size = 12, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 11, hjust = 0.5),
      axis.text     = element_text(color = "black"),
      axis.line     = element_line(color = "black"),
      legend.position = "right",
      legend.title  = element_text(size = 11),
      legend.text   = element_text(size = 9),
      panel.grid    = element_blank(),
      plot.caption  = element_text(size = 9, hjust = 0),
      plot.caption.position = "plot",
      plot.margin   = margin(t = 18, r = 20, b = 24, l = 18, unit = "pt")
    )
  
  
  ggsave(out_png, p, width = 7.5, height = 4.5, dpi = 300, bg = "white")
}

