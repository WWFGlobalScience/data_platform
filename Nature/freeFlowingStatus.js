var freeFlowingRivers = ee.FeatureCollection("WWF/HydroSHEDS/v1/FreeFlowingRivers");
var landscapes = ee.FeatureCollection("projects/wwf-global-science-sandbox/assets/DataPlatform-pilots/usableLandscapes");
var hydrosheds = ee.FeatureCollection("WWF/HydroATLAS/v1/Basins/level06");

// Okay, looking for "CSI" - the Connectivity Status Index. 
function computeMeanCsi(f){
  var geo = f.geometry();
  var basins = hydrosheds.filterBounds(geo);
  
  // Get every basin that intersects with a feature.
  // Returns a collection of collections.
  return basins.map(function(b){
    var rivers = freeFlowingRivers.filterBounds(b.geometry());
    var csi = rivers.reduceColumns(ee.Reducer.mean(), ['CSI']).get('mean');
    
    return b.select(["HYBAS_ID"]).set({"csi": csi});
  });
}

// ----------
// All seems good. Let's export. 
// ----------
var results = landscapes.map(computeMeanCsi).flatten();
Export.table.toDrive(results, "freeFlowingStatusOfRivers"); 
