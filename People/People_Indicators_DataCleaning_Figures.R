setwd("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/R/People")

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)
library(janitor)
library(stringr)

# 1) Read country shapefile & get country list
# ───────────────────────────────────────────────────────────────────────────────
shp_path <- "Prod_countries_EE.shp"
countries_sf <- st_read(shp_path)
country_names <- countries_sf %>% 
  st_drop_geometry() %>% 
  pull(COUNTRY) %>% unique()


# --- 
# Indicators 
# The following indicators are proccessed in this script
#gii_ Gender Inequality Index

#mpi_ Multidimensional Poverty Index

#ISSP_ Income of Small-Scale Food Producers

#II_ Income Share of 4th Decile

#FIS_ Food Insecurity

#CL_ Child Labour


#---
# Annual change in Gender Inequality Index at the national scale (National)
#https://hdr.undp.org/data-center/documentation-and-downloads
# country gii_
# keep world for line graphs
# Gender Inequality Index score (0-1) 2012-2022
# 0=men and women fare about equally; 1=men and women fare unequally across several dimensions

GII <- read_csv("HDR25_Composite_indices_complete_time_series.csv")
GII_sub <- GII %>%
  filter(country %in% country_names)
gii_cols <- names(GII_sub)[str_detect(names(GII_sub), "^gii_\\d{4}$")] #country column and columns named gii_YYYY
GII_sub <- GII_sub %>%
  select(country, all_of(gii_cols))


# # People	Proportion of men, women and children of all ages living in poverty in all its dimensions (National) Data availability per year per country is inconsistent.
# https://unstats.un.org/sdgs/metadata/files/Metadata-01-02-02.pdf
# Percentage of population living in poverty according to nationally-specific indices (0-100%) 2012-2021 
MPI_raw <- read_excel("poverty_data.xlsx", sheet = "Goal1")
MPI_sub <- MPI_raw %>%
  filter(GeoAreaName %in% country_names, SeriesCode == "SD_MDP_MUHC", Age == "ALLAGE",
         Location == "ALLAREA", Sex == "BOTHSEX") 
MPI_wide <- MPI_sub %>%
  mutate(year = as.character(TimePeriod)) %>%
  select(country = GeoAreaName, year, Value) %>%
  pivot_wider(names_from = year, values_from = Value, names_prefix = "mpi_")

#########################
#People	Average income of small-scale food producers
# 2004 - 2021
# https://www.fao.org/in-action/rural-livelihoods-dataset-rulis/en/ > Indicator is > select all countries, all years, and national dissagregation
# Data Summarization: Average income (in 2017 dollars) of small scale food producers
# Average income of small scale food producers (in 2017 $USD) 2014-2020
# Data Output Description: table of countries with appended columns ISSP_2014 - ISSP_2020
ISSP_wide <- read_csv("ISSP.csv") %>%
  filter(Country %in% country_names) %>%
  group_by(Country, Year) %>%
  pivot_wider(names_from = Year, values_from = Value, names_prefix = "ISSP_")  %>%
  select(Country, starts_with("issp_"))

# People	Mortality rate attributed to unsafe water, unsafe sanitation and lack of hygiene
#2012, 2015, and 2019 (2012 and 2015 not comparable to 2019) 
# https://www.who.int/data/gho/data/indicators/indicator-details/GHO/mortality-rate-attributed-to-exposure-to-unsafe-wash-services-(per-100-000-population)-(sdg-3-9-2)

MWASH_wide <- read_csv("WASH.csv") %>%
  rename(country = Location) %>%
  mutate(year = as.character(Period)) %>%
  filter(country %in% country_names, Dim1 == "Both sexes") %>%
  pivot_wider(names_from = year, values_from = Value, names_prefix = "MWASH_") %>%
  select(country, starts_with("MWASH_"))


# People	Percentage of national income earned by the 4th decile of income earners
##https://www.worldbank.org/en/topic/poverty/brief/global-database-of-shared-prosperity
PovertyGap_Data <- read_csv("pip.csv") %>%
  clean_names() %>%  # optional: makes column names lowercase and snake_case
  filter(reporting_level == "national", welfare_type == "income") %>%
  select(country_name, country_code, reporting_year, decile4)
Decile4_wide <- PovertyGap_Data %>%
  filter(country_name %in% country_names) %>%
  pivot_wider(names_from = reporting_year, values_from = decile4, names_prefix = "II_") %>%
  rename(country = country_name)

