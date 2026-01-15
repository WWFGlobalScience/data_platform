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

prod_scapes_EE <- st_read(
  "data_inputs/Prod_scapes_EE_wflags/Prod_scapes_EE.shp",
  quiet = TRUE
) %>%
  st_make_valid()

gdl_sf <- st_read(
  "data_inputs/GDL Shapefiles V6.6/GDL Shapefiles V6.6 large.shp"
) %>%
  st_transform(st_crs(prod_scapes_EE)) %>%
  st_make_valid()

# Keep only what we need from scapes to avoid carrying a lot of extra columns and convert Area km2 to m2 to calculate percent
prod_scapes_id <- prod_scapes_EE %>%
  select(Name,ID,Country,Area_km2,geometry) %>%
  mutate(Area_m2 = as.numeric(Area_km2)*1000000)

# # ------------------------------------------------------------------------------
# # 4) Pre-calculate full area of each GDL unit
# # Reasoning: Percent overlap is defined as:
# #   overlap_area(gdlcode, prod_id) / full_area(Area_m2)
# # So we compute full GDL area once, then join it to the intersection results.
# # ------------------------------------------------------------------------------
# 
# gdl_area_tbl <- gdl_sf %>%
#   mutate(gdl_area_m2 = as.numeric(st_area(geometry))) %>%
#   st_drop_geometry() %>%
#   select(gdlcode, gdl_area_m2)


# ------------------------------------------------------------------------------
# 5) Spatial intersection
# Reasoning:
# - Put GDL FIRST because we are ultimately measuring overlap as a fraction of GDL units.
# - The result geometry is the overlap polygon(s).
# - The result attributes include gdlcode + prod_id (since both inputs have them).
# ------------------------------------------------------------------------------

gdl_scape_intersection <- st_intersection(gdl_sf, prod_scapes_id)

# ------------------------------------------------------------------------------
# 6) Compute overlap area and percent overlap per (Area_m2, overlap_area_m2)
# Reasoning:
# - st_intersection can produce multiple pieces for the same pair; we aggregate them.
# - percent_overlap is relative to the full scape area.
# ------------------------------------------------------------------------------

gdl_scape_overlap <- gdl_scape_intersection %>%
  mutate(overlap_area_m2 = as.numeric(st_area(geometry))) %>%
  group_by(gdlcode, ID) %>%
  mutate(overlap_area_m2 = sum(overlap_area_m2)) %>%
  ungroup() %>%
  mutate(pct_overlap = round(overlap_area_m2 / Area_m2,2)) %>%
  select(-Country,-continent,-Area_km2) %>%
  rename(scape_name = Name,
         scape_id = ID,
         scape_area_m2 = Area_m2)

# ------------------------------------------------------------------------------
# 7) Filter to those with >= 25% overlap
# Reasoning: Your requirement is to keep only (gdlcode, prod_id) pairs where at least
# 25% of the GDL unit lies within the production landscape.
# ------------------------------------------------------------------------------

gdl_scape_overlap_25 <- gdl_scape_overlap %>%
  filter(pct_overlap >= 0.25)

# # Optional: If you want the intersected geometry for only those >=25% pairs,
# # join back to the intersection sf and filter.
# gdl_scape_intersection_25 <- gdl_scape_intersection %>%
#   semi_join(gdl_scape_overlap_25, by = c("gdlcode", "ID"))

st_write(gdl_scape_overlap_25,"data_inputs/scape_GDL_overlap25.shp")

# write.csv(gdl_scape_overlap_25,
#           "gdl_scape_overlap_25pct_table.csv",
#           row.names = FALSE)

# Result objects:
# - gdl_scape_overlap_25: clean table with gdlcode, prod_id, overlap_area_m2, gdl_area_m2, pct_overlap
# - gdl_scape_intersection_25: sf geometry of the overlaps that meet the threshold
