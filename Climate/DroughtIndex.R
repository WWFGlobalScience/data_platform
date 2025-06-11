library(raster)
library(sf)
library(ggplot2)
library(dplyr)
library(tidyr)

pdsi_raster<- brick("DroughtData/global_SCPDSI_1990-2023.tif")
Scapes <- st_read(dsn = "ESSFUseCase/ESSFUseCase.gdb", layer = "Prod_scapes_EE")

#Add unique ID for the raster join
Scapes$unique_row_id <- 1:nrow(Scapes)

print(st_crs(pdsi_raster))
print(st_crs(Scapes))

target_crs_proj4 <- st_crs(Scapes)$proj4string

pdsi_raster_project <- projectRaster(pdsi_raster, crs = target_crs_proj4)
print(crs(pdsi_raster_project))

pdsi_max <- raster::extract(pdsi_raster_project, Scapes, fun = max, na.rm = TRUE, df = TRUE)
pdsi_min <- raster::extract(pdsi_raster_project, Scapes, fun = min, na.rm = TRUE, df = TRUE)

# --- Process Extracted Data for Chronology and Plotting ---

# Generate dates (as before)
start_date <- as.Date("1990-01-01")
end_date <- as.Date("2022-12-01")
dates <- seq(from = start_date, to = end_date, by = "month")

if (length(dates) != nlayers(pdsi_raster_project)) {
  stop("Number of generated dates does not match the number of raster layers.
        Please adjust start_date, end_date, or 'by' argument for date sequence generation.")
}

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

# Combine Max and Min data
pdsi_combined_long <- pdsi_max_long %>%
  left_join(pdsi_min_long, by = c("ID", "Date"))

# --- Step 2: Join with Scapes attributes ---
# Select the original ID and Name columns from your Scapes shapefile
# and ensure they are linked by our temporary 'unique_row_id'
scapes_attributes_to_join <- st_drop_geometry(Scapes) %>%
  select(
    unique_row_id, # This is the ID that matches 'ID' from raster::extract
    # Replace 'Your_Original_ID_Column' and 'Your_Name_Column' with actual names from Scapes
    Name,
    ID,
    Country
  )

# Now, join with the combined data.
# The 'ID' column in pdsi_combined_long is the 'unique_row_id' from Scapes.
pdsi_final_data <- pdsi_combined_long %>%
  left_join(scapes_attributes_to_join, by = c("ID" = "unique_row_id")) # Match 'ID' from extracted data to 'unique_row_id' from Scapes

unique_scapes <- unique(pdsi_final_data$Name)

output_dir <- "DroughtIndex_Plots"

# Plotting both Max and Min PDSI for a single landscape by its original name
# Get all data for the current scape, across all countries it might overlap with
for (OPScape in unique_scapes){
  scape_specific_data <- pdsi_final_data %>%
    filter(Name == OPScape)
  
  message(paste("\n---Processing Scape:",OPScape,"----"))
  
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
  
  filename_safe_name <- gsub("[^A-Za-z0-9_.-]", "_", OPScape)
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
