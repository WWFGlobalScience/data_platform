# Number of conflict events within a country per year ACLED
# Data link: https://acleddata.com/data-export-tool/
# ACLED_YYYY per year per country 


library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(DescTools)

# Load country shapefile. Extract the unique COUNTRY names from the shapefile attribute table
prod_countries <- st_read("data_inputs/Prod_countries_EE/Prod_countries_EE.shp")
ISO_conv <- d.countries %>% select(code,a3)
prod_countries <- prod_countries %>% left_join(ISO_conv, by = c("ISO3" = "a3"))

iso_names <- st_drop_geometry(prod_countries) %>% pull(ISO3) %>% unique()

# Read and process ACLED data
acled_data <- read_csv("Governance/Data/1997-05-01-2025-05-29.csv")

acled_data_summarized <- acled_data %>%
  count(country, iso, year, name = "ACLED_events") %>%
  left_join(ISO_conv,by=c("iso" = "code")) %>%
  select(-iso) %>%
  rename(COUNTRY = country,
         ISO3 = a3)

acled_data_wwf <- acled_data_summarized %>%
  filter(ISO3 %in% iso_names)
  
# Reformat: one column per year (acled_YYYY)
acled_wide <- acled_data_selected %>%
  arrange(ISO3, year) %>%
  # keep only join key + year + value + region label for plotting
  select(COUNTRY, ISO3, year, ACLED_events) %>%
  pivot_wider(
    id_cols     = c(COUNTRY,ISO3),
    names_from  = year,
    values_from = ACLED_events,
    names_glue  = "{.value}_{year}"
  )

# ------------------------------------------------------------------------------
# Write output to CSV
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")

filename <- paste0("Governance/acled_conflict_national_", run_date, ".csv")

write.csv(acled_wide,paste0(filename))

# ------------------------------------------------------------------------------
# Write output to GeoPackage
# ------------------------------------------------------------------------------#
# Read in the overlapped areas from GPKG
prod_countries_geo <- prod_countries %>% select(ISO3,geometry)

acled_prod_out <- prod_countries_geo %>%
  left_join(acled_wide, by = c("ISO3"))

acled_prod_out <- st_transform(acled_prod_out, 4326)

filename2 <- paste0("Governance/acled_conflict_national_", run_date, ".gpkg")

st_write(acled_prod_out, paste0(filename2), layer = "conflict_events", delete_layer = TRUE)

# ------------------------------------------------------------------------------
# Figures: Conflict trends within each country (use long format)
# ------------------------------------------------------------------------------

# Create output folder
dir.create(paste0("Governance/ACLED_Plots"))
dir.create(paste0("Governance/ACLED_Plots/",run_date))

fig_dir <- paste0("Governance/ACLED_Plots/",run_date)

# Plot loop
for (ctry in unique(acled_data_wwf$COUNTRY)) {
  df_sub <- acled_data_wwf %>%
    filter(COUNTRY == ctry) %>%
    mutate(
      year = as.numeric(year),
      value = as.integer(ACLED_events)
    ) %>%
    drop_na(year, ACLED_events)
  
  if (nrow(df_sub) == 0) next
  
  out_png <- file.path(
    fig_dir,
    paste0("ACLED_", str_trim(ctry),".png")
  )
  
  p <- ggplot(df_sub, aes(x = year, y = ACLED_events)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    geom_text(aes(label = value), vjust = -0.8, size = 3.5) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), by = 1)) +
    scale_y_continuous(breaks = scales::breaks_pretty(),
                       limits = c(0, NA),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Conflict Events in", ctry),
      x = "Year",
      y = "Number of conflict events",
      caption = "Source: Armed Conflict Location & Event Data (ACLED) conflict event dataset from May 1, 1997 - May 29, 2025"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.title.y = element_text(face="bold", vjust = 0.5),
      axis.title.x = element_text(face="bold",margin = margin(t = 10, unit = "pt")),
      axis.text = element_text(color = "black"),
      axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      plot.caption = element_text(size=10, face = "italic", hjust=0)
    )
  
  ggsave(out_png, plot = p, width = 9, height = 5.5, dpi = 300)
}

