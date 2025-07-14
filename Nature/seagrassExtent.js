// Seascapes. 
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add coral reef extent. Source: https://developers.google.com/earth-engine/datasets/catalog/ACA_reef_habitat_v2_0#bands
function addSeagrass(f){
  var seagrass = ee.Image("ACA/reef_habitat/v2_0").select(['benthic']).eq(14).selfMask();
  
  var s = ee.Image.pixelArea().updateMask(seagrass).divide(1e6); // to sq.km
  var ext = s.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 100,  // Actual is 5m2, but the computation crashes. 
    "bestEffort": true,
    "maxPixels": 1e10
  });
  
  return ee.Feature(null, ext).copyProperties(f);
}

// Fingers crossed. 
var results = scapes.sea.map(addSeagrass);
Export.table.toDrive(results, "seascapesWithSeagrassExport");
