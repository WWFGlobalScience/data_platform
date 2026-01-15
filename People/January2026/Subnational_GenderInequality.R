# ------------------------------------------------------------------------------
# Subnational measure of gender inequality using the Subnational Gender Development
# Index developed and maintained by Global Data Lab
# Data is retrieved from the GDL using an API access token - G95BikZsJG5NnUZbfPczkQ9nTUwSIHKz3Z6ukk-De44
# ------------------------------------------------------------------------------
library(sf)
library(dplyr)
library(stringr)
library(readr)
library(tidyr)
library(rnaturalearth)
library(countrycode)
library(units)
library(gdldata)

install.packages("remotes")
remotes::install_github("ropensci/rnaturalearthhires")
library(rnaturalearthhires)

# ------------------------------------------------------------------------------
# Load and validate prod_scapes_EE sf object
# ------------------------------------------------------------------------------
# prod_scapes_EE <- st_read(
#   "data_inputs/Prod_scapes_EE_wflags/Prod_scapes_EE.shp",
#   quiet = TRUE
# ) %>%
#   st_make_valid() %>%
#   mutate(
#     scape_id   = ID,     # 
#     scape_name = Name    # rename now to avoid collisions later
#   )
# 
# # ------------------------------------------------------------------------------
# # Load GDL shapefile for the entire globe using the subnational units that are included for this dataset
# # ------------------------------------------------------------------------------
# gdl_bound <- st_read("data_inputs/GDL Shapefiles V6.6/GDL Shapefiles V6.6 large.shp") %>%
#   st_transform(st_crs(prod_scapes_EE)) %>%
#   st_make_valid()

# # Keep only what we need and create ISO3 for joining to GDL
# gdl_bound_clean <- gdl_bound %>%
#   transmute(
#     iso_a2 = iso_a2,
#     iso3   = countrycode(iso_a2, origin = "iso2c", destination = "iso3c"),
#     name   = name,
#     geometry = geometry
#   ) %>%
#   filter(!is.na(iso3))

# ------------------------------------------------------------------------------
# Load GDL subnational areas that overlap with landscapes (at least 25% of scape)
# ------------------------------------------------------------------------------

gdl_scape_overlap_25 <- st_read(
  "data_inputs/scape_GDL_overlap25.shp",
  quiet=TRUE
  ) %>%
  st_make_valid()

gdl_scape_overlap_25 <- gdl_scape_overlap_25 %>%
  rename(iso_code = iso_cod,
         scape_name = scap_nm,
         scape_id = scape_d,
         scape_area_m2 = scp_r_2,
         overlap_area_m2 = ovrl__2,
         pct_overlap = pct_vrl)

# ------------------------------------------------------------------------------
# Load GDL subnational gender development data
# ------------------------------------------------------------------------------

sess <- gdl_session("G95BikZsJG5NnUZbfPczkQ9nTUwSIHKz3Z6ukk-De44")
sess <- set_dataset(sess, 'shdi')
sess <- set_indicator(sess, 'sgdi')

countries <- gdl_countries(sess)

sess <- set_countries(sess, c(countries$isocode3))
sgdi <- gdl_request(sess)

# Reformat the data for joining
# NOTE: Use ISO3 + region name as join key to ADM1 polygons

colnames(sgdi) <- tolower(colnames(sgdi))

sgdi_wide <- sgdi %>%
  arrange(
    iso_code, year
  ) %>%
  select(
    -continent,-level,-country,-iso_code,-region
  ) %>%
  pivot_wider(
    names_from  = year,
    values_from = sgdi,
    names_glue  = "{.value}_{year}"
  )

# ------------------------------------------------------------------------------
# Join GDL subnational polygons with SGDI table
# ------------------------------------------------------------------------------
gdl_join <- gdl_scape_overlap_25 %>%
  left_join(sgdi_wide, by = c("gdlcode"))

