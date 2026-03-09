# People – Tenure Security (% of adult population perceiving land rights as secure)
# Source: data_comparison.csv (PRINDEX)
# Years: 2020 and 2024

library(sf)
library(dplyr)
library(readr)
library(ggplot2)
library(stringr)
library(tidyr)

# Step 1: Load shapefile and extract country names
shapefile_path <- "data_inputs/Prod_countries_EE/Prod_countries_EE.shp"
prod_countries <- st_read(shapefile_path)
country_names <- st_drop_geometry(prod_countries) %>% pull(COUNTRY) %>% unique()

# Step 2: Read tenure data
tenure_all <- read_csv("Governance/Data/data_comparison.csv")

# Step 3: Fix country names manually for mismatches with our country shapefile and change - to NA
tenure_all$Country <- gsub("Congo (Republic)", "Congo", tenure_all$Country, fixed = TRUE)
tenure_all$Country <- gsub("Korea (Republic)", "South Korea", tenure_all$Country, fixed = TRUE)
tenure_all$Country <- gsub("Turkey", "Turkiye", tenure_all$Country, fixed = TRUE)
tenure_all$Country <- gsub("United States of America", "United States", tenure_all$Country, fixed = TRUE)
tenure_all$Country <- gsub("Viet Nam", "Vietnam", tenure_all$Country, fixed = TRUE)
  
tenure_all$tenure_2020 <- gsub("^-$",NA,tenure_all$tenure_2020)
tenure_all$tenure_2024 <- gsub("^-$",NA,tenure_all$tenure_2024)

# Step 4:  Filter tenure data for ones relevant to countries we work in
tenure_selected <- tenure_all %>%
  filter(Country %in% country_names) %>%
  rename(country = Country)

# Step 3: Join to spatial data
tenure_prod_out <- prod_countries %>%
  left_join(tenure_selected, by = c("COUNTRY" = "country"))

# Step 4: Export GeoPackage
tenure_prod_out <- st_transform(tenure_prod_out, 4326)

run_date <- format(Sys.Date(), "%Y_%m_%d")

filename <- paste0("Governance/tenure_security_", run_date, ".gpkg")

st_write(tenure_prod_out, filename, layer = "tenure_security", delete_layer = TRUE)

# Step 5: Create folder for plots
#dir.create("Governance/Tenure_Plots", showWarnings = FALSE)
dir.create(paste0("Governance/Tenure_Plots/",run_date))
fig_dir <- paste0("Governance/Tenure_Plots/",run_date)

# Step 6: Create line plots (2020 and 2024)
# Create long dataframe for plotting with labels for %
tenure_long <- tenure_selected %>%
  pivot_longer(cols = c(tenure_2020, tenure_2024), names_to = "year", values_to = "value") %>%
  mutate(value = as.integer(value)) %>%
  mutate(label = paste0(sprintf("%4.f", value),"%"))

tenure_long$year <- gsub("tenure_2020",2020,tenure_long$year)
tenure_long$year <- gsub("tenure_2024",2024,tenure_long$year)

for (ctry in unique(tenure_long$country)) {
  df_sub <- tenure_long %>%
    filter(country == ctry)
  
  if (nrow(df_sub) < 1) next
  
  out_png <- file.path(
    fig_dir,
    paste0("TenureSecurity_", str_trim(ctry),".png")
  )
  
  p <- ggplot(df_sub, aes(x = year, y = value, group = 1)) +
    geom_point(size=2.5, color = "#728423") +
    geom_line(color = "#728423", size = 1.2, linetype = "dashed") +
    geom_text(aes(label = label), hjust = 0.5, nudge_y = -4) +
    scale_x_discrete(breaks = c(2020, 2024)) +
    scale_y_continuous(breaks = scales::breaks_pretty(),
                       limits = c(0, 100),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Perceived Tenure Security in", ctry),
      x = "Year",
      y = "% of adult population with secure tenure",
      caption = "Source: PRINDEX perceived tenure dataset (2025). Note: not all years may have data available."
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.text = element_text(color = "black"),
      axis.title.y = element_text(face="bold", vjust = 0.5),
      axis.title.x = element_text(face="bold",margin = margin(t = 10, unit = "pt")),
      axis.line = element_line(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      plot.caption = element_text(size=10, face = "italic", hjust=0)
    )
  
  ggsave(out_png, plot = p, width = 9, height = 5.5, dpi = 300)
}
