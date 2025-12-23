library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

# Load shapefile
prod_countries <- st_read("Prod_countries_EE.shp")
country_names <- st_drop_geometry(prod_countries) %>% pull(COUNTRY) %>% unique()

# Read and process ACLED data
acled_data <- read_csv("1997-05-01-2025-05-29.csv") %>%
  filter(country %in% country_names) %>%
  count(country, year, name = "ACLED_events") %>%
  rename(COUNTRY = country)

# Convert to long format for plotting (already in long form, just rename)
long_data <- acled_data %>%
  rename(value = ACLED_events)

# Create output folder
dir.create("ACLED_Plots", showWarnings = FALSE)

# Plot loop
for (ctry in unique(long_data$COUNTRY)) {
  df_sub <- long_data %>%
    filter(COUNTRY == ctry) %>%
    mutate(
      year = as.numeric(year),
      value = as.numeric(value)
    ) %>%
    drop_na(year, value)
  
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    geom_text(aes(label = value), vjust = -0.8, size = 4) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), by = 1)) +
    labs(
      title = paste("Conflict Events in", ctry),
      x = "Year",
      y = "Number of conflict events"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank()
    )
  
  plot_path <- file.path("ACLED_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", ctry), "_ACLED.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}
