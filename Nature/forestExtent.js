// Includes: land (FeatureCollection) - all 243 pilot landscapes.
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add forest extent 2000, 2020. Source: https://glad.umd.edu/dataset/GLCLUC2020
// Pixels with ≥ 5 m forest height were deemed “forest.” 
function addForest(f){
  var y00 = ee.Image("projects/glad/GLCLU2020/Forest_height_2000").gte(5);
  var y20 = ee.Image("projects/glad/GLCLU2020/Forest_height_2020").gte(5);
  
  var a00 = ee.Image.pixelArea().updateMask(y00).divide(1e6);
  var fe00 = a00.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 300,  // Actual is 30m but our landscapes are a bit too large.  
    "bestEffort": true,
    "maxPixels": 1e10
  }).get("area");
  
  var a20 = ee.Image.pixelArea().updateMask(y20).divide(1e6);
  var fe20 = a20.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 300,
    "bestEffort": true,
    "maxPixels": 1e10
  }).get("area");
  
  return ee.Feature(null).set("fe00", fe00, "fe20", fe20);
}

// Compute and export to Google Drive.
var results = scapes.land.map(addForest);
Export.table.toDrive(results, "landscapesWithForestExport");
