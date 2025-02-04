setwd("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform")

library(tidyverse)
library(sf)

amazon<- st_read("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Pilotscapes_FFR_clip/Amazon_FFR.shp")
pantanal<- st_read("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Pilotscapes_FFR_clip/Pantanal_FFR.shp")
pilot<- st_read("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/Pilotscapes_FFR_clip/Pilot_FFR_clip_091824.shp")

pilot.scapes<- st_read("Pilot_scapes_EE/Pilot_scapes_EE.shp")
countries<- st_read("C:/Users/baezschon/OneDrive - World Wildlife Fund, Inc/Desktop/Data Platform/CountrySHP/CountrySHP/pilotcountriesjoined3.shp")

pilot.scapes.simple<- pilot.scapes %>% select(Scape)
pilot.scapes.simple<- st_transform(pilot.scapes.simple,crs=8857)

pilot.simple<- pilot %>% select(CSI,CSI_FF2)
pilot.simple<- st_transform(pilot.simple,crs=8857)

pilot_intersected<- st_intersection(st_make_valid(pilot.simple),st_make_valid(pilot.scapes.simple))

pilot_intersected$length<- st_length(pilot_intersected)
pilot_intersected$length_km<- as.numeric(pilot_intersected$length / 1000)

lines.df<- pilot_intersected %>% as.data.frame() %>% select(-geometry)

scapes<- lines.df %>%
  group_by(Scape,CSI_FF2) %>%
  summarise(length_total = sum(length_km,na.rm=T)) %>%
  ungroup()

scapes.wide<- scapes %>%
  pivot_wider(names_from = CSI_FF2,values_from = length_total) %>%
  rename(
    CSI_category_1 = '1',
    CSI_category_2 = '2',
    CSI_category_3 = '3'
  )

scapes.sf<- pilot.scapes %>%
  left_join(scapes.wide,by="Scape")
st_write(scapes.sf, "EcosystemStructure_FFRv4.GPKG", layer = "FFR", driver = "GPKG")

