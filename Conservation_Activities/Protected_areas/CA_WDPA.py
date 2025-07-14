#Prepare WDPA data for inclusion in data platform
#Desired output: pilot landscapes shapefile with 20 additional fields. 10 for area and 10 for percent. 
# 4 fields: Total Protected Area (area and percent of scape protected) and Not Protected Area (area and percent of scape not protected)
# 16 fields: 1 area and 1 percent for each of 8 IUCN categories are: Ia, Ib, II, III, IV, V, VI, + Other. (percent of scape in each category)

#set workspace
scratch_ws= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb"
analysis_ws= r"L:\data_platform\Analysis\Prod_outputs\Cons_activities"

#data inputs. must be on VPN connect to Sasquatch drive. file gdb's downloaded from Protected Planet
WDPA_gdb=r"L:\data_platform\_Data\prod_data\WDPA_May2025_Public\WDPA_May2025_Public.gdb"
WDPA_polys= f'{WDPA_gdb}\WDPA_poly_May2025'
WDPA_points= f'{WDPA_gdb}\WDPA_point_May2025'

scapes= r"L:\data_platform\Analysis\Prod_outputs\scratch.gdb\Prod_scapes" #best to use a feature class in a file gdb, same projection as WDPA layer.

import arcpy
import pandas as pd
arcpy.env.workspace= scratch_ws

#Select polygons that intersect with pilot landscapes, save in scratch db
polys_PS= arcpy.management.SelectLayerByLocation(WDPA_polys, "INTERSECT", scapes)
arcpy.management.CopyFeatures(polys_PS, 'polys_in_scapes')
print ("polys copied")

#Select points that intersect with pilot landscapes, save in scratch db
points_PS= arcpy.management.SelectLayerByLocation(WDPA_points, "INTERSECT", scapes)
points_PS_inc= arcpy.management.SelectLayerByAttribute(points_PS, "REMOVE_FROM_SELECTION", "REP_AREA=0") #SQL expression
arcpy.management.CopyFeatures(points_PS, 'points_in_scapes')
print ("points copied")

#Create a geodesic buffer by calculating the radius of a circle with the 'rep_area' value= reported area of the site. TODO Account for marine points ('rep_m_area')
#calculate buffer distance field
arcpy.management.CalculateField('points_in_scapes', 'buff_dist', "(math.sqrt(!REP_AREA!/math.pi))*1000", 'PYTHON', '', 'FLOAT') 
arcpy.analysis.Buffer('points_in_scapes', 'pts_buff', 'buff_dist', method='GEODESIC') #buffer calc is in meters
print ("buffers drawn for points")



# Dissolve all polys layer
arcpy.management.Dissolve('polys_in_scapes', 'polys_all_dis', multi_part=True) #polys_all_dis is the WDPA all polygon flat layer
print("all polys dissolved")

# From polys intersecting with pilot scapes, select where IUCN_CAT!= “Not Reported”, “Not Applicable”, or "Not Assigned"
polys_PS_IUCN= arcpy.management.SelectLayerByAttribute('polys_in_scapes', "NEW_SELECTION", "IUCN_CAT <> 'Not Applicable' And IUCN_CAT <> 'Not Reported' And IUCN_CAT <> 'Not Assigned'") #SQL expression
arcpy.management.CopyFeatures(polys_PS_IUCN, 'polys_IUCN')
print("iucn polys selected")
# (there are still some overlapping features in IUCN categories, although the total area is very small.

#  TODO-figure out how to handle overlap-do we assign to whatever IUCN category is higher? in order to not double count?
# Or make a note in summary graphics that IUCN categories are not necessarily mutually exclusive-maybe we don't use a pie chart. this one.

# Dissolve on IUCN_CAT. to get only IUCN categories.
arcpy.management.Dissolve('polys_IUCN', 'polys_IUCN_dis', 'IUCN_CAT', multi_part=True) #polys_IUCN_dis is the IUCN polys only flat layer
print("iucn polys dissolved")

#Get other non IUCN WDPAs
polys_PS_other= arcpy.management.SelectLayerByAttribute('polys_in_scapes', "NEW_SELECTION", "IUCN_CAT <> 'Not Applicable' And IUCN_CAT <> 'Not Reported' And IUCN_CAT <> 'Not Assigned'", 'INVERT') #SQL expression
arcpy.management.CopyFeatures(polys_PS_other, 'polys_IUCN_other')
print("iucn other polys selected")

#Erase IUCN layer to get ‘Other’ layer with no overlap
arcpy.analysis.Erase('polys_IUCN_other', 'polys_IUCN_dis', 'polys_other_erase') 
print("poly erased to generate other polys")

