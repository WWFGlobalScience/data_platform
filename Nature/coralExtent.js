// Includes: sea (FeatureCollection) - all 68 pilot seascapes.
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add coral reef extent. Source: https://developers.google.com/earth-engine/datasets/catalog/ACA_reef_habitat_v2_0#bands
function addCoral(f){
  var benthic = ee.Image("ACA/reef_habitat/v2_0").select(['benthic']);
  var coral = benthic.updateMask(benthic.eq(15));
  
  var c = ee.Image.pixelArea().updateMask(coral).divide(1e6); // to sq.km
  var ext = c.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 100,  // Actual is 5m2, but the computation crashes. 
    "bestEffort": true,
    "maxPixels": 1e10
  });
  
  return ee.Feature(null, ext).copyProperties(f);
}

// Compute and export results to Google Drive. 
var results = scapes.sea.map(addCoral);
Export.table.toDrive(results, "seascapesWithCoralExport");
