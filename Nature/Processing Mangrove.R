setwd("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform")

library(tidyverse)
library(sf)

scapes<- st_read("Pilot_scapes_EE/Pilot_scapes_EE.shp")
scapes<- st_transform(scapes,crs=8857)
#For each year I read in the shp, then I transform it, and I remove -Area to standardize files then I clip them to the scapes shp
mangrove.2020<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2020_vec.shp")
mangrove.2020<- st_transform(mangrove.2020,crs=8857)
mangrove.2020<- mangrove.2020 %>% select(-Area)
mangrove.2020$year<- 2020
mangrove.2020.clipped<- st_filter(mangrove.2020,scapes)

mangrove.2019<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2019_vec.shp")
mangrove.2019<- st_transform(mangrove.2019,crs=8857)
mangrove.2019$year<- 2019
mangrove.2019.clipped<- st_filter(mangrove.2019,scapes)

mangrove.2018<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2018_vec.shp")
mangrove.2018<- st_transform(mangrove.2018,crs=8857)
mangrove.2018$year<- 2018
mangrove.2018.clipped<- st_filter(mangrove.2018,scapes)


mangrove.2017<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2017_vec.shp")
mangrove.2017<- st_transform(mangrove.2017,crs=8857)
mangrove.2017$year<- 2017
mangrove.2017.clipped<- st_filter(mangrove.2017,scapes)

mangrove.2016<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2016_vec.shp")
mangrove.2016<- st_transform(mangrove.2016,crs=8857)
mangrove.2016$year<- 2016
mangrove.2016.clipped<- st_filter(mangrove.2016,scapes)

mangrove.2015<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2015_vec.shp")
mangrove.2015<- st_transform(mangrove.2015,crs=8857)
mangrove.2015$year<- 2015
mangrove.2015.clipped<- st_filter(mangrove.2015,scapes)

mangrove.2014<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2014_vec.shp")
mangrove.2014<- st_transform(mangrove.2014,crs=8857)
mangrove.2014$year<- 2014
mangrove.2014.clipped<- st_filter(mangrove.2014,scapes)

mangrove.2013<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2013_vec.shp")
mangrove.2013<- st_transform(mangrove.2013,crs=8857)
mangrove.2013$year<- 2013
mangrove.2013.clipped<- st_filter(mangrove.2013,scapes)

mangrove.2012<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2012_vec.shp")
mangrove.2012<- st_transform(mangrove.2012,crs=8857)
mangrove.2012$year<- 2012
mangrove.2012.clipped<- st_filter(mangrove.2012,scapes)

mangrove.2011<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2011_vec.shp")
mangrove.2011<- st_transform(mangrove.2011,crs=8857)
mangrove.2011$year<- 2011
mangrove.2011.clipped<- st_filter(mangrove.2011,scapes)

mangrove.2010<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2010_vec.shp")
mangrove.2010<- st_transform(mangrove.2010,crs=8857)
mangrove.2010$year<- 2010
mangrove.2010.clipped<- st_filter(mangrove.2010,scapes)

mangrove.2009<- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2009_vec.shp")
mangrove.2009<- st_transform(mangrove.2009,crs=8857)
mangrove.2009$year<- 2009
mangrove.2009.clipped<- st_filter(mangrove.2009,scapes)

# For 2008
mangrove.2008 <- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2008_vec.shp")
mangrove.2008 <- st_transform(mangrove.2008, crs = 8857)
mangrove.2008$year <- 2008
mangrove.2008.clipped <- st_filter(mangrove.2008, scapes)

# For 2007
mangrove.2007 <- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_2007_vec.shp")
mangrove.2007 <- st_transform(mangrove.2007, crs = 8857)
mangrove.2007$year <- 2007
mangrove.2007.clipped <- st_filter(mangrove.2007, scapes)

# For 1996
mangrove.1996 <- st_read("Ecosystem Structure_Mangrove Habitat Extent/gmw_v3_2020_vec/gmw_v3_1996_vec.shp")
mangrove.1996 <- st_transform(mangrove.1996, crs = 8857)
mangrove.1996$year <- 1996
mangrove.1996.clipped <- st_filter(mangrove.1996, scapes)


#Binding all my years together
mangrove.clipped<- rbind(mangrove.2019.clipped,mangrove.2020.clipped)

scapes.name<- scapes %>% select(Scape)

#intersection with scapes
mangrove.clipped.name<- st_intersection(mangrove.clipped,scapes.name)

#Do area calculations
mangrove.clipped.name$area<- st_area(mangrove.clipped.name)

#turn it into a data frame for faster processing
mangrove.agg<- as.data.frame(mangrove.clipped.name) %>%
  select(-geometry) %>%
  group_by(Scape,year) %>%
  summarise(area_scape = sum(area,na.rm=T)) %>%
  ungroup()

#pivot the table for correct format
mangrove.agg.sf<- scapes %>%
  left_join(mangrove.agg,by="Scape") %>%
  pivot_wider(names_from = year,values_from = area_scape)
  

#Save Mangrove.agg.sf

  