# People - "Proportion of the total population consuming all five food groups typically recommended for daily consumption"
# https://www.dietquality.org/ 
# DQQ_2021-2023_Public_Results.csv — assign year as 2023

DIET_2023 <- read_csv("DQQ_2021-2023_Public_Results.csv") %>%
  filter(Country %in% country_names,
         Indicator == "All-5",
         Subgroup == "All") %>%
  mutate(year = "2023") %>%
  select(Country, year, Mean) %>%
  pivot_wider(names_from = year, values_from = Mean, names_prefix = "DIET_") %>%
  rename(country = Country)



# People	Prevalence of moderate or severe food insecurity in the population, based on the Food Insecurity Experience Scale
# https://www.fao.org/faostat/en/#data/FS

FIS_wide <- read_csv("FAOSTAT_data_en_6-17-2025.csv") %>%
  filter(`Item Code` == 210091, Element == "Value") %>% #% only and 210091 is for All the country 210091M is male 210091F for female
  rename(country = Area) %>%
  filter(country %in% country_names) %>%
  select(country, Value, Year) %>%
  pivot_wider(names_from = Year, values_from = Value, names_prefix = "FIS_")

# People	Proportion and number of children aged 5‐17 years engaged in child labour, by sex and age
# 2014-2022
# Single timestep, data was collected between 2014-2022
# https://data.unicef.org/topic/child-protection/child-labour/
# separate these REF_AREA:Geographic area so that only the Geographic area exists then rename to country and filter 
# TIME_PERIOD:Time period == year	OBS_VALUE:Observation Value

# People - Proportion of children aged 5‐17 engaged in child labour
# https://data.unicef.org/topic/child-protection/child-labour/
# Data typically reported once per country, with varying years (2014–2022)

CHILD_LABOUR_v2 <- read_csv("fusion_GLOBAL_DATAFLOW_UNICEF_1.0_.PT_CHLD_5-17_LBR_ECON._T.csv") %>%
  separate(`REF_AREA:Geographic area`, into = c("code", "country"), sep = ": ", remove = FALSE) %>%
  select(country, year = 'TIME_PERIOD:Time period', value = 'OBS_VALUE:Observation Value') %>%
  filter(country %in% country_names) %>%
  pivot_wider(names_from = year, values_from = value, names_prefix = "CL_")


# Join all wide-format datasets by country name
people_data <- countries_sf %>%
  left_join(GII_sub,         by = c("COUNTRY" = "country")) %>%
  left_join(MPI_wide,        by = c("COUNTRY" = "country")) %>%
  left_join(ISSP_wide,       by = c("COUNTRY" = "Country")) %>%
  left_join(MWASH_wide,      by = c("COUNTRY" = "country")) %>%
  left_join(Decile4_wide,    by = c("COUNTRY" = "country")) %>%
  left_join(DIET_2023,       by = c("COUNTRY" = "country")) %>%
  left_join(FIS_wide,        by = c("COUNTRY" = "country")) %>%
  left_join(CHILD_LABOUR_v2, by = c("COUNTRY" = "country"))

# Export as GeoPackage
st_write(people_data, "People_Indicators.gpkg", layer = "people_data", delete_layer = TRUE)



################## Figures
library(tidyverse)
library(readxl)
library(ggrepel)
library(showtext)

#Note that only the indicators where type = time produce figures for MWASH and Diet are not

indicator_meta <- tribble(
  ~prefix,     ~indicator_name,                                 ~category,  ~unit,             ~type,
  "gii_",      "Gender Inequality Index",                        "People",   "Index (0–1)",      "time",
  "mpi_",      "Multidimensional Poverty Index",                 "People",   "%",                "time",
  "ISSP_",     "Income of Small-Scale Food Producers",           "People",   "2017 USD",         "time",
  "MWASH_",    "Mortality from Unsafe Water & Sanitation",       "People",   "per 100,000",      "one",
  "II_",       "Income Share of 4th Decile",                     "People",   "%",                "time",
  "DIET_",     "Diet Quality (All 5 Food Groups)",               "People",   "%",                "one",
  "FIS_",      "Food Insecurity Prevalence",                     "People",   "%",                "time",
  "CL_",       "Child Labour (Aged 5–17)",                       "People",   "%",                "time"
)

