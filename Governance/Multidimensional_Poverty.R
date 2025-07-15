# # People	Proportion of men, women and children of all ages living in poverty in all its dimensions (National) Data availability per year per country is inconsistent.
# https://unstats.un.org/sdgs/metadata/files/Metadata-01-02-02.pdf
# Percentage of population living in poverty according to nationally-specific indices (0-100%) 2012-2021 
#MPI_Multidimensional_Poverty_Index.R
library(tidyverse)
library(readxl)
library(sf)


countries_sf <- st_read("Prod_countries_EE.shp")
country_names <- countries_sf %>% st_drop_geometry() %>% pull(COUNTRY) %>% unique()

# Load MPI data
MPI_raw <- read_excel("poverty_data.xlsx", sheet = "Goal1")
MPI_sub <- MPI_raw %>%
  filter(GeoAreaName %in% country_names,
         SeriesCode == "SD_MDP_MUHC",
         Age == "ALLAGE",
         Location == "ALLAREA",
         Sex == "BOTHSEX")

MPI_wide <- MPI_sub %>%
  mutate(year = as.character(TimePeriod)) %>%
  select(country = GeoAreaName, year, Value) %>%
  pivot_wider(names_from = year, values_from = Value, names_prefix = "mpi_")

# Join
people_data_mpi <- countries_sf %>%
  left_join(MPI_wide, by = c("COUNTRY" = "country"))

# Reshape for plotting
long_data <- people_data_mpi %>%
  st_drop_geometry() %>%
  pivot_longer(cols = starts_with("mpi_"), names_to = "year", values_to = "value") %>%
  mutate(
    year = as.numeric(str_remove(year, "mpi_")),
    value = as.numeric(value)
  ) %>%
  drop_na(value)

# Create folder for plots
dir.create("Multidimensial_Poverty_Plots", showWarnings = FALSE)

# Plot loop with corrected axis title
for (country in unique(long_data$COUNTRY)) {
  df_sub <- long_data %>% filter(COUNTRY == country)
  if (nrow(df_sub) == 0) next
  
  p <- ggplot(df_sub, aes(x = year, y = value)) +
    geom_line(color = "#728423", size = 1.2) +
    geom_point(color = "#728423", size = 2.5) +
    scale_x_continuous(breaks = seq(min(df_sub$year), max(df_sub$year), by = 1)) +
    labs(
      title = paste("Proportion of Population in Multidimensional Poverty in", country),
      x = "Year",
      y = "Population in multidimensional poverty (%)"
    ) +
    theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.line = element_line(color = "black"),
      legend.position = "none"
    )
  
  plot_path <- file.path("MPI Figures", paste0(gsub("[^a-zA-Z0-9]", "_", country), "_MPI.png"))
  ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
}
