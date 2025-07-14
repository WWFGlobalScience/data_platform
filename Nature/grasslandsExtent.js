// Includes: land (FeatureCollection) - all 243 pilot landscapes.
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add grassland extent. Source: https://developers.google.com/earth-engine/datasets/catalog/projects_global-pasture-watch_assets_ggc-30m_v1_grassland_c
// 2022 "natural/seminatural grasslands."
function addGrass(f){
  var collection = ee.ImageCollection("projects/global-pasture-watch/assets/ggc-30m/v1/grassland_c");
  var img = ee.Image(collection.filterDate('2022-01-01', '2023-01-01').first()).eq(2).selfMask();
  
  var g = ee.Image.pixelArea().updateMask(img).divide(1e6); // to sq.km
  var ext = g.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 300,  // Actual is 30m but our several of our landscapes are too large.
    "bestEffort": true,
    "maxPixels": 1e10
  }).get("area");
  
  return f.set("grasses", ext);
}

// Compute and export to Google Drive. 
var results = scapes.land.map(addGrass);
Export.table.toDrive(results, "landscapesWithGrassesExport");
