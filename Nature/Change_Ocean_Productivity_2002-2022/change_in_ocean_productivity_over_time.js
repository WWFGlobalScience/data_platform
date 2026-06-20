// =============================================================
// SECTION 1: HEADER
// =============================================================
// Indicator:    Change in ocean productivity over time (chlorophyll-a)
//               — proxy for fish stock movement  [indicator code TBD]
// Description:  From MODIS-Aqua L3SMI, produces in one run: (A) four regional
//               chlorophyll-anomaly CSVs (Arctic, SW Indian, E. Pacific,
//               W. Pacific) that feed the R analysis, and (B) early (2002-2007)
//               / late (2016-2022) / difference layers with an interactive map,
//               region boxes and legend, plus GeoTIFF exports for the
//               Pacific-Indian tiles, the Arctic, and a global difference.
// Author:       Giselle Hall
// Date:         2026-05-11
// Last updated: 2026-06-18 — reformatted to DMAP v3 Section 4.4 structure
// Dependencies: Google Earth Engine Code Editor (JavaScript API). No external
//               libraries. Source is the public MODIS-Aqua L3SMI collection.
// Environment:  Run in the Google Earth Engine Code Editor (code.earthengine.google.com).
//
// NOTES:
//   - The outputs from this feed the R section of analysis.
//     The R stage reads the four Part A CSVs (region, date, mean) and the
//     global difference raster exported in Part B (chl_early_vs_late).
//   - The global pixel-wise TREND/SLOPE raster (chl_trend_slope_global.tif)
//     used by the R trend map comes from a SEPARATE linearFit script and is
//     NOT produced here.
//   - Antimeridian handling/issue resolution: the Pacific-Indian exports 
//     and the East-Pacific display boxes are split into tiles/boxes with 
//     min < max on purpose.
// =============================================================


// =============================================================
// SECTION 2: USER INPUTS
// =============================================================
// Description: Dataset, date windows, region geometries, export destination,
//              and processing scales to set before running.
// Inputs:      none (definitions only)
// Outputs:     parameters used throughout
// Notes:       Edit region geometries to change scope. Scales: 25 km for the
//              regional anomaly means (fast, sufficient), 10 km for the GeoTIFFs.
// =============================================================

// --- Dataset + date windows ---
var collectionId = 'NASA/OCEANDATA/MODIS-Aqua/L3SMI';
var fullStart  = '2002-07-01';  var fullEnd  = '2022-02-28';   // full record
var earlyStart = '2002-07-01';  var earlyEnd = '2007-12-31';   // early period
var lateStart  = '2016-01-01';  var lateEnd  = '2022-02-28';   // late period

// --- Output destination + processing parameters ---
var exportFolder  = 'GEE_Exports';
var anomalyScale  = 25000;   // m, regional anomaly means
var geotiffScale  = 10000;   // m, exported rasters
var tileScaleParam = 4;      // memory management for large regions
var crs           = 'EPSG:4326';

// --- Region geometries (analysis scope) ---
var Arctic       = ee.Geometry.Rectangle([-180, 60, 180, 89.9], crs, false);
var SW_Indian    = ee.Geometry.Rectangle([30, -50, 90, -10],    crs, false);
var East_Pacific = ee.Geometry.Rectangle([-150, -60, -70, 60],  crs, false);
var West_Pacific = ee.Geometry.Rectangle([120, -60, 180, 60],   crs, false);

// --- Export tiles (split to avoid antimeridian crossing) ---
var tile1        = ee.Geometry.Rectangle([30, -60, 180, 60],  crs, false); // Indian + W Pacific
var tile2        = ee.Geometry.Rectangle([180, -60, 300, 60], crs, false); // E Pacific
var arcticTile   = Arctic;                                                  // [-180,60,180,89.9]
var globalRegion = ee.Geometry.Rectangle([-180, -90, 180, 90], crs, false);


// =============================================================
// SECTION 3: LOAD LIBRARIES AND SOURCE FILES
// =============================================================
// Description: Load the source collection. (GEE has no external libraries.)
// Inputs:      collectionId, fullStart, fullEnd
// Outputs:     modisCol (raw chlor_a collection)
// Notes:       Loading is lazy; nothing computes until used/exported.
// =============================================================

var modisCol = ee.ImageCollection(collectionId)
  .select('chlor_a')
  .filterDate(fullStart, fullEnd);


