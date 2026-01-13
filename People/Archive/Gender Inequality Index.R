#setwd("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/R/People")
#People 
# GII Gender Inequality Index Calculation
library(tidyverse)
library(readr)
library(sf)

# Load shapefile and extract country list
countries_sf <- st_read("Prod_countries_EE.shp")
country_names <- countries_sf %>% st_drop_geometry() %>% pull(COUNTRY) %>% unique()

# Load and filter Gender Inequality Index
GII <- read_csv("HDR25_Composite_indices_complete_time_series.csv")
GII_sub <- GII %>%
  filter(country %in% country_names)
gii_cols <- names(GII_sub)[str_detect(names(GII_sub), "^gii_\\d{4}$")]
GII_sub <- GII_sub %>% select(country, all_of(gii_cols))

# Join with spatial data
people_data_gii <- countries_sf %>%
  left_join(GII_sub, by = c("COUNTRY" = "country"))

# Reshape to long
long_data <- people_data_gii %>%
  st_drop_geometry() %>%
  select(COUNTRY, all_of(gii_cols)) %>%
  pivot_longer(-COUNTRY, names_to = "year", values_to = "value") %>%
  mutate(year = as.numeric(str_extract(year, "\\d{4}")),
         value = as.numeric(value)) %>%
  drop_na(value)

# Plot for each country
for (country in unique(long_data$COUNTRY)) {
  df_sub <- long_data %>% filter(COUNTRY == country)
  if (nrow(df_sub) == 0 || all(is.na(df_sub$value))) next
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    labs(title = paste("Gender Inequality Index in", country),
         x = "Year", y = "Index (0–1)") +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
          axis.text = element_text(color = "black"),
          axis.line = element_line(color = "black"),
          legend.position = "none")
  
  plot_path <- file.path("Final Figures", "People", "Gender Inequality Index", paste0(gsub("[^a-zA-Z0-9]", "_", country), "_GII.png"))
  dir.create(dirname(plot_path), recursive = TRUE, showWarnings = FALSE)
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}
