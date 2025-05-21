library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(scatterpie)
library(readxl)

#Prepare the data
EmissionFossil <- read_excel("GHGEmission/LatestData/Fossil_2024.xlsx", sheet = 2, skip = 11) #direct download from Global Carbon Budget
EmissionLULUCF <- read_excel("GHGEmission/LatestData/LULUCF_2024.xlsx", sheet = 2) #Calculated the average of four bookkeeping models that is directly downloaded from Global Carbon Budget

names(EmissionFossil)[colnames(EmissionFossil)=="...1"] <- "Year"
EmissionFossil <- subset(EmissionFossil, Year >=1990)
EmissionFossil <- EmissionFossil[,1:(ncol(EmissionFossil)-16)]
Fossil_long <- pivot_longer(
  EmissionFossil,
  cols = -Year,
  names_to = "Country",
  values_to = "Fossil"
)

names(EmissionLULUCF)[colnames(EmissionLULUCF)=="unit: Tg C/year"] <- "Year"
EmissionLULUCF <- subset(EmissionLULUCF, Year >=1990)
EmissionLULUCF <- EmissionLULUCF[,1:(ncol(EmissionLULUCF)-4)]
LULUCF_long <- pivot_longer(
  EmissionLULUCF,
  cols = -Year,
  names_to = "Country",
  values_to = "LULUCF"
)

#common country names across two datasets
common_cols <- intersect(names(EmissionLULUCF), names(EmissionFossil))
#only 197 countries are in common between the two datasets

#Combine the two datasets
EmissionsData_long <- merge(LULUCF_long, Fossil_long, by = c("Country","Year"), all = TRUE )
EmissionsData_long[is.na(EmissionsData_long)] <- 0

# #Read country shapefile
# Countries_Sf <- st_read(dsn = "ESSFUseCase/ESSFUseCase.gdb", layer = "World_Countries_Gene_Project") #Country shapefile downloaded from living atlas
# plot(st_geometry(Countries_Sf),main = "World Countries")
# print(st_crs(Countries_Sf))

Scapes <- st_read(dsn = "ESSFUseCase/ESSFUseCase.gdb", layer = "Prod_scapes_EE")
print(st_crs(Scapes))
#plot(st_geometry(Scapes), main = "Scape")


# Check CRS of both layers
crs_landscape <- st_crs(Scapes)
#crs_countries <- st_crs(Countries_Sf)

print(paste("Landscape CRS:", crs_landscape$input))
#print(paste("Countries CRS:", crs_countries$input))

scape_sf <- st_make_valid(Scapes)
#Countries_Sf <- st_make_valid(crs_countries)

#Clip the country data to the operational landscapes
#Scapes_countries <- st_intersection(Countries_Sf,scape_sf)
#plot(st_geometry(Scapes_countries),main = "Countries")

Scapes_countriesdf <- scape_sf %>%
  select(Name, Country) %>%
  st_drop_geometry() %>%
  as_tibble() %>%
  rename(
    Scape = Name,
    Country = Country
  )%>%
  mutate(
    Scape = as.factor(Scape),
    Country = as.factor(Country)
  )

Scapes_EmissionsData_long <- merge(EmissionsData_long, Scapes_countriesdf, by = c("Country"))

Emissions_plot <- pivot_longer(
  Scapes_EmissionsData_long,
  cols = -c(Year,Scape,Country)
)

unique_scapes <- unique(Scapes_EmissionsData_long$Scape)

output_dir <- "GHGEmissions_Plots"

#start adding loop from here

for (OPScape in unique_scapes){
  
  message(paste("\n---Processing Scape:",OPScape,"----"))
  
  # Get all data for the current scape, across all countries it might overlap with
  scape_specific_data <- Emissions_plot %>%
  filter(Scape == OPScape)
  
  # Identify unique countries within this specific scape
  unique_countries_in_scape <- unique(scape_specific_data$Country)
  
 
  Emission_plot <- ggplot(scape_specific_data, aes(x=Year, y=value, fill=name))+
    geom_area()+
    #scale_x_continuous(breaks = seq(min(scape_specific_data$year), max(EGR_aggregated$year), by = 10))+
    scale_fill_manual(values = c("LULUCF" = "green", "Fossil" = "#1A2B3C")) +
    labs(title=OPScape,
         x="Year",
         y=expression(MtCO[2]*e),
         fill="")+
    theme_minimal()+
    theme(legend.position = "bottom")
  
  if (length(unique_countries_in_scape) > 1) {
    Emission_plot <- Emission_plot + facet_grid(Country~., scales = "free_y") + # Facet by Country
      theme(strip.text = element_text(face = "bold")) # Make facet labels bold
    message(paste("Applying facet_grid for multiple countries in Scape:", OPScape))
  } else {
    # If only one country, adjust title to include country name
    Emission_plot <- Emission_plot + labs(title=paste(unique_countries_in_scape[1], "for", OPScape))
    message(paste("Generating single plot for Scape:", OPScape, "and Country:", unique_countries_in_scape[1]))
  }
  print(Emission_plot)
  
  # Sanitize scape name for filename
  sane_scape_name <- gsub("[^a-zA-Z0-9_.-]", "_", OPScape)
  plot_filename <- file.path(output_dir, paste0("Emission_", sane_scape_name, ".png"))
  
  ggsave(filename = plot_filename, plot = Emission_plot, width = 12, height = 7, dpi = 300)
  message(paste("Saved plot:", plot_filename))
  
}

