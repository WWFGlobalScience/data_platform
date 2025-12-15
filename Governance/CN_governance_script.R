library(tidyverse)
library(sf)
library(rnaturalearth)
library(units)

# Load and validate prod_scapes_EE sf object
prod_scapes_EE <- st_read("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Prod_scapes_EE_wflags/Prod_scapes_EE.shp")

prod_scapes_EE <- st_make_valid(prod_scapes_EE)

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

adm1_sci <- adm1_joined %>%
  select(iso_code, adm1_code, name, country, year, sci) %>%
  pivot_wider(
    names_from = year,
    values_from = sci,
    names_glue = "{.value}_{year}_ind_GDL"
  )

# Create and validate new object for administrative boundaries that intersect with prod_scapes_EE
adm1_sci_prod_scapes <- adm1_sci %>%
  filter(lengths(st_intersects(., prod_scapes_EE)) > 0)

adm1_sci_prod_scapes <- st_make_valid(adm1_sci_prod_scapes)

st_write(adm1_sci_prod_scapes, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/adm1_sci_corruption.shp")

# Calculate the area of intersection between the operational landscapes and the administrative boundaries that intersect them

# Create intersection object
intersections_sci <- st_intersection(
  adm1_sci_prod_scapes %>% mutate(id1 = row_number()),
  prod_scapes_EE %>% mutate(id2 = row_number())
)

# Create column for area of overlap
intersections_sci$overlap_area <- st_area(intersections_sci)

# Create column for area of overlap in sq. km.
intersections_sci$overlap_area_km2 <- set_units(intersections_sci$overlap_area, km^2) %>% drop_units()

# Reset the sq. km. to numerics
intersections_sci$overlap_area_num <- as.numeric(intersections_sci$overlap_area_km2)

# Plot boxplot of area of intersection
ggplot(intersections_sci, aes(y = overlap_area_num)) +
  geom_boxplot() +
  labs(
    title = "Distribution of Polygon Overlap Areas",
    y = "Overlap Area (km²)",
    x = ""
  ) +
  theme_minimal()

## Grand corruption

adm1_grand <- adm1_joined %>%
  select(iso_code, adm1_code, name, country, year, grand) %>%
  pivot_wider(
    names_from = year,
    values_from = grand,
    names_glue = "{.value}_{year}_ind_GDL"
  )

# Create and validate new object for administrative boundaries that intersect with prod_scapes_EE
adm1_grand_prod_scapes <- adm1_grand %>%
  filter(lengths(st_intersects(., prod_scapes_EE)) > 0)

adm1_grand_prod_scapes <- st_make_valid(adm1_grand_prod_scapes)

st_write(adm1_grand_prod_scapes, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/adm1_grand_corruption.shp")

# Calculate the area of intersection between the operational landscapes and the administrative boundaries that intersect them

# Create intersection object
intersections_grand <- st_intersection(
  adm1_grand_prod_scapes %>% mutate(id1 = row_number()),
  prod_scapes_EE %>% mutate(id2 = row_number())
)

# Create column for area of overlap
intersections_grand$overlap_area <- st_area(intersections_grand)

# Create column for area of overlap in sq. km.
intersections_grand$overlap_area_km2 <- set_units(intersections_grand$overlap_area, km^2) %>% drop_units()

# Reset the sq. km. to numerics
intersections_petty$overlap_area_num <- as.numeric(intersections_petty$overlap_area_km2)

# Plot boxplot of area of intersection
ggplot(intersections_petty, aes(y = overlap_area_num)) +
  geom_boxplot() +
  labs(
    title = "Distribution of Polygon Overlap Areas",
    y = "Overlap Area (km²)",
    x = ""
  ) +
  theme_minimal()

## Petty corruption

adm1_petty <- adm1_joined %>%
  select(iso_code, adm1_code, name, country, year, petty) %>%
  pivot_wider(
    names_from = year,
    values_from = petty,
    names_glue = "{.value}_{year}_ind_GDL"
  )

# Create and validate new object for administrative boundaries that intersect with prod_scapes_EE
adm1_petty_prod_scapes <- adm1_petty %>%
  filter(lengths(st_intersects(., prod_scapes_EE)) > 0)

adm1_petty_prod_scapes <- st_make_valid(adm1_petty_prod_scapes)

st_write(adm1_petty_prod_scapes, "C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy/Conservation_Navigator/Data/Output_data/adm1_petty_corruption.shp")
# Calculate the area of intersection between the operational landscapes and the administrative boundaries that intersect them

# Create intersection object
intersections_petty <- st_intersection(
  adm1_petty_prod_scapes %>% mutate(id1 = row_number()),
  prod_scapes_EE %>% mutate(id2 = row_number())
)

# Create column for area of overlap
intersections_petty$overlap_area <- st_area(intersections_petty)

# Create column for area of overlap in sq. km.
intersections_petty$overlap_area_km2 <- set_units(intersections_petty$overlap_area, km^2) %>% drop_units()

# Reset the sq. km. to numerics
intersections_petty$overlap_area_num <- as.numeric(intersections_petty$overlap_area_km2)

# Plot boxplot of area of intersection
ggplot(intersections_petty, aes(y = overlap_area_num)) +
  geom_boxplot() +
  labs(
    title = "Distribution of Polygon Overlap Areas",
    y = "Overlap Area (km²)",
    x = ""
  ) +
  theme_minimal()