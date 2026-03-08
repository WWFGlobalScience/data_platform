# ------------------------------------------------------------------------------
# Subnational Grand Corruption Trends— Baseline (GDL, governance dataset)
# Outputs:
#   1) GeoPackage of overlap polygons with grand corruption columns (grand_YYYY)
#   2) One figure per scape: grand corruption trends for overlapping subnational areas
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

gdl_scape_overlap_retained <- readRDS("data_inputs/gdl_scape_overlap_retained.rds")

# ------------------------------------------------------------------------------
# Load GDL subnational corruption data (SCI)
# ------------------------------------------------------------------------------
sess <- gdl_session("5YY0sJHmjCstN2EgcTWqsZuUo8_mzcMQVX_2xPMmv7I")
sess <- set_dataset(sess, "governance")
sess <- set_indicator(sess, "grand")

countries <- gdl_countries(sess)
sess <- set_countries(sess, c(countries$isocode3))

grand <- gdl_request(sess)
colnames(grand) <- tolower(colnames(grand))

# Reformat: one column per year (grand_YYYY)
grand_wide <- grand %>%
  arrange(iso_code, year) %>%
  select(gdlcode, region, year, grand) %>%
  pivot_wider(
    id_cols     = c(gdlcode, region),
    names_from  = year,
    values_from = grand,
    names_glue  = "{.value}_{year}"
  )

# ------------------------------------------------------------------------------
# Join overlap polygons with petty table
# ------------------------------------------------------------------------------
gdl_join <- gdl_scape_overlap_retained %>%
  left_join(select(grand_wide,-region), by = "gdlcode")

# ------------------------------------------------------------------------------
# Write output (25% only)
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")
gdl_prod_out <- gdl_join %>%
  rename(scape_id = ID)

filename <- paste0("Governance/subnat_corruption_grand_", run_date, ".csv")

write.csv(gdl_prod_out,paste0(filename))

# ------------------------------------------------------------------------------
# Write output to GeoPackage
# ------------------------------------------------------------------------------#
# Read in the overlapped areas from GPKG
gdl_scapes_overlap <- st_read(
  "data_inputs/gdl_scape_overlap_retained.gpkg",
  quiet = TRUE
) %>%
  st_make_valid()

gdl_scapes_overlap <- gdl_scapes_overlap %>% select(gdlcode,ID,geom)

gdl_prod_out2 <- gdl_scapes_overlap %>%
  left_join(gdl_join, by = c("gdlcode", "ID")) %>%
  rename(scape_id = ID)

gdl_prod_out2 <- st_transform(gdl_prod_out2, 4326)

filename2 <- paste0("Governance/subnat_corruption_grand_", run_date, ".gpkg")

st_write(gdl_prod_out2, paste0(filename2), layer = "subnational_grand_corruption", delete_layer = TRUE)

# ------------------------------------------------------------------------------
# Figures:grand trends within each scape (lines = overlapping GDL subnational areas)
# ------------------------------------------------------------------------------
fig_dir <- "Scapes_Grand_Corruption_Trends/03-06-2026"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

grand_long_scape <- gdl_prod_out %>%
  distinct(
    scape_id, scape_name, gdlcode, region,
    across(starts_with("grand_")),
    .keep_all = TRUE
  ) %>%
  pivot_longer(
    cols = starts_with("grand_"),
    names_to = "year",
    values_to = "corruption_index"
  ) %>%
  mutate(
    year = as.integer(str_extract(year, "\\d{4}")),
    corruption_index = as.numeric(corruption_index),
    gdl_name = str_squish(region)
  ) %>%
  filter(!is.na(corruption_index))

scape_list <- sort(unique(grand_long_scape$scape_id))

##Define palette based on the maximum number of subnational areas per scape
nb.cols <- max(tally(group_by(distinct(select(grand_long_scape,gdlcode,scape_id)),scape_id))$n)

#Extend an existing palette (e.g., Set3) to that number
library(RColorBrewer)
mycolors <- colorRampPalette(brewer.pal(8, "Set3"))(nb.cols)

#Plot all scapes
for (sid in scape_list) {
  
  df_sub <- grand_long_scape %>%
    filter(scape_id == sid)
  
  if (sum(!is.na(df_sub$corruption_index)) < 2) next
  
  scape_nm <- df_sub$scape_name[!is.na(df_sub$scape_name)][1]
  if (is.na(scape_nm) || scape_nm == "") scape_nm <- as.character(sid)
  
  safe_scape <- str_replace_all(scape_nm, "[^A-Za-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")

    out_png <- file.path(
    fig_dir,
    paste0("Grand_Corruption_GDL_Trends_Scape_", sid, "_", safe_scape, ".png")
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
      title = paste("Subnational Grand Corruption Trends in", scape_nm),
      subtitle = "Subnational areas overlapping with the operational landscape",
      x = "Year",
      y = "Index value",
      color = "Subnational areas",
      linetype = "Subnational areas",
      caption = "Source: Global Data Lab (GDL), governance dataset. Indicator: Grand Corruption Index."
    ) +
    scale_x_continuous(breaks = seq(1995, 2022, by = 1)) +
    scale_colour_manual(values = mycolors) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title    = element_text(size = 12, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 8, hjust = 0.5),
      axis.text     = element_text(color = "black"),
      axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
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

