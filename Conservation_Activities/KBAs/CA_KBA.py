#Prepare KBA data for inclusion in data platform
#Desired output: pilot landscapes shapefile with 22 additional fields. 11 for area and 11 for percent. 
# 2 fields: Total KBA (area and percent of scape covered by KBAs)
# 4 fields: Total KBAs Protected (area and percent of KBAs protected) and KBAs Not Protected (area and percent of KBAs not protected)
# 16 fields: 1 area and 1 percent for each of 8 IUCN categories are: Ia, Ib, II, III, IV, V, VI, + Other. (percent of KBAs that are in each IUCN category.)

#set workspace
scratch_ws= r"C:\Users\mills\OneDrive - World Wildlife Fund, Inc\Documents\Pro Projects\Data_Platform\Scratch.gdb"
analysis_ws=r"C:\Users\mills\OneDrive - World Wildlife Fund, Inc\Documents\Pro Projects\Data_Platform\Analysis"

#data inputs. must be on VPN connect to Sasquatch drive. fild gdb's downloaded from Protected Planet
KBA_folder=r"L:\data_platform\_Data\Pilots_data\KBA_Aug2024\KBAsGlobal_2024_Aug_02_POL\KBAsGlobal_2024_Aug_02_POL" 
KBA_polys= f'{KBA_folder}\KBAsGlobal_2024_Aug_02_POL.shp'
KBA_points= f'{KBA_folder}\KBAsGlobal_2024_Aug_02_PNT.shp'

scapes= r"C:\Users\mills\OneDrive - World Wildlife Fund, Inc\Documents\Pro Projects\Data_Platform\Analysis\Pilot_scapes_EE.shp"

import arcpy
import pandas as pd
arcpy.env.workspace= scratch_ws


#select layer by location select KBA polys that overlap with scapes
#dissolve to make a flat layer
#select layer by location select KBA points that overlap with scapes
#buffer points by sitarea field
#intersect points and polygon KBA layers with dissolved all IUCN polys flat layer
# dissolve on IUCN_CAT #wont work after union. try merge with field map?

##ALTERNATE do not use points for now (don't know what the area field units are anyways)

#Select KBA polygons that intersect with pilot landscapes, save in scratch db
polys_PS= arcpy.management.SelectLayerByLocation(KBA_polys, "INTERSECT", scapes)

arcpy.management.CopyFeatures(polys_PS, 'KBA_polys')
print ("polys copied")

# Dissolve all polys layer
arcpy.management.Dissolve('KBA_polys', 'KBA_polys_dis', multi_part=True)
print("all polys dissolved")

#summarize within scapes 
arcpy.analysis.SummarizeWithin(scapes, 'KBA_polys_dis', 'PS_KBA_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES')
print("summarize KBAs within pilot scapes done")

#Join total PA field in PS_IUCN_sum to copy of scapes dataset
arcpy.management.AlterField('PS_KBA_sum', 'sum_Area_HECTARES', 'KBA_HA')
arcpy.management.JoinField(scapes, 'ScapeID', 'PS_KBA_sum', 'JOIN_ID', fields=['KBA_HA'])
arcpy.management.CalculateField(scapes, 'KBA_pct', "!KBA_HA!/!Area_HA!*100", 'PYTHON', '', 'FLOAT')


#merge IUCN polys with other polys to get flat dissolved layer with all categories.
arcpy.management.Merge(['polys_IUCN_dis', 'polys_other_erase'], 'IUCN_merge')
print("iucn polys merged.")

#replace Null with 'Other'
with arcpy.da.UpdateCursor('IUCN_merge', ["IUCN_CAT"]) as cursor:
    for row in cursor:
        if row[0] == None:
            row[0] = 'Other'
            cursor.updateRow(row)

print ("null updated to other.")

#intersect polygon KBA flat layer with all IUCN flat layer with all categories ("IUCN_merge")
arcpy.analysis.Intersect(['KBA_polys_dis', 'IUCN_merge'], 'KBA_IUCN_int')
print("kbas and iucn intersected.")
#dissolve on IUCN_CAT
arcpy.management.Dissolve('KBA_IUCN_int', 'KBA_IUCN_dis', 'IUCN_CAT', multi_part=True)
print("kba+iucn int dissolved")

#summarize within scapes 
arcpy.analysis.SummarizeWithin(scapes, 'KBA_IUCN_dis', 'PS_KBA_IUCN_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES', group_field='IUCN_CAT', add_group_percent=True, out_group_table='KBA_sum')
print("summarize KBAS with IUCN info within pilot scapes done")




### Table manipulations for WDPA summaries.
#reformat KBA_sum table 
kba_sum='KBA_sum'
columns = [f.name for f in arcpy.ListFields(kba_sum)] #get all columns
kba = pd.DataFrame(data=arcpy.da.SearchCursor(kba_sum, columns), columns=columns)

col_order=['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI', 'O']

area_pivot=kba.pivot(index='Join_ID', columns= 'IUCN_CAT', values='sum_Area_HECTARES')
area_pivot=area_pivot.reindex(columns=col_order)
area_pivot=area_pivot.add_suffix('_HA', axis=1)
area_pivot=area_pivot.add_prefix('KBA_', axis=1)


pct_pivot=kba.pivot(index='Join_ID', columns= 'IUCN_CAT', values='PercentArea')
pct_pivot=pct_pivot.reindex(columns=col_order)
pct_pivot=pct_pivot.add_suffix('_pct', axis=1)
pct_pivot=pct_pivot.add_prefix('KBA_', axis=1)

newdf = pd.concat([area_pivot, pct_pivot], axis=1)

#fill NaN with 0s
newdf= newdf.fillna(0)
print(newdf)
print(newdf.shape)

newdf.to_csv(f"{analysis_ws}\KBA_sum.csv")
join_table=f"{analysis_ws}\KBA_sum.csv"

# Join fields in summary table to copy of scapes dataset
arcpy.management.JoinField(scapes, 'ScapeID', join_table, 'JOIN_ID')
print("Joined KBA summary table to Scapes.shp")

#Join total PA field in PS_IUCN_sum to copy of scapes dataset
arcpy.management.AlterField('PS_KBA_IUCN_sum', 'sum_Area_HECTARES', 'KBA_PA_HA')
arcpy.management.JoinField(scapes, 'ScapeID', 'PS_KBA_IUCN_sum', 'JOIN_ID', fields=['KBA_PA_HA'])

arcpy.management.CalculateField(scapes, 'KBA_PA_pct', "!KBA_PA_HA!/!KBA_HA!*100", 'PYTHON', '', 'FLOAT')
arcpy.management.CalculateField(scapes, 'KBA_NP_HA', "!KBA_HA!-!KBA_PA_HA!", 'PYTHON', '', 'FLOAT')
arcpy.management.CalculateField(scapes, 'KBA_NP_pct', "!KBA_NP_HA!/!KBA_HA!*100", 'PYTHON', '', 'FLOAT')
print("Total protected and non-protected KBAS areas and percents per scape calculated.")

