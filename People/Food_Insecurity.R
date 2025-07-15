# People – Prevalence of moderate or severe food insecurity in the population
# Source: https://www.fao.org/faostat/en/#data/FS
# Definition: Percentage of people experiencing moderate or severe food insecurity (based on FIES)
# Years: Varies by country; typically 2014–2022

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)
library(janitor)
library(stringr)
library(ggplot2)


# Step 1: Read shapefile and extract country names
shapefile_path <- "C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Prod_countries_EE.shp"
countries_sf <- st_read(shapefile_path)
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% unique()

# Step 2: Load FAOSTAT FIES data and filter
FIS_wide <- read_csv("FAOSTAT_data_en_6-17-2025.csv") %>%
  filter(
    `Item Code` == 210091,     # All population
    Element == "Value"         # Actual values
  ) %>%
  rename(country = Area) %>%
  filter(country %in% country_names) %>%
  select(country, Value, Year) %>%
  pivot_wider(names_from = Year, values_from = Value, names_prefix = "FIS_")

# Step 3: Join with shapefile
people_data_fis <- countries_sf %>%
  left_join(FIS_wide, by = c("COUNTRY" = "country"))

# Step 4: Reshape to long format for plotting
long_data <- people_data_fis %>%
  st_drop_geometry() %>%
  pivot_longer(cols = starts_with("FIS_"), names_to = "year", values_to = "value") %>%
  mutate(
    year = str_remove(year, "FIS_"),
    value = as.numeric(value)
  ) %>%
  drop_na(value)

# Step 5: Create output folder
dir.create("Food_Insecurity_Plots", showWarnings = FALSE)

# Step 6: Plot bar chart per country
for (country in unique(long_data$COUNTRY)) {
  df_sub <- long_data %>% filter(COUNTRY == country)
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_col(fill = "#728423") +
    geom_text(aes(label = round(value, 1)), vjust = -0.5, size = 4) +
    labs(
      title = paste("Prevalence of Food Insecurity in", country),
      x = "Year",
      y = "% experiencing food insecurity"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      legend.position = "none"
    )
  
  plot_path <- file.path("Food_Insecurity_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", country), "_FIS.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}
