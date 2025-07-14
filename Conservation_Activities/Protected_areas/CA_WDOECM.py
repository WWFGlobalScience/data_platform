#Prepare WDOECM data for inclusion in data platform
#Desired output: pilot landscapes shapefile with 2 additional fields. 1 for OECM area and 1 for OECM percent. (percent of scape covered by OECMs)

#set workspace
scratch_ws= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb"
analysis_ws=  r"L:\data_platform\Analysis\Prod_outputs\Cons_activities"

#data inputs. must be on VPN connect to Sasquatch drive. fild gdb's downloaded from Protected Planet
WDOECM_gdb=r"L:\data_platform\_Data\prod_data\WDOECM_May2025_Public\WDOECM_May2025_Public.gdb"
WDOECM_polys= f'{WDOECM_gdb}\WDOECM_poly_May2025'
WDOECM_points= f'{WDOECM_gdb}\WDOECM_point_May2025'

scapes= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb\Prod_scapes"
polys_all_dis= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb\polys_all_dis" #WDPA polys flat layer from WDPA script outputs.

import arcpy
arcpy.env.workspace= scratch_ws

#Select polygons that intersect with pilot landscapes, save in scratch db
polys_PS= arcpy.management.SelectLayerByLocation(WDOECM_polys, "INTERSECT", scapes)
arcpy.management.CopyFeatures(polys_PS, 'polys_in_scapes2')
print ("polys copied")

# Dissolve all polys layer
arcpy.management.Dissolve('polys_in_scapes2', 'polys_all_dis2', multi_part=True)
print("all polys dissolved")

#Select points that intersect with pilot landscapes, save in scratch db
points_PS= arcpy.management.SelectLayerByLocation(WDOECM_points, "INTERSECT", scapes)
points_PS_inc= arcpy.management.SelectLayerByAttribute(points_PS, "REMOVE_FROM_SELECTION", "REP_AREA=0") #SQL expression

matchcount = int(arcpy.management.GetCount(points_PS_inc)[0]) 
print(f"pts selected: {matchcount}")

if matchcount == 0: #no points, polys_all_dis2 is only oecm layer
    #Erase WDPA flat layer from OECMs to avoid overlap and double counting PAs and OECMS.
    arcpy.analysis.Erase('polys_all_dis2', polys_all_dis, 'oecm_erase') #oecm_erase is the oecm flat layer
    print("poly erased to generate OECM polys")

    #Summarize polys_iuc within pilot scapes to calculate area in hectares for OECMs
    arcpy.analysis.SummarizeWithin(scapes, 'oecm_erase', 'PS_OECM_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
    print("summarize within pilot scapes done")

else: #points exist, oecm_union is the oecm layer
    arcpy.management.CopyFeatures(points_PS, 'points_in_scapes2')
    print ("points copied")

    #Create a geodesic buffer by calculating the radius of a circle with the 'rep_area' value= reported area of the site. TODO Account for marine points ('rep_m_area')
    #calculate buffer distance field
    arcpy.management.CalculateField('points_in_scapes2', 'buff_dist', "(math.sqrt(!REP_AREA!/math.pi))*1000", 'PYTHON', '', 'FLOAT') 
    arcpy.analysis.Buffer('points_in_scapes2', 'pts_buff2', 'buff_dist', method='GEODESIC') #buffer calc is in meters
    print ("buffers drawn for points")

    # Dissolve all points_buffer layer
    arcpy.management.Dissolve('pts_buff2', 'pts_all_dis2', multi_part=True)
    print("all points_buffer dissolved")

    #union with polys layer
    arcpy.analysis.Union(['pts_all_dis2', 'polys_all_dis2'], 'oecm_union')
    print("union done")

    #Erase WDPA flat layer from OECMs to avoid overlap and double counting PAs and OECMS.
    arcpy.analysis.Erase('oecm_union', polys_all_dis, 'oecm_erase') #oecm_erase is the oecm flat layer
    print("poly erased to generate OECM polys")

    #Summarize polys_iuc within pilot scapes to calculate area in hectares for OECMs
    arcpy.analysis.SummarizeWithin(scapes, 'oecm_erase', 'PS_OECM_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
    print("summarize within pilot scapes done")

#Prep summary fc
arcpy.management.AlterField('PS_OECM_sum', 'sum_Area_HECTARES', 'OECM_HA')
#Calculate percentage field
arcpy.management.CalculateField('PS_OECM_sum', 'OECM_pct', "!OECM_HA!/!Area_HA!*100", 'PYTHON', '', 'FLOAT')
print("Field renamed and New pct field calculated")

# Join fields in summary fc to copy of scapes dataset
arcpy.management.JoinField(scapes, 'ID', 'PS_OECM_sum', 'ID', fields=['OECM_HA', 'OECM_pct']) 
print("Joined WDPA summary table to Scapes.shp")



