// Includes: sea (FeatureCollection) - all 68 pilot seascapes.
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add Cumulative Human Impact (CHI). Source: https://www.nature.com/articles/s41598-019-47201-9 
function addCHI(f){
  var img = ee.Image('users/ryancovingtonwwf/forSummerPilots/cumulative_impact_2010');
  var props = f.toDictionary();
  var chi = img.reduceRegion({
    "reducer": ee.Reducer.mean(),
    "geometry": f.geometry(),
    "scale": 1000,  // From the paper. 
    "maxPixels": 1e10
  }).get("b1");
  
  return ee.Feature(null, props).set("chi", chi);
}

// Compute and export results to Google Drive.
var results = scapes.sea.map(addCHI);
Export.table.toDrive(results, "seascapesWithChiExport");