# ------------------------------------------------------------------------------
# Intersect GDL with production landscapes
# ------------------------------------------------------------------------------
# gdl_prod_int <- st_intersection(
#   gdl_bound_joined,
#   prod_scapes_EE %>% select(scape_id, scape_name, Area_km2)
# ) %>%
#   mutate(int_area = st_area(geometry)) %>%
#   mutate(Area_m2 = as.numeric(Area_km2) * 1000000)
# 
# 
# # Percent of ADM1 that overlaps the production landscape
# gdl_prod_long <- gdl_prod_int %>%
#   mutate(
#     pct_prod_in_gdl = round(as.numeric(int_area / Area_m2) * 100, 2)
#   )
# 
# # ------------------------------------------------------------------------------
# # Filter ADM1 units that overlap with production landscapes (at least 25% of landscape)
# # ------------------------------------------------------------------------------
# gdl_prod_25 <- gdl_prod_long %>%
#   filter(pct_prod_in_gdl >= 25)

# ------------------------------------------------------------------------------
# Check accuracy by mapping production landscapes over GDL boundaries - by country,
# otherwise takes a long time to map
# ------------------------------------------------------------------------------
library(ggplot2)

test <- filter(gdl_join, iso_cod == "COD")
prod_test <- filter(prod_scapes_EE, Country == "Democratic Republic of the Congo")
base <- filter (gdl_sf, iso_code == "COD")

ggplot() +
  geom_sf(data = base, color="gray", alpha=1.0) +
  geom_sf(data = test, aes(fill = pct_vrl)) +
  geom_sf(data = prod_test, color="magenta", alpha=0.4) +
  coord_sf()

# ------------------------------------------------------------------------------
# Write output (25% only)
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")
gdl_prod_25_out <- gdl_join %>%
  st_make_valid() %>%
  st_transform(4326)

gpkg_name <- paste0("sgdi_25_pct_", run_date, ".gpkg")

st_write(
  gdl_prod_25_out,
  gpkg_name,
  layer = "gdl_sgdi25",
  delete_layer = TRUE
)

# ------------------------------------------------------------------------------
# figures GDL SGDI within each Scape
# ------------------------------------------------------------------------------
fig_dir <- "Scapes_GDL_Trends"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Pivot wide -> long for plotting
sgdi_long_scape <- gdl_join %>%
  st_drop_geometry() %>%
  # De-duplicate potential multipart intersections
  distinct(
    scape_id, scape_name, gdlcode, region,
    across(starts_with("sgdi_")),
    .keep_all = TRUE
  ) %>%
  pivot_longer(
    cols = starts_with("sgdi_"),
    names_to = "year",
    values_to = "sgdi"
  ) %>%
  mutate(
    year = as.integer(str_extract(year, "\\d{4}")),
    sgdi = as.numeric(sgdi),
    gdl_name = str_squish(region)
  )

scape_list <- sort(unique(sgdi_long_scape$scape_id))

for (sid in scape_list) {
  
  df_sub <- sgdi_long_scape %>%
    filter(scape_id == sid)
  
  # Skip scapes without enough non-missing values to draw a line
  if (sum(!is.na(df_sub$sgdi)) < 2) next
  
  scape_nm <- df_sub$scape_name[!is.na(df_sub$scape_name)][1]
  if (is.na(scape_nm) || scape_nm == "") scape_nm <- as.character(sid)
  
  safe_scape <- str_replace_all(scape_nm, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(
    fig_dir,
    paste0("SGDI_GenderInequality_GDL_Trends_Scape_", sid, "_", safe_scape, ".png")
  )
  
  # Drop NAs for line drawing and ensure correct ordering
  df_line <- df_sub %>%
    filter(!is.na(sgdi)) %>%
    arrange(gdl_name, year)
  
 
  p <- ggplot() +
    geom_line(
      data = df_line,
      aes(
        x = year,
        y = sgdi,
        group = gdl_name,
        color = gdl_name,
        linetype = gdl_name
      ),
      linewidth = 1.0,
      alpha = 0.8
    ) +
    geom_point(
      data = df_line,
      aes(
        x = year,
        y = sgdi,
        color = gdl_name
      ),
      size = 1.6,
      alpha = 0.8
    ) +
    labs(
      title = paste("Subnational Trends in Gender Inequality", scape_nm),
      subtitle = "Subnational areas overlapping with at least 25% of operational landscape",
      x = "Year",
      y = "Subnational Gender Development Index",
      color = "Subnational areas",
      linetype = "Subnational areas",
      caption = "Source: Global Data Lab (GDL). Subnational Gender Development Index (SGDI) is calculated from a large collection of household survey data and used here as a measure of gender inequality"
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title    = element_text(size = 12, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 8, hjust = 0.5),
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

