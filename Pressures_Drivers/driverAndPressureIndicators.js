
// This script is meant to be executed in the Earth Engine code editor. I'll work on a Python version soon.


// Landscapes: Pantanal, TriDom, Diana seascape, Upper Amazon.
var landscapes = ee.FeatureCollection('users/ryancovingtonwwf/pilot_landscapes');

// We also have some data sets that are only available at the country level. 
var namesFilter = ee.List(['Brazil', 'Bolivia', 'Cameroon', 'Colombia', 'Rep of the Congo', 'Gabon', 'Madagascar', 'Paraguay' ]);
var countries = ee.FeatureCollection("USDOS/LSIB_SIMPLE/2017")
  .filter(ee.Filter.inList('country_na', namesFilter));
  

// ----------------------------------------------------------------------------------------------
//
// Let's start with country-level datasets. These are CSVs that need to be joined to a geometry. 
//
// ----------------------------------------------------------------------------------------------

// Annual production of forestry resources. 
var forests = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/annualForestProduction');

// Food loss and waste. 
var food = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/annualFoodLossAndWaste');

// National water use efficiency. 
var useEff = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/changeInWaterUseEfficiency'); 

// Mismanaged plastic. 
var plastic = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/estimatedVolumeOfMismanagedPlasticWaste');

// Number of known introduced or invasive species. 
var iis = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/knownNumberOfInvasiveOrIntroducedSpecies');

// Define the relationship between the collections. 
var namesInCommon = ee.Filter.stringContains({
  leftField: 'country_na',  // From the countries collection. 
  rightField: 'country'  // In all of the CSVs.
});

// Join CSVs to the countries feature collection.
function joinCSVs(fc, r){
  // @param {ee.FeatureCollection} - The countries of the pilot landscapes to process. 
  // @param {ee.Filter} r - The relationship between the two collections we're joining. 
  // @return {ee.FeatureCollection} The countries that make up the pilot landscapes with CSV properties attached.
  
  function cleanUpJoin(jc){
    // @param {ee.FeatureCollection} jc - A joined feature collection.
    // @return {ee.FeatureCollection} The joined collection with the properties cleaned up. 

    return jc.map(function(f){
      var match = ee.List(f.get('matches'));  // Returns a list. 
      var addedProps = match.get(0);  // Returns a feature.   
      return ee.Feature(f.geometry())
        .copyProperties({
          'source': f,
          'exclude': ['matches']
        })
        .copyProperties({
          'source': addedProps, 
          'exclude': ['matches']
        });
    });
  }
  
  // Surely, there is a more elegant way to do this. 
  var plasticAdded = cleanUpJoin(ee.Join.saveAll('matches').apply(fc, plastic, r));
  var forestsAdded = cleanUpJoin(ee.Join.saveAll('matches').apply(plasticAdded, forests, r));
  var foodAdded = cleanUpJoin(ee.Join.saveAll('matches').apply(forestsAdded, food, r));
  var useEffAdded = cleanUpJoin(ee.Join.saveAll('matches').apply(foodAdded, useEff, r));
  var iisAdded = cleanUpJoin(ee.Join.saveAll('matches').apply(useEffAdded, iis, r));

  return iisAdded;  
}

// Indicators summarized by country.
// (i.e., vector datasets that are only available at the national scale)
var countryData = joinCSVs(countries, namesInCommon);

// Add to map. 
Map.addLayer(countryData, {}, 'Country-level indicators');
print(countryData);


// ---------------------------------------------------------------------------------------
//
// Next, let's tackle vector datasets. They need to be summarized to our pilot landscapes.  
//
// ---------------------------------------------------------------------------------------

// Global Dam Watch. 
// Source: https://www.globaldamwatch.org/database
var dams = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/GDW_barriers_v1_0');

// Water stress in major basins. 
// Source: https://zenodo.org/records/7797979
var stress = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/sbnt_son_water');

// Number of dams per pilot landscape. 
var damsInAmazon = dams.filterBounds(landscapes.filter(ee.Filter.eq('Scape', 'Colombian Amazon'))).size();
var damsInPantanal = dams.filterBounds(landscapes.filter(ee.Filter.eq('Scape', 'Pantanal'))).size();
var damsInTriDom = dams.filterBounds(landscapes.filter(ee.Filter.eq('Scape', 'TRIDOM'))).size();
var damsInDiana = dams.filterBounds(landscapes.filter(ee.Filter.eq('Scape', 'Madagascar Diana'))).size();

