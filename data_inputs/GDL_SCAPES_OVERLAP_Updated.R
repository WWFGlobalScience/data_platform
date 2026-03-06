# Or install the latest development version from GitHub
install.packages("remotes")
remotes::install_github("GlobalDataLab/R-data-api")
library(gdldata)
library(sf)
library(dplyr)

#token 5YY0sJHmjCstN2EgcTWqsZuUo8_mzcMQVX_2xPMmv7I
# sess <- gdl_session("5YY0sJHmjCstN2EgcTWqsZuUo8_mzcMQVX_2xPMmv7I")
# gdl_datasets(session)      # retrieves a list of available datasets
# gdl_indicators(session)    # retrieves a list of indicators for the current dataset
# gdl_levels(session)        # retrieves a list of aggregation levels
# gdl_countries(session)     # retrieves a list of available countries
# gdl_regions(session, iso3) # retrieves a list of regions in a particular country
# 
# ds <- gdl_datasets(sess)

# Read in the production scapes for WWF
prod_scapes_EE <- st_read(
  "data_inputs/Prod_scapes_EE_wflags/Prod_scapes_EE.shp",
  quiet = TRUE
) %>%
  st_make_valid()

# Read in the subnational areas from GDL
gdl_sf <- st_read(
  "data_inputs/GDL Shapefiles V6.6/GDL Shapefiles V6.6 large.shp"
) %>%
  st_transform(st_crs(prod_scapes_EE)) %>%
  st_make_valid()

# Calculate area of GDL subnational areas
gdl_sf$Area_m2 <- as.numeric(st_area(gdl_sf))
gdl_sf$Area_km2 <- gdl_sf$Area_m2/1000000

# Keep only what we need from scapes to avoid carrying a lot of extra columns and convert Area km2 to m2 to calculate percent
prod_scapes_id <- prod_scapes_EE %>%
  select(Name,ID,Country,Area_km2,geometry) %>%
  mutate(Area_m2 = as.numeric(Area_km2)*1000000)

# ------------------------------------------------------------------------------
# Spatial intersection
# Reasoning:
# - Put GDL FIRST because we are ultimately measuring overlap as a fraction of GDL units.
# - The result geometry is the overlap polygon(s).
# - The result attributes include gdlcode + prod_id (since both inputs have them).
# ------------------------------------------------------------------------------

gdl_scape_intersection <- st_intersection(gdl_sf, prod_scapes_id)

# ------------------------------------------------------------------------------
# 6) Compute overlap area and percent overlap of landscape by subnational area (Area_m2, overlap_area_m2)
# Reasoning:
# - st_intersection can produce multiple pieces for the same pair; we aggregate them.
# - pct_overlap_scape is relative to the full scape area.
# - pct_overlap_subnat is relative to the full subnational area
# ------------------------------------------------------------------------------

gdl_scape_overlap <- gdl_scape_intersection %>%
  mutate(overlap_area_m2 = as.numeric(st_area(geometry))) %>%
  group_by(gdlcode, ID) %>%
  mutate(overlap_area_m2 = sum(overlap_area_m2)) %>%
  ungroup() %>%
  mutate(pct_overlap_scape = round(overlap_area_m2 / Area_m2.1,2)) %>%
  mutate(pct_overlap_subnat = round(overlap_area_m2 / Area_m2,2)) %>%
  select(-Country,-continent,-Area_km2.1,-Area_km2) %>%
  rename(scape_name = Name,
         sc_area_m2 = Area_m2.1,
         sn_area_m2 = Area_m2,
         ov_area_m2 = overlap_area_m2,
         pct_scape = pct_overlap_scape,
         pct_subnat = pct_overlap_subnat) %>%
  st_drop_geometry()

# ------------------------------------------------------------------------------
# Filter to those subnational areas that overlap with >= 25% of the landscape area
# or subnational areas with >= 95% of their area contained in the landscape area
# Reasoning: 
# Reasoning: Your requirement is to keep only (gdlcode, prod_id) pairs where at least
# 25% of the production landscape is captured by the subnational area (meaning that 
# trends in the subnational area should reflect trends in a significant portion of the scape)
# and also where 95% of the GDL unit lies within the production landscape (basically anything where it
# is practically the whole subnational area is within the scape.
# ------------------------------------------------------------------------------

gdl_scape_overlap_retained <- gdl_scape_overlap %>%
  filter(pct_scape >= 0.25 | pct_subnat >= 0.95)
  

# # Optional: If you want the intersected geometry for only those >=25% pairs,
# # join back to the intersection sf and filter.

gdl_scape_overlap_retained_shp <- gdl_scape_overlap_retained %>%
  left_join(select(gdl_scape_intersection,gdlcode,ID,geometry), by = c("gdlcode", "ID"))

st_write(gdl_scape_overlap_retained_shp, "gdl_scape_overlap_retained.gpkg",append=FALSE)

write_rds(gdl_scape_overlap_retained,"gdl_scape_overlap_retained.rds")

write_rds(gdl_scape_overlap,"gdl_scape_overlap.rds")

# write.csv(gdl_scape_overlap_25,
#           "gdl_scape_overlap_25pct_table.csv",
#           row.names = FALSE)

# Result objects:
# - gdl_scape_overlap_25: clean table with gdlcode, prod_id, overlap_area_m2, gdl_area_m2, pct_overlap
# - gdl_scape_intersection_25: sf geometry of the overlaps that meet the threshold
