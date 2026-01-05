# ------------------------------------------------------------------------------
# Load required libraries
# ------------------------------------------------------------------------------

library(sf)            # For reading and handling spatial (vector) data
library(dplyr)         # For data manipulation (filtering, mutating, joining)
library(tidyr)         # For reshaping data between wide and long formats
library(ggplot2)       # For plotting
library(lubridate)     # For working with dates
library(scatterpie)    # For pie-chart style visualizations (not used directly here)
library(readxl)        # For reading Excel files


# ------------------------------------------------------------------------------
# Prepare emissions data
# ------------------------------------------------------------------------------

# Read fossil fuel emissions data from the Global Carbon Budget
# Source: https://globalcarbonbudget.org/the-latest-gcb-data/
# Data are read from the second sheet, skipping header rows
EmissionFossil <- read_excel(
  "GHGEmission/LatestData/Fossil_2024.xlsx",
  sheet = 2,
  skip  = 11
)

# Read LULUCF emissions data (average of four bookkeeping models)
# Source: https://globalcarbonbudget.org/the-latest-gcb-data/
EmissionLULUCF <- read_excel(
  "GHGEmission/LatestData/LULUCF_2024.xlsx",
  sheet = 2
)

# ------------------------------------------------------------------------------
# Clean and reshape fossil fuel emissions data
# ------------------------------------------------------------------------------

# Rename the year column (often unnamed in the original Excel file)
names(EmissionFossil)[colnames(EmissionFossil) == "...1"] <- "Year"

# Keep only data from 1990 onward
EmissionFossil <- subset(EmissionFossil, Year >= 1990)

# Remove trailing columns that do not correspond to country emissions
EmissionFossil <- EmissionFossil[, 1:(ncol(EmissionFossil) - 16)]

# Convert fossil fuel emissions data from wide to long format
Fossil_long <- pivot_longer(
  EmissionFossil,
  cols      = -Year,
  names_to  = "Country",
  values_to = "Fossil"
)


# ------------------------------------------------------------------------------
# Clean and reshape LULUCF emissions data
# ------------------------------------------------------------------------------

# Rename the year column
names(EmissionLULUCF)[colnames(EmissionLULUCF) == "unit: Tg C/year"] <- "Year"

# Keep only data from 1990 onward
EmissionLULUCF <- subset(EmissionLULUCF, Year >= 1990)

# Remove trailing columns that do not correspond to country emissions
EmissionLULUCF <- EmissionLULUCF[, 1:(ncol(EmissionLULUCF) - 4)]

# Convert LULUCF emissions data from wide to long format
LULUCF_long <- pivot_longer(
  EmissionLULUCF,
  cols      = -Year,
  names_to  = "Country",
  values_to = "LULUCF"
)


# ------------------------------------------------------------------------------
# Identify common structure across datasets
# ------------------------------------------------------------------------------

# Identify common country columns between the two datasets
# (Used only for checking overlap; not directly used later)
common_cols <- intersect(names(EmissionLULUCF), names(EmissionFossil))
# Note: Only ~197 countries are common across both datasets


# ------------------------------------------------------------------------------
# Combine fossil and LULUCF emissions data
# ------------------------------------------------------------------------------

# Merge the long-format fossil and LULUCF datasets by Country and Year
EmissionsData_long <- merge(
  LULUCF_long,
  Fossil_long,
  by  = c("Country", "Year"),
  all = TRUE
)

# Replace missing values with zeros
# This ensures both emission sources exist for all country-year combinations
EmissionsData_long[is.na(EmissionsData_long)] <- 0


# ------------------------------------------------------------------------------
# Load landscape (scape) spatial data
# ------------------------------------------------------------------------------

# Read operational landscape polygons
Scapes <- st_read(
  dsn   = "ESSFUseCase/ESSFUseCase.gdb",
  layer = "Prod_scapes_EE"
)

# Print CRS for reference
print(st_crs(Scapes))

