# People – Tenure Security (% of adult population perceiving land rights as secure)
# Source: data_comparison.csv
# Years: 2020 and 2024

library(sf)
library(dplyr)
library(readr)
library(ggplot2)
library(stringr)
library(tidyr)

# Step 1: Load shapefile and extract country names
shapefile_path <- "Prod_countries_EE.shp"
prod_countries <- st_read(shapefile_path)
country_names <- st_drop_geometry(prod_countries) %>% pull(COUNTRY) %>% unique()

# Step 2: Read tenure data
tenure_all <- read_csv("data_comparison.csv") %>%
  filter(Country %in% country_names) %>%
  rename(country = Country)

# Step 3: Join to spatial data
prod_countries <- prod_countries %>%
  left_join(tenure_all, by = c("COUNTRY" = "country"))

# Step 4: Export GeoPackage
prod_countries <- st_transform(prod_countries, 4326)
st_write(prod_countries, "Governance_Tenure.gpkg", layer = "tenure_indicators", delete_layer = TRUE)

# Step 5: Create folder for plots
dir.create("Tenure_Plots", showWarnings = FALSE)

# Step 6: Create line plots (2020 and 2024)
for (ctry in unique(tenure_all$country)) {
  df_sub <- tenure_all %>%
    filter(country == ctry) %>%
    select(country, `2020` = tenure_2020, `2024` = tenure_2024) %>%
    pivot_longer(cols = c(`2020`, `2024`), names_to = "year", values_to = "value") %>%
    mutate(year = as.numeric(year), value = as.numeric(value)) %>%
    drop_na(value)
  
  if (nrow(df_sub) < 1) next
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    geom_text(aes(label = round(value, 1)), vjust = -0.8, size = 4) +
    scale_x_continuous(breaks = c(2020, 2024)) +
    labs(
      title = paste("Perceived Tenure Security in", ctry),
      x = "Year",
      y = "% of adult population with secure tenure"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank()
    )
  
  ggsave(file.path("Tenure_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", ctry), "_Tenure.png")),
         plot = p, width = 9, height = 5.5, dpi = 300)
}
