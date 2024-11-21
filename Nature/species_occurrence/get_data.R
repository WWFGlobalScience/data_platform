# Set R environment -------------------------------------------------------

library(usethis)

##Open blank R environment file (will open in new window)
usethis::edit_r_environ()

##Manually paste the following information in the opened file (or add your personal GBIF credentials), save file
GBIF_USER="scheng_wwf"
GBIF_PWD="Dataplatform2024"
GBIF_EMAIL="samantha.cheng@wwfus.org"

##Restart R session

# Retrieve desired species data from GBIF ---------------------------------

library(rgbif)
library(sf)
library(dplyr)

# Read in any existing species information
species_list <- read.csv("WWF Focal Species_11-19-2024.csv", header = TRUE)
species_list$Species.group <- tolower(species_list$Species.group)

# Define variables
species <- c("sea turtles") #Options are: wwf, sturgeons, bison, migratory birds, migratory fish, bears, big cats, elephants, rhinos, apes, sea turtles, whales, dolphins and porpoises)

# Define species list
if (species == "wwf") {
  selected <- species_list
} else {
  selected <- filter(species_list, Species.group == paste(species))
}
   
myspecies <- paste(names(selected$Scientific.Name), selected$Scientific.Name, sep="")
  
# Get taxon keys
taxon_keys <- sapply(myspecies, function(species) {
  key <- name_backbone(species)$usageKey
  return(key)
})

# Try the download with simplified predicates
data <- occ_download(
  pred_in("taxonKey", unname(taxon_keys)), #only those we specified
  pred("hasGeospatialIssue", FALSE), #removes those with spatial probelms
  pred("hasCoordinate", TRUE), #only those with coordinates
  pred("occurrenceStatus","PRESENT"), #removes absence data
  pred_gte("year", 1900), # 1990 and onward
  pred_not(pred_in("basisOfRecord",c("FOSSIL_SPECIMEN","LIVING_SPECIMEN"))), #no fossils or living specimens
  format = "SIMPLE_CSV",
  user = Sys.getenv("GBIF_USER"),
  pwd = Sys.getenv("GBIF_PWD"),
  email = Sys.getenv("GBIF_EMAIL")
)

# Print download information and citation
print(data)

# Wait for the download to complete - this checks whether the request status it needs to be completed before moving on.
occ_download_wait(data)

# Get the download and import it into R
sp_data <- occ_download_get(data) %>%
  occ_download_import()

# Save the full species data to a RDS file
saveRDS(sp_data, paste0("processed_data/",species,"_occurrences_",Sys.Date(),".rds"))

# Convert to spatial data frame with species information
species_sf <- sp_data %>%
  filter(!is.na(decimalLongitude) & !is.na(decimalLatitude)) %>%
  # select(gbifID, decimalLongitude, decimalLatitude, species, 
  #        individualCount, occurrenceStatus, eventDate, year,
  #        coordinateUncertaintyInMeters) %>%
  st_as_sf(coords = c("decimalLongitude", "decimalLatitude"), 
           crs = 4326)

#Save full species shapefile
st_write(species_sf, paste0("processed_data/",species,"_occurrences_",Sys.Date(),".shp"))

# Print citation information to file
sink(file = paste0(species,"_citation.txt"))
data
sink(file = NULL)
