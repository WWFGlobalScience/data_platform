library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(readxl)
library(lubridate)
library(janitor)
library(stringr)
library(showtext)

# Optional: Add font for cleaner plots
font_add_google("Open Sans", "opensans")
showtext_auto()

# Read shapefile and extract country list
shp_path <- "Prod_countries_EE.shp"
countries_sf <- st_read(shp_path)
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% unique()

# Load and clean WASH data
people_data_mwash <- read_csv("WASH.csv") %>%
  rename(country = Location) %>%
  mutate(year = as.character(Period)) %>%
  filter(country %in% country_names, Dim1 == "Both sexes", year == "2019") %>%
  select(country, value = Value)

# Clean country names for matching if needed
people_data_mwash <- people_data_mwash %>%
  mutate(country = str_trim(country))

# Create output folder
dir.create("MWASH_Plots", showWarnings = FALSE)

# Plot one dot per country
for (i in 1:nrow(people_data_mwash)) {
  df_sub <- people_data_mwash[i, ]
  
  p <- ggplot(df_sub, aes(x = country, y = value)) +
    geom_point(color = "#728423", size = 4.5) +
    geom_text(aes(label = round(value, 1)), vjust = -1, size = 5) +
    labs(
      title = paste("Mortality from Unsafe Water & Sanitation in", df_sub$country, "(2019)"),
      x = NULL,
      y = "Deaths per 100,000 people"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.line.y = element_line(color = "black"),
      axis.line.x = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "none"
    )
  
  plot_path <- file.path("MWASH_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", df_sub$country), "_MWASH_2019.png"))
  ggsave(plot_path, plot = p, width = 6, height = 5, dpi = 300)
}
