// Includes: land (FeatureCollection) - all 243 pilot landscapes.
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");
var lands = scapes.land;

// Global Human Modification v3 -- 7 images, 1 band ("constant") 
var hm = ee.ImageCollection("projects/sat-io/open-datasets/GHM/HM_1990_2020_OVERALL_300M");

// Add Global Human Modification - 1990, 95, 2000, 05, 10, 15, 20. 
// Source: https://gee-community-catalog.org/projects/ghm/?h=human+m
function getHMbyYear(y){
  var img = hm.filter(ee.Filter.eq('year', y)).first();
  var label = ee.String("hm").cat(ee.Number(y).format("%d"));
  
  var annualStats = lands.map(function(f){
    var averageHM = img.reduceRegion({
      'reducer': ee.Reducer.mean(),
      'geometry': f.geometry(),
      'scale': 300,
      'maxPixels': 1e10
    }).get('constant');
  
    return ee.Feature(null, f.toDictionary()).set(label, averageHM);
  });
  
  // A pretty enormous list of feature collections. Like, 1750 total elements.
  return annualStats; 
}

// Years to compute.
// Importantly, won't need to do all of this for a single year. Could be much simpler.
var years = ee.List.sequence(1990, 2020, 5);

// Clean up the results that come back. 
var isList = years.map(getHMbyYear);
var hasDuplicates = ee.FeatureCollection(isList).flatten();

// Use ee.Join.saveAll() to match the lands feature collection to hasDuplicates.
// Set a filter condition for the join. 
var haveSameID = ee.Filter.equals({
  'leftField': 'ID',
  'rightField': 'ID'
});

// Define the join. 
var saveAllJoin = ee.Join.saveAll('matches');

// Apply the join. 
var areas = saveAllJoin.apply(lands, hasDuplicates, haveSameID);

// Clean up the joined collection.
var results = areas.map(function(f){
  
  // Get global human modification from each year.
  var hm90 = ee.Feature(ee.List(f.get('matches')).get(0)).get('hm1990');
  var hm95 = ee.Feature(ee.List(f.get('matches')).get(1)).get('hm1995');
  var hm00 = ee.Feature(ee.List(f.get('matches')).get(2)).get('hm2000');
  var hm05 = ee.Feature(ee.List(f.get('matches')).get(3)).get('hm2005');
  var hm10 = ee.Feature(ee.List(f.get('matches')).get(4)).get('hm2010');
  var hm15 = ee.Feature(ee.List(f.get('matches')).get(5)).get('hm2015');
  var hm20 = ee.Feature(ee.List(f.get('matches')).get(6)).get('hm2020');
  
  // Make a dictionary of the properties that we want. 
  var estimates = ee.Dictionary.fromLists(
    ['hm90','hm95','hm00','hm05','hm10','hm15','hm20'],
    [hm90, hm95, hm00, hm05, hm10, hm15, hm20]);
  
  var props = f.toDictionary().combine(estimates).remove(['matches']);
  
  // Don't really need the .geo anymore, so we can drop.
  return ee.Feature(null, props);
});

// Export to Google Drive.
Export.table.toDrive(results, "landscapesWithHMExport");