// =============================================================
// SECTION 4: LOAD AND INSPECT SOURCE DATA
// =============================================================
// Description: Log-transform the chlorophyll values and inspect coverage.
// Inputs:      modisCol
// Outputs:     logCol (log10 chlorophyll collection)
// Notes:       log10 is standard for chlorophyll-a (log-normal distribution).
// =============================================================

var logCol = modisCol.map(function(img) {
  return img.log10()
    .rename('log_chl')
    .copyProperties(img, ['system:time_start', 'system:time_end']);
});

print('Images in collection:', modisCol.size());


// =============================================================
// SECTION 5: DATA CLEANING AND PREPARATION
// =============================================================
// Description: Build the monthly climatology and anomalies, and the region
//              feature collection used for the regional means.
// Inputs:      logCol, region geometries
// Outputs:     climatology, anomalyCol, regionFC
// Notes:       Anomaly = log_chl minus the same-month climatological mean.
// =============================================================

var months = ee.List.sequence(1, 12);

var climatology = ee.ImageCollection.fromImages(
  months.map(function(m) {
    return logCol
      .filter(ee.Filter.calendarRange(m, m, 'month'))
      .mean()
      .set('month', m);
  })
);

var anomalyCol = logCol.map(function(img) {
  var month = ee.Date(img.get('system:time_start')).get('month');
  var clim  = climatology.filter(ee.Filter.eq('month', month)).first();
  return img.subtract(clim)
    .rename('chl_anomaly')
    .copyProperties(img, ['system:time_start']);
});

var regionFC = ee.FeatureCollection([
  ee.Feature(Arctic,       {region: 'Arctic'}),
  ee.Feature(SW_Indian,    {region: 'SW_Indian'}),
  ee.Feature(East_Pacific, {region: 'East_Pacific'}),
  ee.Feature(West_Pacific, {region: 'West_Pacific'})
]);


// =============================================================
// SECTION 6: ANALYSIS / INDICATOR CALCULATION
// =============================================================
// Description: (A) regional anomaly time series via reduceRegions, and
//              (B) early/late period means and their difference.
// Inputs:      anomalyCol, regionFC, logCol
// Outputs:     timeSeries (per region per date), earlyMean, lateMean, difference
// Notes:       reduceRegions runs all four regions per image in one pass at
//              anomalyScale with tileScale for memory.
// =============================================================

// --- A. Regional anomaly time series ---
var summariseImage = function(img) {
  var date = ee.Date(img.get('system:time_start')).format('YYYY-MM-dd');
  var reduced = img.reduceRegions({
    collection: regionFC,
    reducer:    ee.Reducer.mean(),
    scale:      anomalyScale,
    tileScale:  tileScaleParam
  });
  return reduced.map(function(f) { return f.set('date', date); });
};

var timeSeries = anomalyCol.map(summariseImage).flatten();

// --- B. Early / late period means and difference ---
var earlyMean  = logCol.filterDate(earlyStart, earlyEnd).mean().rename('log_chl');
var lateMean   = logCol.filterDate(lateStart, lateEnd).mean().rename('log_chl');
var difference = lateMean.subtract(earlyMean).rename('difference');


// =============================================================
// SECTION 7: QUALITY CHECKS
// =============================================================
// Description: Console reminders of the export tasks and screenshot option.
// Inputs:      none
// Outputs:     console messages
// Notes:       Productivity caveat: "more productive" is not automatically
//              good — interpret by region (upwelling vs eutrophication).
// =============================================================

print('Tasks tab: 4 CSV + 6 Pacific-Indian + 3 Arctic + 1 global difference = 14 tasks.');
print('Toggle map layers (top right). Screenshot with Windows + Shift + S.');


// =============================================================
// SECTION 8: EXPORT OUTPUTS
// =============================================================
// Description: Export the four anomaly CSVs and the period GeoTIFFs
//              (Pacific-Indian tiles, Arctic, and global difference).
// Inputs:      timeSeries, earlyMean, lateMean, difference, tiles, exportFolder
// Outputs:     14 Drive export tasks (start them in the Tasks tab)
// Notes:       CSVs feed the R script; the global difference exports as
//              chl_early_vs_late (read by the R early-vs-late map).
// =============================================================

