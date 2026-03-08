# People – Percentage of national income earned by the bottom 40% of income earners
# Source: https://www.worldbank.org/en/topic/poverty/brief/global-database-of-shared-prosperity THIS REQUIRES AN ACCOUNT
# Definition: Share of national income earned by the bottom 40%
library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)
library(janitor)
library(stringr)
library(ggplot2)

# Step 1: Read country shapefile and extract country names
shapefile_path <- "Spatial Data/Prod_countries_EE/Prod_countries_EE.shp"
countries_sf <- st_read(shapefile_path)
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% unique()

# Step 2: Read and filter World Bank Shared Prosperity data
PovertyGap_Data <- read_csv("pip.csv") %>%
  clean_names() %>%
  filter(
    reporting_level == "national",
    welfare_type == "income"
  ) %>%
  select(country_name, country_code, reporting_year, decile1, decile2, decile3, decile4) %>%
  mutate(bottom40_share = (decile1 + decile2 + decile3 + decile4) * 100) %>%
  select(-c(decile1, decile2, decile3, decile4))

# Step 3: Reshape to wide format
Decile4_wide <- PovertyGap_Data %>%
  filter(country_name %in% country_names) %>%
  pivot_wider(
    names_from = reporting_year,
    values_from = bottom40_share,
    names_prefix = "II_"
  ) %>%
  select(-country_name)            # drop name, keep country_code for join

# Step 4: Join with country shapefile and export as geopackage
people_data_ii <- countries_sf %>%
  left_join(Decile4_wide, by = c("ISO3" = "country_code"))

st_write(people_data_ii,
         "people_data_ii.gpkg",
         layer = "people_data_ii",
         delete_layer = TRUE)


test <- st_read("people_data_ii.gpkg") #Test to make sure the geopackage works


# Step 5: Reshape to long format for plotting
long_data <- people_data_ii %>%
  st_drop_geometry() %>%
  pivot_longer(
    cols = starts_with("II_"),
    names_to = "year",
    values_to = "value"
  ) %>%
  mutate(
    year = as.numeric(str_remove(year, "II_")),
    value = as.numeric(value)
  ) %>%
  drop_na(value)

# Step 6: Create output folder
dir.create("Income_Inequality_Plots", showWarnings = FALSE)
# Step 7: Loop and plot per country
for (country in unique(long_data$COUNTRY)) {
  df_sub <- long_data %>% filter(COUNTRY == country) %>% drop_na(value)
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = value, group = 1)) +
    geom_line(color = "#728423", linewidth = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), by = 1)) +
    labs(
      title = paste("Bottom 40% Income Share in", country),
      x = "Year",
      y = "Income share of bottom 40% (%)"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.text.x = element_text(angle = 90, vjust = 0.5),
      axis.line = element_line(color = "black"),
      legend.position = "none"
    )
  
  # Save plot
  plot_path <- file.path("Income_Inequality_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", country), "_II.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}


