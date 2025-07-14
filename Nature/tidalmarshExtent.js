// Seascapes. 
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add tidal marshes. Pixels are 10m x 10m. 
function addMarsh(f){
  var img = ee.Image("users/tomworthington81/SM_Global_2020/global_export_v2_6/saltmarsh_v2_6");
  
  var m = ee.Image.pixelArea().updateMask(img).divide(1e6);
  var ext = m.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 300,  // Actual is 10m, but some of our seascapes are too large.
    "bestEffort": true,
    "maxPixels": 1e10
  });
  
  return ee.Feature(null, ext).copyProperties(f);
}

// Compute and export to Drive. 
var results = scapes.sea.map(addMarsh);
Export.table.toDrive(results, "seascapesWithSaltMarshExport");
