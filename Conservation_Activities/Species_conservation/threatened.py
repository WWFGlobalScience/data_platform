import arcpy
import csv
import os
from datetime import datetime

# Set workspace and allow overwriting
arcpy.env.overwriteOutput = True

# ============================================
# CONFIGURATION - Update these paths
# ============================================

# Single feature class containing multiple landscape polygons
# Each polygon should have a name/ID field to identify it
# Specify the path to the folder containing the feature class with the polygons
landscapes_layer = r"***"
landscape_name_field = "ID"  # Field that contains the landscape name/ID. ID used because landscape names makes script fail

# Main folder containing species layers (will search all subfolders)
species_main_folder = r"***"
# The script will automatically search all subfolders for shapefiles and geodatabases

# Or use a single geodatabase:
# species_main_folder = r"C:\GIS_Data\MyProject.gdb"

# Output CSV folder and base filename
output_folder = r"***"
output_base_name = "landscape_species_counts"  # Timestamp will be added automatically

# ============================================
# OUTPUT DETAIL SETTING
# ============================================
# Set to True to include detailed breakdown by species layer
# Set to False for summary only (Landscape, Total Count)
include_species_details = False  # TOGGLE THIS: True = detailed, False = summary only

# ============================================
# SETUP
# ============================================

# Generate timestamped output filename
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
csvOutput = os.path.join(output_folder, f"{output_base_name}_{timestamp}.csv")

print("Starting spatial analysis using Select by Location...")
if include_species_details:
    print("Output mode: DETAILED (includes breakdown by species layer)")
else:
    print("Output mode: SUMMARY (landscape totals only)")
print(f"Results will be saved to: {csvOutput}")
print("-" * 60)

# Verify landscapes layer exists
if not arcpy.Exists(landscapes_layer):
    print(f"ERROR: Landscapes layer not found: {landscapes_layer}")
    exit()

# Get list of all species feature classes (searches all subfolders)
species_paths = []

if species_main_folder.endswith('.gdb'):
    # It's a geodatabase - list all feature classes
    arcpy.env.workspace = species_main_folder
    species_layers = arcpy.ListFeatureClasses()
    species_paths = [os.path.join(species_main_folder, fc) for fc in species_layers]
    print(f"Searching geodatabase: {species_main_folder}")
else:
    # It's a folder - search all subfolders for shapefiles
    print(f"Searching main folder and all subfolders: {species_main_folder}")

    for root, dirs, files in os.walk(species_main_folder):
        for file in files:
            if file.endswith('.shp'):
                full_path = os.path.join(root, file)
                species_paths.append(full_path)
                # Print folder name for organization
                subfolder = os.path.basename(root)
                print(f"  Found: {file} in subfolder '{subfolder}'")

    # Also search for geodatabases in subfolders
    for root, dirs, files in os.walk(species_main_folder):
        for dir_name in dirs:
            if dir_name.endswith('.gdb'):
                gdb_path = os.path.join(root, dir_name)
                arcpy.env.workspace = gdb_path
                gdb_feature_classes = arcpy.ListFeatureClasses()
                if gdb_feature_classes:
                    print(f"  Found geodatabase: {dir_name}")
                    for fc in gdb_feature_classes:
                        fc_path = os.path.join(gdb_path, fc)
                        species_paths.append(fc_path)
                        print(f"    Found: {fc}")

print(f"\nTotal species layers found: {len(species_paths)}")

# Get list of all landscape features
landscape_cursor = arcpy.da.SearchCursor(landscapes_layer, [landscape_name_field, "OID@"])
landscapes = [(row[0], row[1]) for row in landscape_cursor]
del landscape_cursor

print(f"Found {len(landscapes)} landscape polygons in: {landscapes_layer}")
print("-" * 60)

# ============================================
# ANALYSIS
# ============================================

results = []
# Set header based on detail level
if include_species_details:
    results.append(["Landscape", "Species Layer", "Count"])
else:
    results.append(["Landscape", "Count"])

# Process each landscape polygon
for landscape_name, landscape_oid in landscapes:
    print(f"\nProcessing landscape: {landscape_name}")

    # Create a layer for this specific landscape polygon
    landscape_layer = "landscape_layer"
    arcpy.management.MakeFeatureLayer(landscapes_layer, landscape_layer)

    # Select just this landscape polygon
    where_clause = f"{arcpy.AddFieldDelimiters(landscapes_layer, landscape_name_field)} = '{landscape_name}'"
    arcpy.management.SelectLayerByAttribute(landscape_layer, "NEW_SELECTION", where_clause)

    total_species_count = 0

    # Process each species layer
    for species_path in species_paths:
        species_name = os.path.splitext(os.path.basename(species_path))[0]

        # Print progress (always show during processing)
        print(f"  Checking species layer: {species_name}...", end=" ")

        try:
            # Create temporary feature layer for the species data
            temp_species_layer = f"temp_species_{species_name}"
            arcpy.management.MakeFeatureLayer(species_path, temp_species_layer)

            # Select species features that intersect with this landscape
            arcpy.management.SelectLayerByLocation(
                temp_species_layer,
                "INTERSECT",
                landscape_layer,
                selection_type="NEW_SELECTION"
            )

            # Count selected features
            count = int(arcpy.management.GetCount(temp_species_layer)[0])
            print(f"{count} features")

            # Store detailed result only if requested
            if include_species_details:
                results.append([landscape_name, species_name, count])

            total_species_count += count

            # Clean up temporary layer
            arcpy.management.Delete(temp_species_layer)

        except Exception as e:
            print(f"ERROR: {str(e)}")
            if include_species_details:
                results.append([landscape_name, species_name, f"ERROR"])

    # Add total for this landscape - format depends on detail level
    if include_species_details:
        results.append([landscape_name, "TOTAL", total_species_count])
        results.append(["", "", ""])  # Blank row for readability
    else:
        # Summary mode - just landscape name and total
        results.append([landscape_name, total_species_count])

    print(f"  Total species count for {landscape_name}: {total_species_count}")

    # Clean up landscape layer
    arcpy.management.Delete(landscape_layer)

# ============================================
# WRITE RESULTS TO CSV
# ============================================

print("\n" + "-" * 60)
print("Writing results to CSV...")

try:
    with open(csvOutput, 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerows(results)
    print(f"SUCCESS! Results written to: {csvOutput}")
except Exception as e:
    print(f"ERROR writing CSV: {str(e)}")

print("\nAnalysis complete!")
print(f"Total landscapes processed: {len(landscapes)}")
print(f"Total species layers processed: {len(species_paths)}")