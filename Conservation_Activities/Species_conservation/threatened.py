# This notebook script runs within ArcGIS Pro with a group layer of landscapes and group layer of threatened species groups
import arcpy, csv

arcpy.env.overwriteOutput = True
project = arcpy.mp.ArcGISProject("CURRENT")
active_map = project.activeMap

layers = active_map.listLayers()  # all the layers in the map
lssppdata = []
# path to output csv
csvOutput = r""

for l in layers:
    if l.isGroupLayer and l.name == "Landscapes":  # layer group with the landscapes each as a separate layer
        lslayers = l.listLayers()

for l in layers:
    if l.isGroupLayer and l.name == "Spp":  # layer group with the species groups layers
        spplayers = l.listLayers()

for lslayer in lslayers:
    print(lslayer)
    sppdata = []
    sppdata.append([lslayer.name, ])
    sppCount = 0
    for lyr in spplayers:
        print(lyr)
        arcpy.management.SelectLayerByLocation(lyr, "INTERSECT", lslayer)
        selected = arcpy.da.SearchCursor(lyr, ["*"])
        rows = [row for row in arcpy.da.SearchCursor(lyr, ["*"])]
        sppdata.append([lyr.name, len(rows)])
        sppCount = sppCount + len(rows)
    # Get total
    sppdata.append(["TOTAL COUNT", sppCount])
    lssppdata.extend(sppdata)

with open(csvOutput, 'w', newline='') as file:
    writer = csv.writer(file)
    writer.writerows(lssppdata)
print("Data has been written successfully.")