# ==============================================================================
# People Indicators — Note you can either go from people_data OR the geopackage 
# Output structure: People/Figures/<Indicator>/<Country>_<Indicator>.png
# Assumption: GeoPackage already includes ISSP_* columns.
# ==============================================================================

# --- Setup --------------------------------------------------------------------
library(sf)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(tibble)
library(showtext)
library(sysfonts)

gpkg_path <- "F:/SanDiskSecureAccess Vault/TEST/People_Indicators.gpkg"
gpkg_layer <- "people_data"   # change if your layer name differs

# Read GeoPackage (sf object)
people_data <- st_read(gpkg_path, layer = gpkg_layer, quiet = TRUE)

# --- Indicator metadata --------------------------------------------------------
# type = "time" will be plotted in bulk; type = "one" is skipped )
indicator_meta <- tribble(
  ~prefix,  ~indicator_name,                           ~category, ~unit,         ~type,
  "gii_",   "Gender Inequality Index",                  "People",  "Index (0–1)",  "time",
  "mpi_",   "Multidimensional Poverty Index",           "People",  "%",           "time",
  "ISSP_",  "Income of Small-Scale Food Producers",     "People",  "2017 USD",    "time",
  "MWASH_", "Mortality from Unsafe Water & Sanitation", "People",  "per 100,000", "one",
  "II_",    "Income Share of 4th Decile",               "People",  "%",           "time",
  "DIET_",  "Diet Quality (All 5 Food Groups)",         "People",  "%",           "one",
  "FIS_",   "Food Insecurity Prevalence",               "People",  "%",           "time",
  "CL_",    "Child Labour (Aged 5–17)",                 "People",  "%",           "time"
)

# ---- Font + theme -------------------------------------------------------------
font_add_google("Open Sans", "opensans")
showtext_auto()

theme_people_plot <- function() {
  theme_minimal(base_family = "opensans", base_size = 13) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      axis.title.x = element_text(size = 13),
      axis.title.y = element_text(size = 13),
      axis.text = element_text(size = 12, color = "black"),
      axis.line = element_line(color = "black", linewidth = 0.4),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      plot.margin = margin(10, 10, 10, 10),
      legend.position = "none"
    )
}

safe_name <- function(x) gsub("[^a-zA-Z0-9]", "_", x)

# ---- Plot loop ---------------------------------------------------------------
for (i in seq_len(nrow(indicator_meta))) {
  
  row <- indicator_meta[i, ]
  
  # Only time-series indicators
  if (row$type != "time") next
  
  prefix <- row$prefix
  cols <- names(people_data)[str_starts(names(people_data), prefix)]
  if (length(cols) == 0) next
  
  long_data <- people_data %>%
    st_drop_geometry() %>%
    select(COUNTRY, all_of(cols)) %>%
    pivot_longer(-COUNTRY, names_to = "year", values_to = "value") %>%
    mutate(
      COUNTRY = str_trim(COUNTRY),
      value   = suppressWarnings(as.numeric(value)),
      year    = suppressWarnings(as.numeric(str_extract(year, "\\d{4}")))
    ) %>%
    drop_na(year, value)
  
  for (country in unique(long_data$COUNTRY)) {
    
    df_sub <- long_data %>% filter(COUNTRY == country)
    
    # 🚫 Skip if fewer than 2 observations
    if (nrow(df_sub) < 2) next
    
    # Ensure ticks show as YYYY (and only for years that exist for this country/indicator)
    year_breaks <- sort(unique(as.numeric(df_sub$year)))
    
    p <- ggplot(df_sub, aes(x = as.numeric(year), y = value)) +
      geom_line(color = "#728423", linewidth = 1.2) +
      geom_point(color = "#728423", size = 2.5) +
      scale_x_continuous(
        breaks = year_breaks,
        labels = function(x) sprintf("%04d", x)
      ) +
      labs(
        title = paste(row$indicator_name, "in", country),
        x = "Year",
        y = paste0(row$indicator_name, " (", row$unit, ")")
      ) +
      theme_people_plot()
    
    plot_path <- file.path(
      out_root,
      row$indicator_name,
      paste0(safe_name(country), "_", safe_name(row$indicator_name), ".png")
    )
    
    dir.create(dirname(plot_path), recursive = TRUE, showWarnings = FALSE)
    ggsave(plot_path, plot = p, width = 9, height = 5.5, dpi = 300)
  }
  
  message("Finished: ", row$indicator_name)
}

message("All figures saved to: ", out_root)