# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(raster)
library(sf)
library(ggplot2)
library(dplyr)
library(tidyr)

# ------------------------------------------------------------------------------
# Load input data
# ------------------------------------------------------------------------------

# Load the monthly global scPDSI raster
# Each layer corresponds to one month from 1990 onward
# Source: https://crudata.uea.ac.uk/cru/data/drought/

pdsi_raster<- brick("DroughtData/global_SCPDSI_1990-2023.tif") 

# Load landscape polygons from a File Geodatabase
Scapes <- st_read(dsn = "ESSFUseCase/ESSFUseCase.gdb", layer = "Prod_scapes_EE")

# ------------------------------------------------------------------------------
# Prepare spatial data
# ------------------------------------------------------------------------------

# Add a temporary unique row ID to the polygon data
# This is used later to correctly join raster extraction results
Scapes$unique_row_id <- 1:nrow(Scapes)

# Print coordinate reference systems (CRS) for checking consistency
print(st_crs(pdsi_raster))
print(st_crs(Scapes))

# Extract the CRS of the polygons as a PROJ.4 string
# (Used to reproject the raster to match the polygons)
target_crs_proj4 <- st_crs(Scapes)$proj4string

# Reproject the scPDSI raster to match the polygon CRS
pdsi_raster_project <- projectRaster(pdsi_raster, crs = target_crs_proj4)
print(crs(pdsi_raster_project))

# ------------------------------------------------------------------------------
# Extract raster values for each polygon
# ------------------------------------------------------------------------------

# Extract the maximum scPDSI value per polygon for each raster layer (month)
# Returns a data frame with one row per polygon and one column per raster layer
pdsi_max <- raster::extract(pdsi_raster_project, Scapes, fun = max, na.rm = TRUE, df = TRUE)

# Extract the minimum scPDSI value per polygon for each raster layer (month)
pdsi_min <- raster::extract(pdsi_raster_project, Scapes, fun = min, na.rm = TRUE, df = TRUE)

# ------------------------------------------------------------------------------
# Generate dates corresponding to raster layers
# ------------------------------------------------------------------------------
# Define start and end dates for the scPDSI time series
start_date <- as.Date("1990-01-01")
end_date <- as.Date("2022-12-01")

# Generate a monthly sequence of dates
dates <- seq(from = start_date, to = end_date, by = "month")

# Ensure that the number of dates matches the number of raster layers
# This is a safety check to prevent misalignment
if (length(dates) != nlayers(pdsi_raster_project)) {
  stop("Number of generated dates does not match the number of raster layers.
        Please adjust start_date, end_date, or 'by' argument for date sequence generation.")
}

# ------------------------------------------------------------------------------
# Reshape extracted raster data into long (tidy) format
# ------------------------------------------------------------------------------
# Rename columns to dates and pivot to long format for max values
names(pdsi_max)[-1] <- as.character(dates)
pdsi_max_long <- pdsi_max %>%
  pivot_longer(
    cols = -ID, # 'ID' here is the `raster::extract` generated ID (which is our unique_row_id)
    names_to = "Date",
    values_to = "Max_PDSI"
  ) %>%
  mutate(Date = as.Date(Date))

# Rename columns to dates and pivot to long format for min values
names(pdsi_min)[-1] <- as.character(dates)
pdsi_min_long <- pdsi_min %>%
  pivot_longer(
    cols = -ID, # 'ID' here is the `raster::extract` generated ID (which is our unique_row_id)
    names_to = "Date",
    values_to = "Min_PDSI"
  ) %>%
  mutate(Date = as.Date(Date))

# ------------------------------------------------------------------------------
# Combine minimum and maximum PDSI values
# ------------------------------------------------------------------------------

# Join min and max PDSI values by polygon ID and date
pdsi_combined_long <- pdsi_max_long %>%
  left_join(pdsi_min_long, by = c("ID", "Date"))

# ------------------------------------------------------------------------------
# Join scPDSI data with polygon attributes
# ------------------------------------------------------------------------------

# Drop geometry and select relevant attributes from the polygon data
scapes_attributes_to_join <- st_drop_geometry(Scapes) %>%
  select(
    unique_row_id, #Temporary ID created earlier
    Name,          # Landscape name
    ID,            # Original polygon ID
    Country        # Country attribute
  )

# Join attribute data to the scPDSI time series
# The 'ID' column from raster::extract matches 'unique_row_id'
pdsi_final_data <- pdsi_combined_long %>%
  left_join(scapes_attributes_to_join, by = c("ID" = "unique_row_id")) 

# ------------------------------------------------------------------------------
# Prepare plotting
# ------------------------------------------------------------------------------
# Get unique landscape names
unique_scapes <- unique(pdsi_final_data$Name)

# Define output directory for plots
output_dir <- "DroughtIndex_Plots"

# ------------------------------------------------------------------------------
# Generate plots for each landscape
# ------------------------------------------------------------------------------

#Loop through each unique landscape
for (OPScape in unique_scapes){
  #subset data for current landscape
  scape_specific_data <- pdsi_final_data %>%
    filter(Name == OPScape)
  
  message(paste("\n---Processing Scape:",OPScape,"----"))

  #create time series plot showing min-max scPDSI envelope
  p <- ggplot(scape_specific_data, aes(x = Date)) +
    geom_ribbon(aes(ymin = Min_PDSI, ymax = Max_PDSI), fill = "skyblue", alpha = 0.5) +
    geom_line(aes(y = Max_PDSI, color = "Maximum"), size = 1) +
    geom_line(aes(y = Min_PDSI, color = "Minimum"), size = 1, linetype = "dashed") +
    labs(
      title = paste("scPDSI Range for:", OPScape),
      x = "Date",
      y = "scPDSI"
    ) +
    scale_color_manual(
      name = " ",
      values = c("Maximum" = "blue", "Minimum" = "red"),
      guide = guide_legend(override.aes = list(linetype = c("solid", "dashed")))
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5),
      legend.position = "bottom"
    )
  
  #sanitize landscape name 
  filename_safe_name <- gsub("[^A-Za-z0-9_.-]", "_", OPScape)
  #save plot to disk
  ggsave(
    filename = file.path(output_dir, paste0("PDSI_", filename_safe_name, ".png")),
    plot = p,
    width = 10,
    height = 6,
    dpi = 300
  )
  
  cat("Generated plot for:", OPScape, "\n")
  
}

cat("\nAll plots generated and saved to:", output_dir, "\n")


