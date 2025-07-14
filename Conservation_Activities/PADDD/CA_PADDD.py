#Prepare PADDD data for inclusion in data platform
#Desired output: pilot landscapes shapefile with 1 additional fields: number of PADDD events

#set workspace
scratch_ws= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb"
analysis_ws= r"L:\data_platform\Analysis\Prod_outputs\Cons_activities"

#data inputs. must be on VPN connect to Sasquatch drive. fild gdb's downloaded from Protected Planet
PADDD_folder=r"L:\data_platform\_Data\Pilots_data\Protected and Conserved Areas (PCA)_PADDD-20240920T202151Z-001\Protected and Conserved Areas (PCA)_PADDD"
PADDD_polys= f'{PADDD_folder}\PADDDtracker_DataReleaseV2_1_2021_Poly.shp'
PADDD_points= f'{PADDD_folder}\PADDDtracker_DataReleaseV2_1_2021_Pts.shp'

scapes= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb\Prod_scapes"

import arcpy
import pandas as pd
arcpy.env.workspace= scratch_ws

#Select KBA polygons that intersect with pilot landscapes, save in scratch db
polys_PS= arcpy.management.SelectLayerByLocation(PADDD_polys, "INTERSECT", scapes)

matchcount = int(arcpy.management.GetCount(polys_PS)[0]) 
print(f"polys selected: {matchcount}")

if matchcount > 0:
    #copy pts
    arcpy.management.CopyFeatures(polys_PS, 'PADDD_polys')
    print ("polys copied")
    
    #project polys
    arcpy.management.Project('PADDD_polys', 'PADDD_polys_proj', scapes)
    print("polys projected")

    #summarize polys within scapes
    arcpy.analysis.SummarizeWithin(scapes, 'PADDD_polys_proj', 'PADDD_poly_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
    print("summarize PADDD polys within pilot scapes done")

#Select points that intersect with pilot landscapes, save in scratch db
points_PS= arcpy.management.SelectLayerByLocation(PADDD_points, "INTERSECT", scapes)

matchcount2 = int(arcpy.management.GetCount(points_PS)[0]) 
print(f"pts selected: {matchcount2}")

total_paddd= matchcount + matchcount2
print(f"total PADDD events: {total_paddd}")

if matchcount2 > 0:
    #copy pts
    arcpy.management.CopyFeatures(points_PS, 'PADDD_pts')
    print ("pts copied")

    #project pts
    arcpy.management.Project('PADDD_pts', 'PADDD_pts_proj', scapes)
    print("points projected")

    #summarize pts within scapes
    arcpy.analysis.SummarizeWithin(scapes, 'PADDD_pts_proj', 'PADDD_pts_sum', sum_shape=True) #second summarize within does not like to run successfully.
    print("summarize PADDD pts within pilot scapes done")


#Join PADDD stats(point count, polygon count and polygon area) to copy of scapes dataset
if arcpy.Exists('PADDD_pts_sum'):
    arcpy.management.AlterField('PADDD_pts_sum', 'Point_Count', 'PAD_pts')
    arcpy.management.JoinField(scapes, 'ID', 'PADDD_pts_sum', 'ID', fields=['PAD_pts'])
    print("point stats joined")
else: #TODO Test
    #add blank field "PAD_pts" to scapes
    arcpy.management.AddFields(scapes, [['PAD_pts', 'SHORT']])
    print("blank field PAD_pts added")
    #replace Null with 'Other'
    with arcpy.da.UpdateCursor(scapes, ["PAD_pts"]) as cursor:
        for row in cursor:
            if row[0] == None:
                row[0] = 0
                cursor.updateRow(row)
    print ("null updated to other.")

if arcpy.Exists('PADDD_poly_sum'):
    arcpy.management.AlterField('PADDD_poly_sum', 'sum_Area_HECTARES', 'PAD_HA')
    arcpy.management.AlterField('PADDD_poly_sum', 'Polygon_Count', 'PAD_polys')
    arcpy.management.JoinField(scapes, 'ID', 'PADDD_poly_sum', 'ID', fields=['PAD_HA', 'PAD_polys'])
    print("poly stats joined")

else: #TODO Test
    #add blank fields "PAD_HA" and "PAD_polys"
    arcpy.management.AddFields(scapes, [['PAD_HA', 'SHORT'], ['PAD_polys', 'SHORT']])
    print("blank fields PAD_HA and PAD_polys added.")
    #replace Null with 'Other'
    with arcpy.da.UpdateCursor(scapes, ["PAD_HA", "PAD_polys"]) as cursor:
        for row in cursor:
            if row[0] == None:
                row[0] = 0
                cursor.updateRow(row)
    print ("null updated to other.")


arcpy.management.CalculateField(scapes, 'PAD_evts', "!PAD_polys!+!PAD_pts!", 'PYTHON', '', 'LONG')
print("Calculate field done")


