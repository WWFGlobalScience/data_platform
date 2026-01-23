# ------------------------------------------------------------------------------
# Subnational measure of gender inequality using the Subnational Gender Development
# Index developed and maintained by Global Data Lab
# Data is retrieved from the GDL using an API access token - G95BikZsJG5NnUZbfPczkQ9nTUwSIHKz3Z6ukk-De44
# ------------------------------------------------------------------------------
library(dplyr)
library(stringr)
library(readr)
library(tidyr)
library(countrycode)
library(units)
library(gdldata)

# ------------------------------------------------------------------------------
# Load GDL subnational areas that overlap with landscapes (at least 25% of scape)
# ------------------------------------------------------------------------------

gdl_scape_overlap_25 <- read_rds("data_inputs/gdl_scape_overlap_25.rds")

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
# Write output (25% only) to a csv that should be joined to the GDL base layer in ArcGIS for mapping on the platform
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")
gdl_prod_25_out <- gdl_join %>%
  select(-region,-scape_name,-country)

filename <- paste0("People/January2026/sgdi_25_pct_", run_date, ".csv")

write.csv(gdl_prod_25_out,paste0(filename))

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