// --- Anomaly CSVs (inputs to R) ---
Export.table.toDrive({collection: timeSeries.filter(ee.Filter.eq('region', 'Arctic')),       description: 'CHL_Anomaly_Arctic',       folder: exportFolder, fileNamePrefix: 'chl_anomaly_arctic',       fileFormat: 'CSV', selectors: ['region', 'date', 'mean']});
Export.table.toDrive({collection: timeSeries.filter(ee.Filter.eq('region', 'SW_Indian')),    description: 'CHL_Anomaly_SW_Indian',    folder: exportFolder, fileNamePrefix: 'chl_anomaly_sw_indian',    fileFormat: 'CSV', selectors: ['region', 'date', 'mean']});
Export.table.toDrive({collection: timeSeries.filter(ee.Filter.eq('region', 'East_Pacific')), description: 'CHL_Anomaly_East_Pacific', folder: exportFolder, fileNamePrefix: 'chl_anomaly_east_pacific', fileFormat: 'CSV', selectors: ['region', 'date', 'mean']});
Export.table.toDrive({collection: timeSeries.filter(ee.Filter.eq('region', 'West_Pacific')), description: 'CHL_Anomaly_West_Pacific', folder: exportFolder, fileNamePrefix: 'chl_anomaly_west_pacific', fileFormat: 'CSV', selectors: ['region', 'date', 'mean']});

// --- Pacific-Indian GeoTIFFs (two tiles each) ---
Export.image.toDrive({image: earlyMean.clip(tile1),  description: 'PacificIndian_Early_Tile1', folder: exportFolder, fileNamePrefix: 'pacific_indian_early_tile1', region: tile1, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: earlyMean.clip(tile2),  description: 'PacificIndian_Early_Tile2', folder: exportFolder, fileNamePrefix: 'pacific_indian_early_tile2', region: tile2, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: lateMean.clip(tile1),   description: 'PacificIndian_Late_Tile1',  folder: exportFolder, fileNamePrefix: 'pacific_indian_late_tile1',  region: tile1, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: lateMean.clip(tile2),   description: 'PacificIndian_Late_Tile2',  folder: exportFolder, fileNamePrefix: 'pacific_indian_late_tile2',  region: tile2, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: difference.clip(tile1), description: 'PacificIndian_Diff_Tile1',  folder: exportFolder, fileNamePrefix: 'pacific_indian_diff_tile1',  region: tile1, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: difference.clip(tile2), description: 'PacificIndian_Diff_Tile2',  folder: exportFolder, fileNamePrefix: 'pacific_indian_diff_tile2',  region: tile2, scale: geotiffScale, crs: crs, maxPixels: 1e13});

// --- Arctic GeoTIFFs ---
Export.image.toDrive({image: earlyMean.clip(arcticTile),  description: 'Arctic_Early_2002_2007', folder: exportFolder, fileNamePrefix: 'arctic_chl_early_2002_2007', region: arcticTile, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: lateMean.clip(arcticTile),   description: 'Arctic_Late_2016_2022',  folder: exportFolder, fileNamePrefix: 'arctic_chl_late_2016_2022',  region: arcticTile, scale: geotiffScale, crs: crs, maxPixels: 1e13});
Export.image.toDrive({image: difference.clip(arcticTile), description: 'Arctic_Difference',      folder: exportFolder, fileNamePrefix: 'arctic_chl_difference',      region: arcticTile, scale: geotiffScale, crs: crs, maxPixels: 1e13});

// --- Global difference (read by the R early-vs-late map) ---
Export.image.toDrive({image: difference, description: 'CHL_Early_vs_Late_Global', folder: exportFolder, fileNamePrefix: 'chl_early_vs_late', region: globalRegion, scale: geotiffScale, crs: crs, maxPixels: 1e13});


// =============================================================
// SECTION 9: VISUALISATION
// =============================================================
// Description: Interactive map of the difference / period means, region boxes
//              (incl. Arctic), and a directional-change legend.
// Inputs:      difference, lateMean, earlyMean, region geometries
// Outputs:     map layers, region boxes, legend
// Notes:       chlVis is the absolute-concentration ramp; diffVis is the
//              red->white->blue directional-change ramp used by the legend.
// =============================================================

// --- Palettes ---
var chlVis = {
  min: -1.5, max: 1.0,
  palette: ['#3d0060','#6a0dad','#0000ff','#0080ff',
            '#00ffff','#00cc00','#ffff00','#ff6600','#ff0000']
};
var diffVis = {
  min: -0.4, max: 0.4,
  palette: ['#d73027','#f46d43','#fdae61','#ffffff',
            '#abd9e9','#74add1','#4575b4']
};