#Dissolve to get other IUCN categories.
arcpy.management.Dissolve('polys_other_erase', 'polys_other_dis', multi_part=True) #polys_other_dis is the IUCN-Other polys only flat layer
print("other polys dissolved")



#do the same process for the pts buffers.
# Dissolve all points_buffer layer
arcpy.management.Dissolve('pts_buff', 'pts_all_dis', multi_part=True)
print("all points_buffer dissolved")

# From points_buffer, select where IUCN_CAT!= “Not Reported”, “Not Applicable”, or "Not Assigned"
pts_PS_IUCN= arcpy.management.SelectLayerByAttribute('pts_buff', "NEW_SELECTION", "IUCN_CAT <> 'Not Applicable' And IUCN_CAT <> 'Not Reported' And IUCN_CAT <> 'Not Assigned'") #SQL expression

matchcount = int(arcpy.management.GetCount(pts_PS_IUCN)[0]) 
print(f"pts selected: {matchcount}")

if matchcount == 0: #TODO revisit based on updated else workflow. not tested at scale.
    print("no features matched attribute criteria; only 'other' points exist. the 'pts_all_dis' layer is the 'other' layer.")
    #union only other layer to combine with polys
    arcpy.analysis.Union(['pts_all_dis', 'polys_other_dis'], 'other_union')
    print("union done")

    # #summarize polys_iucn_dis and other_union within pilot scapes to calculate area in hectares for each category
    arcpy.analysis.SummarizeWithin(scapes, 'polys_iucn_dis', 'PS_IUCN_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES', group_field='IUCN_CAT', add_group_percent=True, out_group_table='IUCN_sum')
    arcpy.analysis.SummarizeWithin(scapes, 'other_union', 'PS_oth_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES', group_field='FID_pts_all_dis', add_group_percent=True, out_group_table='other_sum')
    print("summarize within pilot scapes done")
    #for some reason the second summarize within generates error 100014 when both are run together.

else: #TODO this part has not been tested.
    # If features matched criteria, write them to a new feature class
    arcpy.management.CopyFeatures(pts_PS_IUCN, 'pts_buff_IUCN')
    print("features matched attribute criteria; iucn points buffer copied to new feature class.")

    #dissolve on IUCN_CAT to get only IUCN categories
    arcpy.management.Dissolve('pts_buff_IUCN', 'pts_buff_IUCN_dis', 'IUCN_CAT', multi_part=True)
    print("iucn points buffer dissolved")
    
    #Erase IUCN layer to get ‘Other’ layer with no overlap
    arcpy.analysis.Erase('pts_all_dis', 'pts_buff_IUCN_dis', 'pts_other_erase')
    print("pts buff erased to generate other points buff") 
    
    #old arcpy.analysis.Union(['pts_other_erase', 'polys_other_dis'], 'other_union') #union might not work bc need to preserve attributes. test out merge instead, watch out for overlap in output. merge then dissolve
    # merge and dissolve other layers points and polys
    arcpy.management.Merge(['pts_other_erase', 'polys_other_dis'], 'other_merge')
    arcpy.analysis.PairwiseDissolve('other_merge', 'other_merge_dis')
    print("other points and polygons merged")
    
    #old arcpy.analysis.Union(['pts_buff_IUCN_dis', 'polys_IUCN_dis'], 'iucn_union')
    # merge and dissolve each IUCN cat points and polys separately other layers points and polys
    iucn_cats=['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI']
    merged_by_cat=[]
    for cat in iucn_cats:
        #TODO handle if pts and/or polys layer does not include a category.
        #select pts layer by cat
        pt_sel= arcpy.management.SelectLayerByAttribute('pts_buff_IUCN_dis', "NEW_SELECTION", f"IUCN_CAT == '{cat}'") #SQL expression

        #select poly layer by cat
        poly_sel= arcpy.management.SelectLayerByAttribute('polys_IUCN_dis', "NEW_SELECTION", f"IUCN_CAT == '{cat}'") #SQL expression

        #merge pts and polys only selected
        arcpy.management.Merge(['pt_sel', 'poly_sel'], f'IUCN_{cat}_merge')

        #dissolve on IUCN field
        arcpy.analysis.PairwiseDissolve(f'IUCN_{cat}_merge', f'IUCN_{cat}_merge_dis', 'IUCN_CAT', multi_part=True)

        merged_by_cat.append(f'IUCN_{cat}_merge_dis')
        print("iucn points and polygons merged by category")

    # #merge all cats
    arcpy.management.Merge(merged_by_cat, 'IUCN_merge')
    arcpy.analysis.PairwiseDissolve('IUCN_merge', 'IUCN_merge_dis', multi_part=True) #this is the flat layer of all IUCN protected points/polygons together.

    #summarize iucn_union and other_union within pilot scapes to calculate area in hectares for each category
    arcpy.analysis.SummarizeWithin(scapes, 'IUCN_merge_dis', 'PS_IUCN_dis_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES') #need to run this step on all IUCN flat layer to account for overlapping IUCN categories.
    arcpy.analysis.SummarizeWithin(scapes, 'IUCN_merge', 'PS_IUCN_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES', group_field='IUCN_CAT', add_group_percent=True, out_group_table='IUCN_sum')
    arcpy.analysis.SummarizeWithin(scapes, 'other_merge_dis', 'PS_oth_sum', keep_all_polygons=True, sum_shape=True, shape_unit='HECTARES') 
    print("summarize within pilot scapes done")


