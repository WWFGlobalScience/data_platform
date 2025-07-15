#########################
#People	Average income of small-scale food producers
# 2004 - 2021
# https://www.fao.org/in-action/rural-livelihoods-dataset-rulis/en/ > Indicator is > select all countries, all years, and national dissagregation
# Data Summarization: Average income (in 2017 dollars) of small scale food producers
# Average income of small scale food producers (in 2017 $USD) 2014-2020
# Data Output Description: table of countries with appended columns ISSP_2014 - ISSP_2020
library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)
library(janitor)
# Read country shapefile & get country list
shp_path <- "Prod_countries_EE.shp"
countries_sf <- st_read(shp_path)
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% unique()

# Load ISSP dataset
ISSP_wide <- read_csv("ISSP.csv") %>%
  filter(Country %in% country_names) %>%
  group_by(Country, Year) %>%
  pivot_wider(
    names_from = Year,
    values_from = Value,
    names_prefix = "ISSP_"
  ) %>%
  select(Country, starts_with("ISSP_"))

# Join with shapefile
people_data_issp <- countries_sf %>%
  left_join(ISSP_wide, by = c("COUNTRY" = "Country"))

# Reshape to long format for plotting
long_data <- people_data_issp %>%
  st_drop_geometry() %>%
  pivot_longer(cols = starts_with("ISSP_"), names_to = "year", values_to = "value") %>%
  mutate(
    year = as.numeric(str_remove(year, "ISSP_")),
    value = as.numeric(value)
  ) %>%
  drop_na(value)

# Create folder for plots
dir.create("ISSP_Plots", showWarnings = FALSE)

# Plot loop with correct y-axis label
for (country in unique(long_data$COUNTRY)) {
  df_sub <- long_data %>% filter(COUNTRY == country)
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), by = 1)) +
    labs(
      title = paste("Average Income of Small-Scale Food Producers in", country),
      x = "Year",
      y = "Average income (2017 USD)"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      legend.position = "none"
    )
  
  plot_path <- file.path("ISSP_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", country), "_ISSP.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}
