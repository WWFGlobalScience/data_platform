# ------------------------------------------------------------------------------
# Subnational Corruption Index (SCI) — Baseline (GDL, governance dataset)
# Outputs:
#   1) GeoPackage of overlap polygons with SCI columns (sci_YYYY)
#   2) One figure per scape: SCI trends for overlapping subnational areas
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(stringr)
library(tidyr)
library(gdldata)
library(ggplot2)
library(scales)

# ------------------------------------------------------------------------------
# Load GDL subnational areas that overlap with landscapes (at least 25% of scape)
# ------------------------------------------------------------------------------
gdl_scape_overlap_25 <- st_read(
  "scape_GDL_overlap25/scape_GDL_overlap25.shp",
  quiet = TRUE
) %>%
  rename(
    iso_code         = iso_cod,
    scape_name       = scap_nm,
    scape_id         = scape_d,
    scape_area_m2    = scp_r_2,
    overlap_area_m2  = ovrl__2,
    pct_overlap      = pct_vrl
  )

# ------------------------------------------------------------------------------
# Load GDL subnational corruption data (SCI)
# ------------------------------------------------------------------------------
sess <- gdl_session("5YY0sJHmjCstN2EgcTWqsZuUo8_mzcMQVX_2xPMmv7I")
sess <- set_dataset(sess, "governance")
sess <- set_indicator(sess, "fullsci")


countries <- gdl_countries(sess)
sess <- set_countries(sess, c(countries$isocode3))

sci <- gdl_request(sess)
colnames(sci) <- tolower(colnames(sci))

# Reformat: one column per year (sci_YYYY)
sci_wide <- sci %>%
  arrange(iso_code, year) %>%
  # keep only join key + year + value + region label for plotting
  select(gdlcode, region.x, year, fullsci) %>%
  pivot_wider(
    id_cols     = c(gdlcode, region.x),
    names_from  = year,
    values_from = fullsci,
    names_glue  = "{.value}_{year}"
  )

# ------------------------------------------------------------------------------
# Join overlap polygons with SCI table
# ------------------------------------------------------------------------------
gdl_join <- gdl_scape_overlap_25 %>%
  left_join(sci_wide, by = "gdlcode")

# ------------------------------------------------------------------------------
# Write output (25% only)
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")

gdl_out <- gdl_join %>%
  st_make_valid() %>%
  st_transform(4326)

gpkg_name <- paste0("subnat_corruption_sci_25_pct_", run_date, ".gpkg")

st_write(
  gdl_out,
  gpkg_name,
  layer = "gdl_corruption_sci_25",
  delete_layer = TRUE
)

# ------------------------------------------------------------------------------
# Figures: SCI trends within each scape (lines = overlapping GDL subnational areas)
# ------------------------------------------------------------------------------
fig_dir <- "Scapes_GDL_Corruption_SCI_Trends"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

sci_long_scape <- gdl_out %>%
  st_drop_geometry() %>%
  distinct(
    scape_id, scape_name, gdlcode, region.x,
    across(starts_with("sci_")),
    .keep_all = TRUE
  ) %>%
  pivot_longer(
    cols = starts_with("fullsci_"),
    names_to = "year",
    values_to = "corruption_index"
  ) %>%
  mutate(
    year = as.integer(str_extract(year, "\\d{4}")),
    corruption_index = as.numeric(corruption_index),
    gdl_name = str_squish(region.x)
  )

scape_list <- sort(unique(sci_long_scape$scape_id))

for (sid in scape_list) {
  
  df_sub <- sci_long_scape %>%
    filter(scape_id == sid)
  
  if (sum(!is.na(df_sub$corruption_index)) < 2) next
  
  scape_nm <- df_sub$scape_name[!is.na(df_sub$scape_name)][1]
  if (is.na(scape_nm) || scape_nm == "") scape_nm <- as.character(sid)
  
  safe_scape <- str_replace_all(scape_nm, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  out_png <- file.path(
    fig_dir,
    paste0("SCI_GDL_Trends_Scape_", sid, "_", safe_scape, ".png")
  )
  
  df_line <- df_sub %>%
    filter(!is.na(corruption_index)) %>%
    arrange(gdl_name, year)
  
  p <- ggplot() +
    geom_line(
      data = df_line,
      aes(
        x = year,
        y = corruption_index,
        group = gdl_name,
        color = gdl_name,
        linetype = gdl_name
      ),
      linewidth = 1.0,
      alpha = 0.8
    ) +
    geom_point(
      data = df_line,
      aes(x = year, y = corruption_index, color = gdl_name),
      size = 1.6,
      alpha = 0.8
    ) +
    labs(
      title = paste("Subnational Corruption Trends (SCI) in", scape_nm),
      subtitle = "Subnational areas overlapping with at least 25% of operational landscape",
      x = "Year",
      y = "Index value",
      color = "Subnational areas",
      linetype = "Subnational areas",
      caption = "Source: Global Data Lab (GDL), governance dataset. Indicator: Subnational Corruption Index (SCI)."
    ) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 6)) +
    theme_minimal(base_size = 13) +
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

