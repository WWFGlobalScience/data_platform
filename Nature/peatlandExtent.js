// Landscapes. 
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add peatland extent. See email from Mabel for source.
function addPeatland(f){
  var img = ee.Image("projects/sat-io/open-datasets/GLOBAL-PEATLAND-DATABASE").selfMask();
  
  var p = ee.Image.pixelArea().updateMask(img).divide(1e6); // to sq.km
  var ext = p.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 1000,  // Actual.
    "bestEffort": true,
    "maxPixels": 1e10
  });
  
  return ee.Feature(null, ext);
}

// Compute and export to Drive.
var results = scapes.land.map(addPeatland);
Export.table.toDrive(results, "seascapesWithPeatlandExport");
