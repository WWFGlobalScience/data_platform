#Prepare ICCA data for inclusion in data platform
#Desired output: pilot landscapes shapefile with 2 additional fields. 1 for IACC area and 1 for IACC percent (percent of scape covered by IACC)


#set workspace
scratch_ws= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb"
analysis_ws= r"L:\data_platform\Analysis\Prod_outputs\Cons_activities"

#data inputs. must be on VPN connect to Sasquatch drive. file gdb's downloaded from Protected Planet
IACC_gdb= r"L:\data_platform\_Data\prod_data\icca_registry_gdb\icca_registry.gdb"
IACC_polys= f'{IACC_gdb}\icca_registry_polygon'
IACC_points= f'{IACC_gdb}\icca_registry_point'

scapes= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb\Prod_scapes"

import arcpy
import pandas as pd
import sys

arcpy.env.workspace= scratch_ws

#Select polygons that intersect with pilot landscapes, save in scratch db
polys_PS= arcpy.management.SelectLayerByLocation(IACC_polys, "INTERSECT", scapes)

matchcount = int(arcpy.management.GetCount(polys_PS)[0]) 
print(f"polys selected: {matchcount}")

if matchcount >0:
    arcpy.management.CopyFeatures(polys_PS, 'IACC_polys')
    print ("polys copied")

    # Dissolve all polys layer
    arcpy.management.Dissolve('IACC_polys', 'IACC_polys_dis', 'governance_type', multi_part=True)
    print("all polys dissolved")

#Select points that intersect with pilot landscapes, save in scratch db
points_PS= arcpy.management.SelectLayerByLocation(IACC_points, "INTERSECT", scapes)

matchcount2 = int(arcpy.management.GetCount(points_PS)[0]) 
print(f"pts selected: {matchcount2}")

if matchcount==0 & matchcount2==0: #neither points or polys
    print ("no IACC points or polygons in scapes. ")
    #add columns to scapes and fill with 0s 
    #Calculate percentage field
    arcpy.management.CalculateField(scapes, 'IACC_HA', "0", 'PYTHON', '', 'FLOAT')
    arcpy.management.CalculateField(scapes, 'IACC_pct', "0", 'PYTHON', '', 'FLOAT')

    print("Empty IACC HA and pct fields calculated")
    sys.exit()

if matchcount2 >0: #at least points intersect.
    arcpy.management.CopyFeatures(points_PS, 'IACC_pts')
    print ("pts copied")

    #Create a geodesic buffer by calculating the radius of a circle with the 'reported_area' value= reported area of the site. TODO Account for marine points ('rep_m_area')
    #calculate buffer distance field
    arcpy.management.CalculateField('IACC_pts', 'buff_dist', "(math.sqrt(float(!reported_area!)/math.pi))*1000", 'PYTHON', '', 'FLOAT') 
    arcpy.analysis.Buffer('IACC_pts', 'IACC_pts_buff', 'buff_dist', method='GEODESIC', ) #buffer calc is in meters
    print ("buffers drawn for points")

    if arcpy.Exists('IACC_polys'): #both points and polys intersect
        #union buffered points and polys
        arcpy.analysis.Union(['IACC_pts_buff', 'IACC_polys_dis'], 'IACC_union') 
        print("union done")

        #summarize union to scapes
        arcpy.analysis.SummarizeWithin(scapes, 'IACC_union', 'PS_IACC_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
        print("summarize within pilot scapes done")

    else: #only points intersect
        #summarize IACC_pts_buff to scapes
        arcpy.analysis.SummarizeWithin(scapes, 'IACC_pts_buff', 'PS_IACC_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
        print("summarize within pilot scapes done")

else: #only polys intersect
    #summarize IACC_polys_dis to scapes
    arcpy.analysis.SummarizeWithin(scapes, 'IACC_polys_dis', 'PS_IACC_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
    print("summarize within pilot scapes done")


#in any of above cases, same table output PS_IACC_sum
#Prep summary fc
arcpy.management.AlterField('PS_IACC_sum', 'sum_Area_HECTARES', 'IACC_HA')
#Calculate percentage field
arcpy.management.CalculateField('PS_IACC_sum', 'IACC_pct', "!IACC_HA!/!Area_HA!*100", 'PYTHON', '', 'FLOAT')
print("Field renamed and New pct field calculated")

# Join fields in summary fc to copy of scapes dataset
arcpy.management.JoinField(scapes, 'ID', 'PS_IACC_sum', 'ID', fields=['IACC_HA', 'IACC_pct'])
print("Joined IACC summary table to Scapes.shp")