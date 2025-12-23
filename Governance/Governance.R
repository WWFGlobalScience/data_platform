#Governance 
# Indicators 
# (CPI_YEAR) Perceived levels of public sector corruption at the national scale Corruption Perceptions Index (0-100) 2012-2024 line graph 
# Number of conflict events within a country per year ACLED #KEY -KL7153qgp7Yz16RUEfN
    #### Data Output Description: table of countries with appended columns FCS_2021 - FCS_2024
#Number of land and environmental human rights defenders killed annually, disaggregated by country, gender; indigenous status. table of countries with appended columns PS_2012 - PS_2022
#Proportion of total adult population with secure tenure rights to land, and who perceive their rights to land as secure, by sex and by type of tenure from 2020 and 2024
#Percent of land area designated for and owned by Indigenous Peoples, Afro-descendant Peoples, and Local Communities - Summed columns for land designated for and land owned by Indigenous, Afro-descendent, or local communities. Joined table of summed columns to vector layer of countries.

library(sf)
library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(lubridate)
library(janitor)

# Step 1: Read country shapefile
shapefile_path <- "C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Prod_countries_EE.shp"
prod_countries <- st_read(shapefile_path)

# Step 2: Extract unique country names
country_names <- prod_countries %>%
  st_drop_geometry() %>%
  pull(COUNTRY) %>%                    
  unique()

#Step 3: Calculate the indicator values in wide format to attach to SF and long tidy format for visualizations 
acled_data <- read.csv("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/1997-05-01-2025-05-29.csv") %>% 
filter(country %in% country_names) %>% 
  count(country, year, name = "ACLED_events")

acled_small <- acled_data %>%
  select(ACLED_events, country, year) %>%
  filter(country %in% country_names)

#Summarise: count how many event_id_cnty you have per country & year
#summary_df <- acled_small %>%
# group_by(country, year) %>%
# summarise(event_count = n(), .groups = "drop")

acled_wide <- acled_small %>% 
  pivot_wider(
    names_from  = year,
    values_from = ACLED_events,
    names_prefix= "ACLED_"
  )


head(acled_data)
head(summary_df)

##### CPI per year 
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(janitor) #cleans up the cloumn names so they are r friendly
cpi_raw <- read_excel("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/CPI2024-Results-and-trends.xlsx", sheet = "CPI Timeseries 2012 - 2024", skip = 1)

# Clean column names, keep ISO3, and rename country column
cpi_clean <- cpi_raw %>%
  clean_names() %>%
  rename(country = country_territory)

# Filter to only countries of interest
cpi_filtered <- cpi_clean %>%
  filter(country %in% country_names)

# Reshape data: keep ISO3 and convert CPI score columns to long format
cpi_long <- cpi_filtered %>%
  select(country, iso3, starts_with("cpi_score_")) %>%
  pivot_longer(cols = starts_with("cpi_score_"),
               names_to = "year",
               names_prefix = "cpi_score_",
               values_to = "cpi_score") %>%
  mutate(year = as.integer(year)) %>%
  arrange(country, year)

# Save to CSV
#write.csv(cpi_long, "CPI_timeseries_clean.csv", row.names = FALSE)


############## Number of land and environmental human rights defenders killed annually, disaggregated by country, gender; indigenous status.
library("lubridate")
# PS_yr 
victims_data <- read_csv("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/global_witness_led_10-10-24.csv")

ps_by_year_country <- victims_data %>%
  mutate(year = year(as.Date(date))) %>%
  filter(country %in% country_names) %>%
  group_by(country, year) %>%
  summarise(PS = sum(number_of_victims, na.rm = TRUE), .groups = "drop") %>%
  arrange(country, year)

#Number of land and environmental human rights defenders killed annually, disaggregated by country, gender; indigenous status. table of countries with appended columns PS_2012 - PS_2022
##note you can't go from raw csv directly here because the download requires manual cleaning 
## Tenure security all = for all types and genders - cloumns are country, tenure_2020 and tenure_2024. file: data_comparison.csv"
## Tenure security gender = for all types by gender tenure_male_200x and  and tenure_fem_200x. file: tenure_gender.csv


tenure_data <- read_csv("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/data_comparison.csv")
tenure_gender_data <- read_csv("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/tenure_gender.csv")


tenure_country<- tenure_data %>%
  filter(Country %in% country_names) 

tenure_gender <- tenure_gender_data %>%
  filter(Country %in% country_names) 

tenure_combined_wide <- tenure_country %>%
  left_join(tenure_gender, by = "Country")

# Ensure sf and dplyr are loaded
library(sf)
library(dplyr)

# --- Join ACLED data (wide) ---
prod_countries <- prod_countries %>%
  left_join(acled_wide, by = c("COUNTRY" = "country"))

# --- Join CPI data (wide format) ---
cpi_wide <- cpi_long %>%
  pivot_wider(names_from = year, values_from = cpi_score, names_prefix = "CPI_")
prod_countries <- prod_countries %>%
  left_join(cpi_wide, by = c("COUNTRY" = "country"))

# --- Join Human Rights Defenders Killings (wide) ---
#ps_wide <- ps_by_year_country %>%
 # pivot_wider(names_from = year, values_from = PS, names_prefix = "PS_")
#prod_countries <- prod_countries %>%
 # left_join(ps_wide, by = c("COUNTRY" = "country"))

# --- Join Tenure Security ---
tenure_combined_wide <- tenure_combined_wide %>%
  rename(country = Country)
prod_countries <- prod_countries %>%
  left_join(tenure_combined_wide, by = c("COUNTRY" = "country"))

# --- Export to GeoPackage ---
prod_countries <- st_transform(prod_countries, 4326)

prod_countries <- prod_countries %>%
  left_join(acled_wide,           by = c("COUNTRY" = "country")) %>%
  left_join(cpi_wide,             by = c("COUNTRY" = "country")) %>%
  left_join(tenure_combined_wide, by = c("COUNTRY" = "country"))

st_write(prod_countries, "Governance_Indicators.gpkg", layer = "governance_indicators", delete_layer = TRUE)



