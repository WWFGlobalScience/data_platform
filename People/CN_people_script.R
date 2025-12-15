library(tidyverse)
library(sf)

#Load production landscapes shapefiles
prod_countries_EE <- st_read("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Prod_countries_EE/Prod_countries_EE.shp")

# Load health data, do be used for several indicators, and create new vaccine variable that takes the mean percent of children vaccinated for each disease
health <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Health Data v2.1.csv") %>%
  mutate(vaccineage1 = rowMeans(select(., bcgage1:measlage1), na.rm = TRUE))
  
# Percent of children under 5 years old who have received five standard vaccines (tuberculosis, diptheria, pertussis, tetanus, measles) 

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
vaccine <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, vaccineage1) %>%
  pivot_wider(
    names_from = year,
    values_from = vaccineage1,
    names_glue = "{.value}_{year}_pct_GDL"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
vaccine_prod_countries <- vaccine %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(vaccine_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/vaccine.csv")

# Child mortality (Number of children dying under five year of age, per 1,000 live births in a given year)

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
child_mort <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, u5mort) %>%
  pivot_wider(
    names_from = year,
    values_from = u5mort,
    names_glue = "{.value}_{year}_rto_GDL"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
child_mort_prod_countries <- child_mort %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(child_mort_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/child_mort.csv")

# Severely underweight (Percentage of children aged 0-59 months who are below minus three standard deviations from median weight-for-age of the World Health Organization (WHO) Child Growth Standards)

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
underweightsev <- health %>%
  filter(level == "National") %>%
  select(isocode3, country, year, underweightsev) %>%
  pivot_wider(
    names_from = year,
    values_from = underweightsev,
    names_glue = "{.value}_{year}_per_GDL"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
underweightsev_prod_countries <- underweightsev %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(underweightsev_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/underweightsev.csv")

# International Poverty Line
pip <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/pip.csv")
  
# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
poverty <- pip %>%
  filter(reporting_level == "national") %>%
  filter(welfare_type == "income") %>%
  rename(year = reporting_year) %>%
  rename(isocode3 = country_code) %>%
  rename(country = country_name) %>%
  select(country, isocode3, year, headcount) %>%
  pivot_wider(
    names_from = year,
    values_from = headcount,
    names_glue = "{.value}_{year}_pct_WorldBank"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
poverty_prod_countries <- poverty %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(poverty_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/poverty.csv")

# Number of people requiring interventions against neglected tropical disease
disease <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Source_data/disease.csv") %>%
  rename(COUNTRY = GEO_NAME_SHORT)

disease <- merge(disease, prod_countries_EE[, c("COUNTRY", "ISO3")], by = "COUNTRY", all.x = TRUE)

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
disease <- disease %>%
  rename(year = DIM_TIME) %>%
  rename(isocode3 = ISO3) %>%
  rename(country = COUNTRY) %>%
  rename(INTD = COUNT_N) %>%
  select(country, isocode3, year, INTD) %>%
  pivot_wider(
    names_from = year,
    values_from = INTD,
    names_glue = "{.value}_{year}_ct_WHO"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
disease_prod_countries <- disease %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(disease_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/INTD.csv")

# Maternal mortality rate
maternal <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/maternal_WHO.csv") %>%
  rename(COUNTRY = GEO_NAME_SHORT)

maternal <- merge(maternal, prod_countries_EE[, c("COUNTRY", "ISO3")], by = "COUNTRY", all.x = TRUE)

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
maternal <- maternal %>%
  rename(year = DIM_TIME) %>%
  rename(isocode3 = ISO3) %>%
  rename(country = COUNTRY) %>%
  rename(MM = RATE_PER_100000_N) %>%
  select(country, isocode3, year, MM) %>%
  pivot_wider(
    names_from = year,
    values_from = MM,
    names_glue = "{.value}_{year}_rto_WHO"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
maternal_prod_countries <- maternal %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(maternal_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/MM.csv")

# Free from stunting, wasting, and overweight
swo <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/wso_UNICEF.csv", skip = 8)

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
swo <- swo %>%
  rename(year = DataSourceYears) %>%
  rename(isocode3 = ISO3Code) %>%
  rename(country = CountryName) %>%
  rename(WOWC = ANT_FREE_r) %>%
  select(country, isocode3, year, WOWC) %>%
  pivot_wider(
    names_from = year,
    values_from = WOWC,
    names_glue = "{.value}_{year}_pct_UNICEF"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
swo_prod_countries <- swo %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(swo_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/WOWC.csv")

# Reproductive rights

# Load column headers first
header <- names(read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Source_data/rr_WHO.csv", n_max = 0))

# Read the rest, skipping 34 rows after the header
rr <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Source_data/rr_WHO.csv", skip = 34, col_names = header)

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
rr <- rr %>%
  rename(year = Year) %>%
  rename(isocode3 = `Country ISO 3 code`) %>%
  rename(country = Country) %>%
  rename(rr = `Value String`) %>%
  select(country, isocode3, year, rr) %>%
  pivot_wider(
    names_from = year,
    values_from = rr,
    names_glue = "{.value}_{year}_pct_WHO"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
rr_prod_countries <- rr %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(rr_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/reprod_rights.csv")

# Gender inequality index
gii <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Source_data/GII-UNDP.csv")

# Transform the dataset to only include national level data, only columns for year, country, ISO, and indicator, and transform so each column gets the indicator value per year
gii <- gii %>%
  rename(isocode3 = countryIsoCode) %>%
  rename(gii = value) %>%
  select(country, isocode3, year, gii) %>%
  pivot_wider(
    names_from = year,
    values_from = gii,
    names_glue = "{.value}_{year}_ind_UNDP"
  )

# Use the ISO code to only include countries that are in the production landscapes shapefiles
gii_prod_countries <- gii %>%
  filter(isocode3 %in% prod_countries_EE$ISO3)

write_csv(gii_prod_countries, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/gii.csv")


# Subnational percentage of people below the international poverty line

library(rnaturalearth)
library(units)

# Load and validate prod_scapes_EE sf object
prod_scapes_EE <- st_read("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Prod_scapes_EE_wflags/Prod_scapes_EE.shp")

prod_scapes_EE <- st_make_valid(prod_scapes_EE)

# Load admin level 1 shapefile for the entire globe
adm1 <- ne_states(returnclass = "sf")

# Transform to the same projection as prod_scapes_EE
adm1 <- st_transform(adm1, st_crs(prod_scapes_EE))

# Validate
adm1 <- st_make_valid(adm1)

adm1_clean <- adm1 %>% select(iso_a2, adm1_code, name, geometry) %>%
  mutate(adm1_code = str_sub(adm1_code, 1, 3))

iwi <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Source_data/GDL-Area_Database_Data-v441.csv")
  
iwi <- iwi %>%
  filter(level == "Subnat") %>%
  rename(name = region,
         adm1_code = isocode3) %>%
  select(adm1_code, name, country, year, gdlcode, level, iwipov35) %>%
  pivot_wider(
    names_from = year,
    values_from = iwipov35,
    names_glue = "{.value}_{year}_pct_GDL"
  )

adm1_joined <- adm1_clean %>%
  left_join(iwi, by = c("adm1_code", "name" = "name"))

# Plot the same shapefile from before and after join to make sure they're the same
plot(adm1_joined %>%
  filter(name == "Lagos"))

plot(adm1_clean %>%
  filter(name == "Lagos"))

# Create and validate new object for administrative boundaries that intersect with prod_scapes_EE
adm1_pov_prod_scapes <- adm1_joined %>%
  filter(lengths(st_intersects(., prod_scapes_EE)) > 0)

adm1_pov_prod_scapes <- st_make_valid(adm1_pov_prod_scapes)

st_write(adm1_pov_prod_scapes, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/adm1_pov.shp")


intersections_pov <- st_intersection(
  adm1_pov_prod_scapes %>% mutate(id1 = row_number()),
  prod_scapes_EE %>% mutate(id2 = row_number())
)

# Create column for area of overlap
intersections_pov$overlap_area <- st_area(intersections_pov)

# Create column for area of overlap in sq. km.
intersections_pov$overlap_area_km2 <- set_units(intersections_pov$overlap_area, km^2) %>% drop_units()

# Reset the sq. km. to numerics
intersections_pov$overlap_area_num <- as.numeric(intersections_pov$overlap_area_km2)