## Table manipulations for WDPA summaries.
#reformat IUCN_sum table 
iucn_sum='IUCN_sum'
columns = [f.name for f in arcpy.ListFields(iucn_sum)] #get all columns
iucn = pd.DataFrame(data=arcpy.da.SearchCursor(iucn_sum, columns), columns=columns)

col_order=['Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI']

area_pivot=iucn.pivot(index='Join_ID', columns= 'IUCN_CAT', values='sum_Area_HECTARES')
area_pivot=area_pivot.reindex(columns=col_order)
area_pivot=area_pivot.add_suffix('_HA', axis=1)
print(area_pivot)

pct_pivot=iucn.pivot(index='Join_ID', columns= 'IUCN_CAT', values='PercentArea')
pct_pivot=pct_pivot.reindex(columns=col_order)
pct_pivot=pct_pivot.add_suffix('_pct', axis=1)
print(pct_pivot)

#insert 'other columns'
other_sum= 'PS_oth_sum'
columns = ['OBJECTID','sum_Area_HECTARES', 'Area_HA'] #
other = pd.DataFrame(data=arcpy.da.SearchCursor(other_sum, columns), columns=columns)
other=other.rename(columns={"sum_Area_HECTARES": "Other_HA"})

#calculate other percent column
other['Other_pct']= other['Other_HA']/other['Area_HA']*100
print(other)

#combine tables
other=other.set_index('OBJECTID')
newdf = pd.concat([area_pivot, pct_pivot, other], axis=1)

#reorder columns
col_order=['JoinID', 'Ia_HA', 'Ib_HA', 'II_HA', 'III_HA', 'IV_HA', 'V_HA', 'VI_HA', 'Other_HA', 'Ia_pct',
       'Ib_pct', 'II_pct', 'III_pct', 'IV_pct', 'V_pct', 'VI_pct', 'Other_pct']
newdf['JoinID']= newdf.index
newdf=newdf.reindex(columns=col_order)

#fill NaN with 0s
newdf= newdf.fillna(0)
print(newdf)
print(newdf.shape)

newdf.to_csv(f"{analysis_ws}\WDPA_sum.csv")
join_table=f"{analysis_ws}\WDPA_sum.csv"

# Join fields in summary tables (PS_oth_sum + IUCN_sum) to copy of scapes dataset  #TODO can't join to OBJECTID field, need to make a copy field and calculate in scapes file.
arcpy.management.JoinField(scapes, 'JoinID', join_table, 'JoinID', fields=['Ia_HA', 'Ib_HA', 'II_HA', 'III_HA', 'IV_HA', 'V_HA', 'VI_HA', 
    'Other_HA', 'Ia_pct', 'Ib_pct', 'II_pct', 'III_pct', 'IV_pct', 'V_pct', 'VI_pct', 'Other_pct']) 
print("Joined WDPA summary table to Scapes.shp")

#Join total PA field in PS_IUCN_sum to copy of scapes dataset 
arcpy.management.AlterField('PS_IUCN_dis_sum', 'sum_Area_HECTARES', 'PA_HA')
arcpy.management.CalculateField('PS_IUCN_dis_sum', 'PA_pct', "!PA_HA!/!Area_HA!*100", 'PYTHON', '', 'FLOAT')
arcpy.management.CalculateField('PS_IUCN_dis_sum', 'NP_HA', "!Area_HA!-!PA_HA!", 'PYTHON', '', 'FLOAT')
arcpy.management.CalculateField('PS_IUCN_dis_sum', 'NP_pct', "!NP_HA!/!Area_HA!*100", 'PYTHON', '', 'FLOAT')
arcpy.management.JoinField(scapes, 'ID', 'PS_IUCN_dis_sum', 'ID', fields=['PA_HA', 'PA_pct', 'NP_HA', 'NP_pct'])

print("Total protected and non-protected areas and percents per scape calculated.")