// --- Map + period layers ---
Map.setCenter(160, 0, 3);
Map.setOptions('SATELLITE');
Map.addLayer(difference, diffVis, 'Difference: Late minus Early', true);
Map.addLayer(lateMean,   chlVis,  'Late period CHL 2016-2022',   false);
Map.addLayer(earlyMean,  chlVis,  'Early period CHL 2002-2007',  false);

// --- Region boundary boxes (box_ prefix avoids clashes with the geometries) ---
var box_SW_Indian      = ee.FeatureCollection([ee.Feature(SW_Indian)]);
var box_West_Pacific   = ee.FeatureCollection([ee.Feature(West_Pacific)]);
var box_East_Pacific_W = ee.FeatureCollection([ee.Feature(ee.Geometry.Rectangle([180, -60, 210, 60], crs, false))]);
var box_East_Pacific_E = ee.FeatureCollection([ee.Feature(ee.Geometry.Rectangle([210, -60, 290, 60], crs, false))]);
var box_Arctic         = ee.FeatureCollection([ee.Feature(Arctic)]);

var boxStyle = {color: 'FFFF00', fillColor: '00000000', width: 2};
Map.addLayer(box_SW_Indian.style(boxStyle),      {}, 'SW Indian Ocean boundary');
Map.addLayer(box_West_Pacific.style(boxStyle),   {}, 'West Pacific boundary');
Map.addLayer(box_East_Pacific_W.style(boxStyle), {}, 'East Pacific boundary West');
Map.addLayer(box_East_Pacific_E.style(boxStyle), {}, 'East Pacific boundary East');
Map.addLayer(box_Arctic.style(boxStyle),         {}, 'Arctic boundary');

// --- Legend (directional change in chlorophyll-a) ---
var legend = ui.Panel({style: {position: 'bottom-left', padding: '8px 15px', backgroundColor: 'white'}});

legend.add(ui.Label({value: 'Change in Ocean Productivity',
  style: {fontWeight: 'bold', fontSize: '14px', margin: '0 0 6px 0', padding: '0'}}));
legend.add(ui.Label({value: 'Late (2016-2022) minus Early (2002-2007)\nlog\u2081\u2080(CHL) mg m\u207b\u00b3',
  style: {fontSize: '11px', color: '#555555', margin: '0 0 8px 0'}}));

var palette = ['#d73027','#f46d43','#fdae61','#ffffff','#abd9e9','#74add1','#4575b4'];
var colorBar = ui.Thumbnail({
  image: ee.Image.pixelLonLat().select('latitude').multiply(0)
    .add(ee.Image.pixelLonLat().select('longitude'))
    .visualize({min: 0, max: 100, palette: palette}),
  params: {bbox: [0, 0, 100, 10], dimensions: '200x20'},
  style:  {stretch: 'horizontal', margin: '0 0 4px 0'}
});
legend.add(colorBar);

legend.add(ui.Panel({
  widgets: [
    ui.Label('-0.4\n(Less productive)', {fontSize: '11px', color: '#d73027', margin: '0'}),
    ui.Label('0\n(No change)', {fontSize: '11px', textAlign: 'center', color: '#555555', margin: '0', stretch: 'horizontal'}),
    ui.Label('+0.4\n(More productive)', {fontSize: '11px', textAlign: 'right', color: '#4575b4', margin: '0'})
  ],
  layout: ui.Panel.Layout.flow('horizontal'),
  style:  {stretch: 'horizontal', margin: '0 0 8px 0'}
}));

legend.add(ui.Label({value: 'Blue  =  more productive in recent years', style: {fontSize: '11px', color: '#4575b4', margin: '2px 0'}}));
legend.add(ui.Label({value: 'Red   =  less productive in recent years', style: {fontSize: '11px', color: '#d73027', margin: '2px 0'}}));
legend.add(ui.Label({value: 'White =  little or no change',            style: {fontSize: '11px', color: '#555555', margin: '2px 0'}}));
legend.add(ui.Label({value: 'Source: MODIS-Aqua L3SMI, NASA OB.DAAC\nAnalysis via Google Earth Engine',
  style: {fontSize: '10px', color: '#888888', margin: '8px 0 0 0'}}));

Map.add(legend);