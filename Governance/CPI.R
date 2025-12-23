# CPI – Perceived levels of public sector corruption (2012–2024)
# Source: Transparency International

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(ggplot2)
library(janitor)
library(stringr)

# Step 1: Load country shapefile
shapefile_path <- "Prod_countries_EE.shp"
prod_countries <- st_read(shapefile_path)
country_names <- st_drop_geometry(prod_countries) %>% pull(COUNTRY) %>% unique()

# Step 2: Load and clean CPI data
cpi_raw <- read_excel("CPI2024-Results-and-trends.xlsx", sheet = "CPI Timeseries 2012 - 2024", skip = 1)

cpi_long <- cpi_raw %>%
  clean_names() %>%
  rename(country = country_territory) %>%
  filter(country %in% country_names) %>%
  select(country, starts_with("cpi_score_")) %>%
  pivot_longer(cols = starts_with("cpi_score_"),
               names_to = "year",
               names_prefix = "cpi_score_",
               values_to = "cpi_score") %>%
  mutate(
    year = as.integer(year),
    cpi_score = as.numeric(cpi_score)
  ) %>%
  drop_na(cpi_score)

# Step 3: Plotting
dir.create("CPI_Plots", showWarnings = FALSE)

for (ctry in unique(cpi_long$country)) {
  df_sub <- cpi_long %>% filter(country == ctry)
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = cpi_score)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    geom_text(aes(label = round(cpi_score, 1)), vjust = -0.8, size = 4) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), 1)) +
    labs(
      title = paste("CPI Score in", ctry),
      x = "Year", y = "CPI Score (0–100)"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank()
    )
  
  ggsave(file.path("CPI_Plots", paste0(gsub("[^a-zA-Z0-9]", "_", ctry), "_CPI.png")),
         plot = p, width = 9, height = 5.5, dpi = 300)
}
