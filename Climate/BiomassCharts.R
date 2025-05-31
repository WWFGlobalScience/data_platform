library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(scatterpie)
library(readr)

# --- Data Preparation Section ---
# Data is assumed to be downloaded directly from Google Earth Engine (GEE).
# The original GEE script is referenced for context: https://code.earthengine.google.com/8db981c5ce05183263088f1626f40a6a

# Define the years for which AGB (Above Ground Biomass) data files exist.
# These years correspond to the suffixes in the CSV filenames.
years <- c(2010, 2015, 2016, 2017, 2018, 2019, 2020, 2021)

# Use `lapply` to efficiently read and process each AGB data file for the defined years.
# `lapply` iterates over the `years` vector, applying an anonymous function to each year.
lapply(years, function(year) {
  # Construct the full file path for the current year's CSV file.
  # Files are expected in a 'Biomass/GEE_Download' subdirectory.
  file_path <- file.path("Biomass", "GEE_Download", paste0("AGB_Sum", year, ".csv"))
  
  # Read the CSV file.
  # `sep = ","` explicitly sets the delimiter to comma.
  # `[, 2:6]` selects columns from the 2nd to the 6th, as the first column is often an index.
  df <- read.csv(file_path, sep = ",")[, 2:6]
  
  # Rename the biomass column. The GEE output often has a generic name like "AGB_Mg_2021"
  # regardless of the actual year in the filename. This line renames it to the specific year
  # to make column names consistent with the data they represent.
  names(df)[names(df) == "AGB_Mg_2021"] <- as.character(year) # Ensure year is character for column name
  
  # Assign the processed data frame to a variable in the global environment.
  # The variable name will be in the format `AGB_YYYY` (e.g., AGB_2010, AGB_2015).
  # This makes each year's data frame accessible for subsequent merging.
  assign(paste0("AGB_", year), df, envir = .GlobalEnv)
})

# Create a list containing all the individual AGB data frames that were just loaded.
# This list will be used for merging them into a single, comprehensive data frame.
all_agb_dfs <- list(AGB_2010, AGB_2015, AGB_2016, AGB_2017,
                    AGB_2018, AGB_2019, AGB_2020, AGB_2021)

# Define the common columns that will be used as keys for merging the data frames.
# These columns identify unique geographic/administrative units.
common_cols <- c("ID", "Name", "Country", "Area_km2") 

# Use `Reduce` to perform a series of merges.
# `Reduce` applies a function cumulatively to the elements of a list.
# Here, it iteratively merges each data frame in `all_agb_dfs` with the result of the previous merge.
# `all = TRUE` ensures that all rows are kept, even if a particular ID/Name combination
# doesn't exist in all years (resulting in NAs for missing year's biomass).
AGB_allyears <- Reduce(function(x, y) merge(x, y, by = common_cols, all = TRUE), all_agb_dfs)

# Extract unique "Name" values from the merged data.
# These "Names" likely represent specific landscapes or areas for which individual plots will be generated.
unique_scapes <- unique(AGB_allyears$Name)

# Pivot the `AGB_allyears` data frame from a wide format to a long format.
# This is crucial for `ggplot2` to easily create time-series plots, as it expects
# a 'Year' column and a 'Biomass' column.
Biomasslong_plot <- pivot_longer(
  AGB_allyears,
  cols = -c(ID, Name, Country, Area_km2), # All columns EXCEPT these are pivoted
  names_to = "Year",                      # New column to store the original column names (years)
  values_to = "Biomass"                   # New column to store the values from the pivoted columns
)

# Convert the 'Year' column to a numeric type. It was a character after pivoting.
Biomasslong_plot$Year <- as.numeric(Biomasslong_plot$Year)
# Convert the 'Biomass' column to a numeric type.
Biomasslong_plot$Biomass <- as.numeric(Biomasslong_plot$Biomass)

# Convert biomass from Mg (Megagrams) to MtCO2e (Million tonnes of CO2 equivalent).
# Assuming a conversion factor or simply dividing by 1,000,000 to get millions of Mg,
# which might then be interpreted as MtCO2e depending on the original units and context.
# Note: The conversion from Mg AGB to MtCO2e typically involves a carbon fraction and
# a CO2 conversion factor (e.g., 3.67 for C to CO2). This line only divides by 1 million.
Biomasslong_plot$Biomass <- Biomasslong_plot$Biomass / 1000000

# Define the output directory where the generated plots will be saved.
output_dir <- "Biomass_Plots"

# Create the output directory if it doesn't already exist.
# `recursive = TRUE` ensures that parent directories are also created if needed.
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# --- Plotting Loop Section ---
# Loop through each unique landscape ('OPScape') to generate a separate plot for each.
for (OPScape in unique_scapes) {
  # Display a message indicating which scape is currently being processed.
  message(paste("\n---Processing Scape:", OPScape, "----"))
  
  # Filter the long-format biomass data to get only the data for the current landscape.
  # This ensures that each plot shows the biomass trend for a single 'Name'.
  scape_specific_data <- Biomasslong_plot %>%
    filter(Name == OPScape)
  
  # Create the ggplot object for the current landscape.
  Biomass_plot <- ggplot(scape_specific_data, aes(x = Year, y = Biomass, group = 1)) +
    # Add a line geom to show the trend over time.
    # `color` and `size` are set for visual aesthetics.
    geom_line(color = "steelblue", size = 1.2) +
    # Add points to mark the specific data points for each year.
    # `color`, `size`, and `shape` are set for visual aesthetics.
    geom_point(color = "darkred", size = 3, shape = 16) +
    # Define plot labels (title, x-axis, y-axis, and fill legend title).
    # `expression(MtCO[2]*e)` is used for proper subscript formatting of CO2e.
    labs(title = OPScape,
         x = "Year",
         y = expression(MtCO[2]*e), # Correct LaTeX-like formatting for CO2e
         fill = "") +
    # Apply a minimal theme for a clean look.
    theme_minimal() +
    # Customize theme elements for better readability and presentation.
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"), # Center and bold the plot title
      axis.title = element_text(face = "bold")             # Bold the axis titles
    ) +
    # Set the x-axis breaks to correspond to the specific years in the data.
    scale_x_continuous(breaks = years)
  
  # Print the generated plot to the R graphics device (useful for interactive viewing).
  print(Biomass_plot)
  
  # Sanitize the scape name to create a valid filename.
  # This replaces any characters that are not letters, numbers, underscores, hyphens, or periods with underscores.
  sane_scape_name <- gsub("[^a-zA-Z0-9_.-]", "_", OPScape)
  # Construct the full path for saving the plot, including the output directory and sanitized filename.
  plot_filename <- file.path(output_dir, paste0("Biomass_", sane_scape_name, ".png"))
  
  # Save the plot to a PNG file.
  # `filename`: The path and name of the file to save.
  # `plot`: The ggplot object to save.
  # `width`, `height`: Dimensions of the saved image in inches.
  # `dpi`: Resolution of the image (dots per inch).
  ggsave(filename = plot_filename, plot = Biomass_plot, width = 12, height = 7, dpi = 300)
  # Display a message confirming that the plot has been saved.
  message(paste("Saved plot:", plot_filename))
}
