# ------------------------------------------------------------------------------
# Perceived levels of public sector corruption at the national scale
# Source: Transparency International
# URL: https://www.transparency.org/en/cpi
# Indicator: CPI_YYYY = Corruption Perceptions Index score (0-100)
# Years: 2012-2024
# Scale: 0 = highly corrupt; 100 = very clean
# Output A: GeoPackage (countries layer with appended CPI_YYYY columns)
# Output B: Time-series figures for each country
# ------------------------------------------------------------------------------

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(stringr)
library(janitor)
library(ggplot2)

# ------------------------------------------------------------------------------
# Load production countries shapefile
# ------------------------------------------------------------------------------
shp_path <- "data_inputs/Prod_countries_EE/Prod_countries_EE.shp"
countries_sf <- st_read(shp_path, quiet = TRUE)

# Extract unique iso3 names for filtering
iso_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(ISO3) %>% 
  unique()

# ------------------------------------------------------------------------------
# Load and process Corruption Perceptions Index data
# ------------------------------------------------------------------------------
# Note: Skip first row which contains header info
cpi_raw <- read_excel("Governance/Data/CPI2024-Results-and-trends.xlsx", 
                      sheet = "CPI Timeseries 2012 - 2024", 
                      skip = 1)

# Clean column names and rename country column
cpi_clean <- cpi_raw %>%
  clean_names()

# Filter by 1S03 to production countries only
cpi_filtered <- cpi_clean %>%
  filter(iso3 %in% iso_names)

# Join to custom country list for production
cpi_prod_out <- select(countries_sf,COUNTRY,ISO3,geometry) %>% 
  left_join(cpi_filtered, by=c("ISO3" = "iso3"))

# ------------------------------------------------------------------------------
# Write output to CSV
# ------------------------------------------------------------------------------
run_date <- format(Sys.Date(), "%Y_%m_%d")

filename <- paste0("Governance/national_cpi_", run_date, ".csv")

cpi_prod_out2 <- cpi_prod_out %>%
  st_drop_geometry()

write.csv(cpi_prod_out2,paste0(filename))

# ------------------------------------------------------------------------------
# Write output to GeoPackage
# ------------------------------------------------------------------------------#
# Read in the overlapped areas from GPKG
cpi_prod_out <- st_transform(cpi_prod_out, 4326)

filename2 <- paste0("Governance/national_cpi_", run_date, ".gpkg")

st_write(cpi_prod_out, paste0(filename2), layer = "national_corruption_perceptions_index", delete_layer = TRUE)

# ------------------------------------------------------------------------------
# Figures: National CPI trends within each country (use long format)
# ------------------------------------------------------------------------------

# Create output folder
#dir.create(paste0("Governance/CPI_Plots"))
dir.create(paste0("Governance/CPI_Plots/",run_date))

fig_dir <- paste0("Governance/CPI_Plots/",run_date)

# Reshape to long format for visualization
cpi_long <- cpi_prod_out2 %>%
  select(COUNTRY,ISO3, starts_with("cpi_score_")) %>%
  pivot_longer(
    cols = starts_with("cpi_score_"),
    names_to = "year",
    names_prefix = "cpi_score_",
    values_to = "cpi_score"
  ) %>%
  rename(
    iso3 = ISO3,
    country = COUNTRY
  ) %>%
  mutate(year = as.integer(year)) %>%
  arrange(country, year)

# ------------------------------------------------------------------------------
# FIGURES: Time-series plots for each country
# ------------------------------------------------------------------------------

# Helper function to create safe file names
safe_name <- function(x) gsub("[^a-zA-Z0-9]", "_", x)

# Use long format data for plotting
plot_data <- cpi_long %>%
  drop_na(cpi_score)

plot_data$year <- as.integer(plot_data$year)

# Generate a plot for each country
for (country in unique(plot_data$country)) {
  
  df_sub <- plot_data %>% filter(country == !!country)
  
  # Skip if fewer than 1 observations
  if (nrow(df_sub) < 1) next
  
  # Use actual years present in the data for x-axis breaks
  p <- ggplot(df_sub, aes(x = as.numeric(year), y = cpi_score)) +
    geom_line(color = "#728423", linewidth = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    geom_text(aes(label = cpi_score), vjust = -0.8, size = 3.5) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), by = 1)) +
    scale_y_continuous(breaks = scales::breaks_pretty(),
                       limits = c(0, NA),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Corruption Perceptions Index in", country),
      x = "Year",
      y = "CPI Score (0–100)",
      caption = "Source: Transparency International"
    ) +
    theme_minimal(base_size = 13) + 
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.title.x = element_text(face="bold",margin = margin(t = 10, unit = "pt")),
      axis.title.y = element_text(face="bold",size = 13),
      axis.text = element_text(size = 12, color = "black"),
      axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5),
      axis.line = element_line(color = "black", linewidth = 0.4),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      plot.margin = margin(10, 10, 10, 10),
      legend.position = "none",
      plot.caption = element_text(size=10, face = "italic", hjust=0)
    )
  
  # Save plot
  plot_path <- file.path(fig_dir, paste0(safe_name(country), "_CPI.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}
