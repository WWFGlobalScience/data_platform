// Landscapes. 
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add number of dams. Source: https://www.globaldamwatch.org/database
function addDams(f){
  var dams = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/GDW_barriers_v1_0');
  var count = dams.filterBounds(f.geometry()).size();
  return ee.Feature(null).set("count", count);
}

// Compute and export to Drive. 
var results = scapes.land.map(addDams);
Export.table.toDrive(results, "landscapesWithDamsExport");
