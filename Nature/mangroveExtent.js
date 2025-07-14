// Includes: sea (FeatureCollection) - all 68 pilot seascapes.
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add mangrove extent, v4.0.19. Source: https://gee-community-catalog.org/projects/mangrove/#earth-engine-snippet-tiles
function addMangroves(f){
  var img = ee.ImageCollection("projects/sat-io/open-datasets/GMW/annual-extent/GMW_MNG_2020").median().selfMask();
  
  var m = ee.Image.pixelArea().updateMask(img).divide(1e6); // to sq.km
  var ext = m.reduceRegion({
    "reducer": ee.Reducer.sum(),
    "geometry": f.geometry(),
    "scale": 300,  // Actual is 10m, but some of our seascapes are too large.  
    "bestEffort": true,
    "maxPixels": 1e10
  });
  
  return ee.Feature(null, ext).copyProperties(f);
}

// Compute and export to Google Drive.
var results = scapes.sea.map(addMangroves);
Export.table.toDrive(results, "seascapesWithMangroveExport");