// I suspect that Sam actually wants these by hydrosheds per landscape, so... 
function addDamsAndWaterStressPerHydroshed(fc){
  // @param {ee.FeatureCollection} fc - WWF pilot landscapes to process.
  // @return {ee.FeatureCollection} A collection of hydrosheds with # of dams attached as a property.
  
  return fc.map(function(f){
    return stress.filterBounds(f.geometry()).map(function(h){
      // @param {ee.FeatureCollection} h - A hydroshed within the current landscape.
      
      return ee.Feature(h.geometry()), h.select(['bws_label', 'wdp_label', 'wsb_label'], ['baselineWaterStress', 'waterDepletion', 'blueWaterScarcity'])
        .set({'dams': dams.filterBounds(h.geometry()).size()});
    });
  }).flatten(); 
}

// Indicators summarized by hydroshed.
// (i.e., vector datasets that are available at subnational scales & are specific to watersheds)
var basinData = addDamsAndWaterStressPerHydroshed(landscapes);

// Add to map. 
Map.addLayer(basinData, {'color':'blue'}, 'Basin-level indicators');

// ----------------------------------------------------------------------------------------------
//
// Lastly, let's tackle the raster datasets. Also need to be summarized to our pilot landscapes.
//
// ----------------------------------------------------------------------------------------------

// Global Human Modification. 
// Source: https://gee-community-catalog.org/projects/ghm/?h=human+m
var humanModificationFrom2017 = ee.Image("projects/sat-io/open-datasets/GHM/ghm_v15_2017_300_60land");

function addMeanGlobalHumanModification(fc){
  // @param {ee.FeatureCollection} fc - WWF pilot landscapes to process.
  // @return {ee.FeatureCollection} The landscapes with GHM attached as a property. 
  
  return fc.map(function(f){
    var stats = humanModificationFrom2017.reduceRegion({
      'reducer': ee.Reducer.mean(),
      'geometry': f.geometry(),
      'scale': 300,  // From the paper.
      'maxPixels': 1e9
    });
    return f.set({'mean_HM': stats.get('constant')});
  });
}

// Add to map. (Actually, a super-dope palette.)
// var visParams_GHM = {min:0, max:1, palette:['0c0c0c','071aff','ff0000','ffbd03','fbff05','fffdfd']};
// Map.addLayer(humanModificationFrom2017, visParams_GHM, 'Global Human Modification, 2017');


// Cumulative Human Impact (CHI). 
// Source: https://www.nature.com/articles/s41598-019-47201-9 
var cumulativeHumanImpact = ee.Image('users/ryancovingtonwwf/forSummerPilots/cumulative_impact_2010');

function addMeanCumulativeHumanImpact(fc){
  // @param {ee.FeatureCollection} fc - WWF pilot seascapes to process.
  // @return {ee.FeatureCollection} The seascapes with the CHI attached as a property.
  
  return fc.map(function(f){
    var stats = cumulativeHumanImpact.reduceRegion({
      'reducer': ee.Reducer.mean(),
      'geometry': f.geometry(),
      'scale': 1000,  // From the paper. 
      'maxPixels': 1e9
    });
    return f.set({'mean_CHI': stats.get('b1')});
  });
}

// Add to map.
// var visParams_CHI = {min: 0, max: 2, palette: ['0D3B66','FAF0CA','F4D35E','EE964B','F95738']};
// Map.addLayer(cumulativeHumanImpact, visParams_CHI, 'Cumulative Human Impact, 2019');

// Indicators summarized by landscape.
// (i.e., raster datasets that can be clipped to our areas of interest)
var scapes = addMeanGlobalHumanModification(landscapes);
var landscapeData = addMeanCumulativeHumanImpact(scapes);

// Add to map. 
Map.addLayer(landscapeData, {'color':'green'}, 'Landscape-level indicators');


// ----------------------------------------------------------------------------------------------
//
//                                 ** Exports. **  
//                          But only if you're serious.
//
// ----------------------------------------------------------------------------------------------

// Export.table.toDrive({
//   'collection': countryData,
//   'folder': 'Data sets for September pilots',
//   'fileNamePrefix': 'countryData',
//   'fileFormat': 'SHP'
// });

// Export.table.toDrive({
//   'collection': basinData,
//   'folder': 'Data sets for September pilots',
//   'fileNamePrefix': 'basinData',
//   'fileFormat': 'SHP'
// });

// Export.table.toDrive({
//   'collection': landscapeData,
//   'folder': 'Data sets for September pilots',
//   'fileNamePrefix': 'landscapeData',
//   'fileFormat': 'SHP'
// });