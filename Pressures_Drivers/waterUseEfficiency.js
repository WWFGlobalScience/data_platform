// Countries. Use "iso3_code".
var countries = ee.FeatureCollection("projects/sat-io/open-datasets/FAO/GAUL/GAUL_2024_L0");

// Water use efficiency. 168 features. Use "iso3".
var wue = ee.FeatureCollection("projects/wwf-global-science-sandbox/assets/DataPlatform-pilots/waterUseEfficiency");

// Use an equals filter to define how our two collections match.
var filter = ee.Filter.equals({
  leftField: "iso3_code",
  rightField: "iso3"
});

// Create the join.
var join = ee.Join.inner();

// Apply the join.
var collection = join.apply(countries, wue, filter);

// Clean up joined collection. 
var results = collection.map(function(f){
  var geo = ee.Feature(f.get("primary")).geometry();
  var props = ee.Feature(f.get("secondary")).toDictionary();
  return ee.Feature(geo, props);
});

Export.table.toDrive(results, "withWaterUseEfficiency");
