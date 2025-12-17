library(tidyverse)
library(sf)
library(rnaturalearth)
library(units)

# Load and validate prod_scapes_EE sf object
prod_scapes_EE <- st_read("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Prod_scapes_EE_wflags/Prod_scapes_EE.shp")

prod_scapes_EE <- st_make_valid(prod_scapes_EE)

prod_scapes_EE <- prod_scapes_EE %>% mutate(prod_id = row_number(),
                                            prod_area = st_area(geometry))
# Load admin level 1 shapefiles for the entire globe
adm1 <- ne_states(returnclass = "sf")

# Transform to the same projection as prod_scapes_EE
adm1 <- st_transform(adm1, st_crs(prod_scapes_EE))

# Validate
adm1 <- st_make_valid(adm1)

# Select only the variables of interest
adm1_clean <- adm1 %>% select(iso_a2, adm1_code, name, geometry)

# Load and simplify subnational corruption data
sci <- read_csv("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Source_data/GDL-CorruptionData-1.0.csv")

sci <- sci %>% 
  rename(
    iso_a2 = ISO2,
    name = region
  )


# Subnational corruption index
# Join the data to the cleaned shapefiles by the name of the subnational unit
adm1_joined <- adm1_clean %>%
  left_join(sci, by = c("iso_a2", "name" = "name"))

# Reformat the data so indicators x year each get one column
adm1_sci <- adm1_joined %>%
  select(iso_code, adm1_code, name, country, year, sci) %>%
  pivot_wider(
    names_from = year,
    values_from = sci,
    names_glue = "{.value}_{year}_ind_GDL"
  )

# Calculate area of each administrative unit
adm1_sci <- adm1_sci %>%
  mutate(adm1_area = st_area(geometry))

# Create intersection object between the administrative units and the production landscapes
adm1_sci_prod_int <- st_intersection(
  adm1_sci,
  prod_scapes_EE %>% select(prod_id)
)

# Calculate the area of intersection between the administrative units and the production landscapes
adm1_sci_prod_int <- adm1_sci_prod_int %>%
  mutate(int_area = st_area(geometry))

# Create a percentage column for how much of the administrative unit is in the production landscape
adm1_sci_prod_long <- adm1_sci_prod_int %>%
  mutate(
    pct_adm1_in_prod = as.numeric(int_area / adm1_area) * 100
  )

# Filter out any administrative units which have less than 25% of their area in a production landscape
adm1_sci_prod_25 <- adm1_sci_prod_long %>%
  filter(pct_adm1_in_prod >= 25)

# Filter out any administrative units which have less than 10% of their area in a production landscape
adm1_sci_prod_10 <- adm1_sci_prod_long %>%
  filter(pct_adm1_in_prod >=10)

# Filter out any administrative units which have less than 5% of their area in a production landscape
adm1_sci_prod_5 <- adm1_sci_prod_long %>%
  filter(pct_adm1_in_prod >=5)

write_sf(adm1_sci_prod_25, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_sci_25_pct.shp")
write_sf(adm1_sci_prod_10, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_sci_10_pct.shp")
write_sf(adm1_sci_prod_5, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_sci_5_pct.shp")


## Grand corruption

# Reformat the data so indicators x year each get one column
adm1_grand <- adm1_joined %>%
  select(iso_code, adm1_code, name, country, year, grand) %>%
  pivot_wider(
    names_from = year,
    values_from = grand,
    names_glue = "{.value}_{year}_ind_GDL"
  )

# Calculate area of each administrative unit
adm1_grand <- adm1_grand %>%
  mutate(adm1_area = st_area(geometry))

# Create intersection object between the administrative units and the production landscapes
adm1_grand_prod_int <- st_intersection(
  adm1_grand,
  prod_scapes_EE %>% select(prod_id)
)

# Calculate the area of intersection between the administrative units and the production landscapes
adm1_grand_prod_int <- adm1_grand_prod_int %>%
  mutate(int_area = st_area(geometry))

# Create a percentage column for how much of the administrative unit is in the production landscape
adm1_grand_prod_long <- adm1_grand_prod_int %>%
  mutate(
    pct_adm1_in_prod = as.numeric(int_area / adm1_area) * 100
  )

# Filter out any administrative units which have less than 25% of their area in a production landscape
adm1_grand_prod_25 <- adm1_grand_prod_long %>%
  filter(pct_adm1_in_prod >= 25)

# Filter out any administrative units which have less than 10% of their area in a production landscape
adm1_grand_prod_10 <- adm1_grand_prod_long %>%
  filter(pct_adm1_in_prod >=10)

# Filter out any administrative units which have less than 5% of their area in a production landscape
adm1_grand_prod_5 <- adm1_grand_prod_long %>%
  filter(pct_adm1_in_prod >=5)

write_sf(adm1_grand_prod_25, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_grand_25_pct.shp")
write_sf(adm1_grand_prod_10, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_grand_10_pct.shp")
write_sf(adm1_grand_prod_5, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_grand_5_pct.shp")


## Petty corruption

# Reformat the data so indicators x year each get one column
adm1_petty <- adm1_joined %>%
  select(iso_code, adm1_code, name, country, year, petty) %>%
  pivot_wider(
    names_from = year,
    values_from = petty,
    names_glue = "{.value}_{year}_ind_GDL"
  )

# Calculate area of each administrative unit
adm1_petty <- adm1_petty %>%
  mutate(adm1_area = st_area(geometry))

# Create intersection object between the administrative units and the production landscapes
adm1_petty_prod_int <- st_intersection(
  adm1_petty,
  prod_scapes_EE %>% select(prod_id)
)

# Calculate the area of intersection between the administrative units and the production landscapes
adm1_petty_prod_int <- adm1_petty_prod_int %>%
  mutate(int_area = st_area(geometry))

# Create a percentage column for how much of the administrative unit is in the production landscape
adm1_petty_prod_long <- adm1_petty_prod_int %>%
  mutate(
    pct_adm1_in_prod = as.numeric(int_area / adm1_area) * 100
  )

# Filter out any administrative units which have less than 25% of their area in a production landscape
adm1_petty_prod_25 <- adm1_petty_prod_long %>%
  filter(pct_adm1_in_prod >= 25)

# Filter out any administrative units which have less than 10% of their area in a production landscape
adm1_petty_prod_10 <- adm1_petty_prod_long %>%
  filter(pct_adm1_in_prod >=10)

# Filter out any administrative units which have less than 5% of their area in a production landscape
adm1_petty_prod_5 <- adm1_petty_prod_long %>%
  filter(pct_adm1_in_prod >=5)

write_sf(adm1_petty_prod_25, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_petty_25_pct.shp")
write_sf(adm1_petty_prod_10, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_petty_10_pct.shp")
write_sf(adm1_petty_prod_5, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/subnat_petty_5_pct.shp")
