library(readr)
library(dplyr)
library(ggplot2)
library(sf)
library(lubridate)
library(janitor)

# Step 1: Load country shapefile and extract names
shapefile_path <- "C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Prod_countries_EE.shp"
countries_sf <- st_read(shapefile_path)
country_names <- countries_sf %>% st_drop_geometry() %>% pull(COUNTRY) %>% unique()

# Step 2: Load and parse date correctly (m/dd/yyyy format)
victims_data <- read_csv("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/global_witness_led_10-10-24.csv") %>%
  mutate(
    date_parsed = mdy(date),  # Parse "m/dd/yyyy" format
    year = year(date_parsed)
  ) %>%
  filter(!is.na(year), country %in% country_names)

# Step 3: Summarize by country and year
ps_by_year_country <- victims_data %>%
  group_by(country, year) %>%
  summarise(PS = sum(number_of_victims, na.rm = TRUE), .groups = "drop") %>%
  arrange(country, year)

# Step 4: Generate plots
dir.create("Defenders_Killed_Plots", showWarnings = FALSE)

for (ctry in unique(ps_by_year_country$country)) {
  df_sub <- ps_by_year_country %>% filter(country == ctry)
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = PS)) +
    geom_line(color = "#728423", linewidth = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    geom_text(aes(label = PS), vjust = -0.8, size = 4) +
    scale_x_continuous(breaks = sort(unique(df_sub$year))) +
    labs(
      title = paste("Environmental Defenders Killed in", ctry),
      x = "Year",
      y = "Number of victims"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank()
    )
  
  ggsave(
    filename = file.path("Defenders_Killed_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", ctry), "_DefendersKilled.png")),
    plot = p, width = 9, height = 5.5, dpi = 300
  )
}