# ------------------------------------------------------------------------------
# Check CRS information
# ------------------------------------------------------------------------------

crs_landscape <- st_crs(Scapes)
print(paste("Landscape CRS:", crs_landscape$input))


# ------------------------------------------------------------------------------
# Validate geometries
# ------------------------------------------------------------------------------

# Ensure landscape geometries are valid before spatial operations
scape_sf <- st_make_valid(Scapes)


# ------------------------------------------------------------------------------
# Prepare landscape–country lookup table
# ------------------------------------------------------------------------------

# Extract landscape–country relationships from the spatial data
# Geometry is dropped because only attribute data are needed
Scapes_countriesdf <- scape_sf %>%
  select(Name, Country) %>%
  st_drop_geometry() %>%
  as_tibble() %>%
  rename(
    Scape   = Name,
    Country = Country
  ) %>%
  mutate(
    Scape   = as.factor(Scape),
    Country = as.factor(Country)
  )


# ------------------------------------------------------------------------------
# Join emissions data with landscape information
# ------------------------------------------------------------------------------

# Attach scape information to country-level emissions data
Scapes_EmissionsData_long <- merge(
  EmissionsData_long,
  Scapes_countriesdf,
  by = c("Country")
)

# Convert emissions data to long format for plotting
Emissions_plot <- pivot_longer(
  Scapes_EmissionsData_long,
  cols = -c(Year, Scape, Country)
)


# ------------------------------------------------------------------------------
# Prepare plotting parameters
# ------------------------------------------------------------------------------

# Extract unique scapes for plotting
unique_scapes <- unique(Scapes_EmissionsData_long$Scape)

# Define output directory for emission plots
output_dir <- "GHGEmissions_Plots"


# ------------------------------------------------------------------------------
# Generate emission plots (one per landscape)
# ------------------------------------------------------------------------------

for (OPScape in unique_scapes) {

  # Print progress message
  message(paste("\n---Processing Scape:", OPScape, "----"))

  # Subset emissions data for the current landscape
  scape_specific_data <- Emissions_plot %>%
    filter(Scape == OPScape)

  # Identify unique countries represented in this scape
  unique_countries_in_scape <- unique(scape_specific_data$Country)

  # Create stacked area plot of emissions over time
  Emission_plot <- ggplot(
    scape_specific_data,
    aes(x = Year, y = value, fill = name)
  ) +
    geom_area() +
    scale_fill_manual(
      values = c("LULUCF" = "green", "Fossil" = "#1A2B3C")
    ) +
    labs(
      title = OPScape,
      x     = "Year",
      y     = expression(MtCO[2]*e),
      fill  = ""
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  # If multiple countries are associated with the scape,
  # facet the plot by country
  if (length(unique_countries_in_scape) > 1) {

    Emission_plot <- Emission_plot +
      facet_grid(Country ~ ., scales = "free_y") +
      theme(strip.text = element_text(face = "bold"))

    message(
      paste("Applying facet_grid for multiple countries in Scape:", OPScape)
    )

  } else {

    # If only one country, include country name in the title
    Emission_plot <- Emission_plot +
      labs(
        title = paste(unique_countries_in_scape[1], "for", OPScape)
      )

    message(
      paste(
        "Generating single plot for Scape:",
        OPScape,
        "and Country:",
        unique_countries_in_scape[1]
      )
    )
  }

  # Display plot in the R session
  print(Emission_plot)

  # Sanitize scape name for safe filename creation
  sane_scape_name <- gsub("[^a-zA-Z0-9_.-]", "_", OPScape)

  # Define output file path
  plot_filename <- file.path(
    output_dir,
    paste0("Emission_", sane_scape_name, ".png")
  )

  # Save plot to disk
  ggsave(
    filename = plot_filename,
    plot     = Emission_plot,
    width    = 12,
    height   = 7,
    dpi      = 300
  )

  # Confirm plot was saved
  message(paste("Saved plot:", plot_filename))
}
