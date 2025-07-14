// Landscapes. 
var scapes = require("users/ryancovingtonwwf/sandbox:DataPlatform/Pilot2_All-land-and-seascapes/land-and-seascapes.js");

// Add water stress in major basins. Source: https://zenodo.org/records/7797979
function addStress(f){
  var sbtn = ee.FeatureCollection('users/ryancovingtonwwf/forSummerPilots/sbnt_son_water');
  var hydrosheds = sbtn.filterBounds(f.geometry());
  
  var stress = hydrosheds.reduceColumns(ee.Reducer.max(), ["wsb_n"]).get("max");
  var depletion = hydrosheds.reduceColumns(ee.Reducer.max(), ["wdp_n"]).get("max");
  var scarcity = hydrosheds.reduceColumns(ee.Reducer.max(), ["bws_n"]).get("max");
  
  return ee.Feature(null).set("stress", stress, "depletion", depletion, "scarcity", scarcity);
}

// Compute and export to Drive.
var results = scapes.land.map(addStress);
Export.table.toDrive(results, "landscapesWithWaterStressExport");
