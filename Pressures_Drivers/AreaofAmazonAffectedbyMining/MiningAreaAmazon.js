// =============================================================
// SECTION 1: HEADER
// =============================================================
// Indicator:    Annual change in the spatial extent of the Amazon forest
//               affected by mining  [indicator code TBD]
// Description:  Constrained to the Amazon Priority Place boundary, produces in
//               one run: (1) a cumulative-area + year-on-year-change table
//               (CSV) for the Excel template, (2) a recency raster coloured
//               by year first detected (2018 yellow -> 2025 Q4 red), and
//               (3) a column chart matching the map's colour gradient.
// Author:       Giselle Hall
// Date:         2026-06-18
// Last updated: 2026-06-18
// Dependencies: Google Earth Engine Code Editor (JavaScript API). No external
//               libraries. Inputs are GEE cloud assets (see Section 2).
// Environment:  Run in the Google Earth Engine Code Editor (code.earthengine.google.com).
//
// CAVEATS (read before running):
//   - VERIFY the AMW asset IDs and the Priority Place field/value (Section 4
//     prints the Name values and the matched count).
//   - Area is summed by RASTER within the boundary at `zonalScale` (default
//     100 m) to avoid vector-intersection timeouts. AMW areas are INDICATIVE,
//     not precise; for finer figures lower zonalScale and rely on the CSV task.
//   - MODEL BREAK 2023 -> 2024: part of that step is a detection-method
//     artifact, not real new mining — not directly comparable across it.
//
// HOW TO RUN: paste into the GEE Code Editor, set Section 2 inputs, click Run,
//   then start the two export tasks (CSV + GeoTIFF) in the Tasks tab. Paste the
//   CSV's cumulative_ha values into the Excel template to fill its table/chart.
// =============================================================


// =============================================================
// SECTION 2: USER INPUTS
// =============================================================
// Description: Asset IDs, output destination, and parameters to set before
//              running. No values are hardcoded below this section.
// Inputs:      none (definitions only)
// Outputs:     input variables used throughout the script
// Notes:       The asset IDs are shared cloud assets in the project; verify
//              they exist in your Assets tab. `palette` is shared by the map
//              and the chart so the two read identically.
// =============================================================

// --- Assets (verify against your Assets tab) ---
var boundaryAsset = 'projects/conservationnavigator/assets/USPriorityPlaceBoundaries';
var amwBase       = 'projects/conservationnavigator/assets/';

// AMW cumulative layers, oldest -> newest
var layers = [
  {year: 2018, label: '2018',   id: amwBase + 'AMW_2018-2018cumulative'},
  {year: 2019, label: '2019',   id: amwBase + 'AMW_2018-2019cumulative'},
  {year: 2020, label: '2020',   id: amwBase + 'AMW_2018-2020cumulative'},
  {year: 2021, label: '2021',   id: amwBase + 'AMW_2018-2021cumulative'},
  {year: 2022, label: '2022',   id: amwBase + 'AMW_2018-2022cumulative'},
  {year: 2023, label: '2023',   id: amwBase + 'AMW_2018-2023cumulative'},
  {year: 2024, label: '2024',   id: amwBase + 'AMW_2018-2024cumulative-clean'},
  {year: 2025, label: '2025Q4', id: amwBase + 'AMW_2018-2025Q4cumulative-clean'}
];

// --- Output destination ---
var exportFolder = 'GEE_Exports';   // Google Drive folder for CSV + GeoTIFF

// --- Parameters ---
var zonalScale = 100;   // m; raise if it times out, lower (to 30) for precision

// Shared 8-colour gradient (older yellow -> newer red): map AND column chart.
var palette = ['#FFEDA0','#FED976','#FEB24C','#FD8D3C',
               '#FC4E2A','#E31A1C','#BD0026','#800026'];


// =============================================================
// SECTION 3: LOAD LIBRARIES AND SOURCE FILES
// =============================================================
// Description: Load the source assets. (GEE has no external libraries to load.)
// Inputs:      boundaryAsset, layers
// Outputs:     ppAll (all Priority Places), amwCollections (AMW layers)
// Notes:       Loading is lazy in GEE; nothing is computed until used/exported.
// =============================================================

var ppAll          = ee.FeatureCollection(boundaryAsset);
var amwCollections = layers.map(function(L) { return ee.FeatureCollection(L.id); });


// =============================================================
// SECTION 4: LOAD AND INSPECT SOURCE DATA (SELECT STUDY AREA)
// =============================================================
// Description: Inspect the Priority Place names and isolate the Amazon polygon.
// Inputs:      ppAll
// Outputs:     amazonPP, amazonGeom
// Notes:       VERIFY the field/value: the same boundary file in the GVI R
//              script used a "Name" field. Confirm "Amazon features matched"
//              reads >= 1 before trusting the outputs.
// =============================================================

print('Priority Places — values in the "Name" field:', ppAll.aggregate_array('Name'));

var amazonPP   = ppAll.filter(ee.Filter.stringContains('Name', 'Amazon'));  // VERIFY
var amazonGeom = amazonPP.geometry();

print('Amazon features matched (should be >= 1):', amazonPP.size());


// =============================================================
// SECTION 5: DATA CLEANING AND PREPARATION
// =============================================================
// Description: Rasterize each cumulative AMW layer to a binary mining mask
//              (1 = mining) for use by both the recency and area products.
// Inputs:      amwCollections
// Outputs:     r (array of binary images, oldest -> newest)
// Notes:       Raster handling avoids the vector-intersection timeouts hit
//              previously with this dataset.
// =============================================================

function rasterize(fc) { return ee.Image(0).byte().paint(fc, 1); }
var r = amwCollections.map(function(fc) { return rasterize(fc); });


// =============================================================
// SECTION 6: ANALYSIS / INDICATOR CALCULATION
// =============================================================
// Description: Build (a) the recency raster (year first detected, clipped to
//              Amazon) and (b) the cumulative-area + year-on-year-change table
//              summed within the Amazon boundary.
// Inputs:      r, layers, amazonGeom, zonalScale
// Outputs:     firstYearPP (recency image), table (cumulative + change)
// Notes:       "Annual change" = cumulative[i] - cumulative[i-1]. The 2018 row
//              is the baseline footprint; its change is set to the baseline so
//              the change column sums to the final cumulative (set to 0 if you
//              prefer). Net/area figures are approximate (see header caveats).
// =============================================================

// --- 6a. Recency raster: stamp each pixel with its year of first detection ---
var firstYear = ee.Image(0);
for (var i = 0; i < layers.length; i++) {
  var newPix = (i === 0) ? r[0] : r[i].subtract(r[i - 1]);   // 1 where newly added
  firstYear = firstYear.where(newPix, layers[i].year);
}
firstYear = firstYear.selfMask();
var firstYearPP = firstYear.clip(amazonGeom);

// --- 6b. Cumulative mining area (ha) WITHIN Amazon, per year ---
function areaInAmazon(binImg) {
  var miningArea = binImg.multiply(ee.Image.pixelArea());     // m^2 where mining
  var s = miningArea.reduceRegion({
    reducer:   ee.Reducer.sum(),
    geometry:  amazonGeom,
    scale:     zonalScale,
    maxPixels: 1e13,
    tileScale: 4
  });
  return ee.Number(s.values().get(0)).divide(1e4);            // m^2 -> ha
}

var cumAreas = r.map(function(img) { return ee.Number(areaInAmazon(img)); });

// --- 6c. Cumulative + year-on-year change table ---
var rows = layers.map(function(L, i) {
  var cum = cumAreas[i];
  var change, pct;
  if (i === 0) {
    change = cum;                 // baseline; set to ee.Number(0) if preferred
    pct    = ee.Number(0);
  } else {
    change = cum.subtract(cumAreas[i - 1]);
    pct    = change.divide(cumAreas[i - 1]).multiply(100);
  }
  return ee.Feature(null, {
    year:             L.label,
    cumulative_ha:    cum,
    annual_change_ha: change,
    pct_change:       pct
  });
});

var table = ee.FeatureCollection(rows);


// =============================================================
// SECTION 7: QUALITY CHECKS
// =============================================================
// Description: Print the table and the data-quality reminders for review.
// Inputs:      table
// Outputs:     console messages
// Notes:       Cross-check the 2023->2024 step (model break) and confirm the
//              Amazon match count (Section 4) before reporting any figure.
// =============================================================

print('Cumulative area within Amazon PP + year-on-year change (ha):', table);
print('Reminder: the 2023->2024 change is partly a model-shift artifact.');


// =============================================================
// SECTION 8: EXPORT OUTPUTS
// =============================================================
// Description: Export the recency raster (GeoTIFF) and the cumulative/change
//              table (CSV) to Google Drive.
// Inputs:      firstYearPP, table, amazonGeom, exportFolder
// Outputs:     two Drive export tasks (start them in the Tasks tab)
// Notes:       Paste the CSV's cumulative_ha values into the Excel template to
//              populate its table and gradient column chart.
// =============================================================

Export.image.toDrive({
  image:       firstYearPP.toInt16(),
  description: 'AMW_recency_year_first_detected_AmazonPP',
  folder:      exportFolder,
  region:      amazonGeom,
  scale:       30,
  maxPixels:   1e13,
  fileFormat:  'GeoTIFF'
});

Export.table.toDrive({
  collection:  table,
  description: 'AMW_cumulative_annual_change_AmazonPP',
  folder:      exportFolder,
  fileFormat:  'CSV',
  selectors:   ['year', 'cumulative_ha', 'annual_change_ha', 'pct_change']
});


// =============================================================
// SECTION 9: VISUALISATION
// =============================================================
// Description: Draw the recency map (clipped) with the boundary outline and a
//              year legend, and print the gradient column chart whose columns
//              match the map's colour ramp.
// Inputs:      firstYearPP, amazonPP, palette, table
// Outputs:     map layers, legend, column chart (Console)
// Notes:       The column chart uses evaluate() so each column can carry its
//              own gradient colour; it renders a moment after the rest and
//              appears lower in the Console.
// =============================================================

// --- 9a. Recency map + boundary + legend ---
Map.centerObject(amazonPP, 5);
Map.addLayer(firstYearPP, {min: 2018, max: 2025, palette: palette},
             'Mining — year first detected (within Amazon PP)');
Map.addLayer(ee.Image().byte().paint(amazonPP, 0, 2),
             {palette: ['FFFFFF']}, 'Amazon Priority Place boundary');

var legend = ui.Panel({style: {position: 'bottom-left', padding: '8px'}});
legend.add(ui.Label('Year first detected', {fontWeight: 'bold'}));
var yrs = [2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025];
for (var j = 0; j < yrs.length; j++) {
  legend.add(ui.Panel({
    widgets: [
      ui.Label('', {backgroundColor: palette[j], padding: '8px', margin: '2px'}),
      ui.Label(yrs[j] === 2025 ? '2025 Q4' : String(yrs[j]), {margin: '2px'})
    ],
    layout: ui.Panel.Layout.Flow('horizontal')
  }));
}
Map.add(legend);

// --- 9b. Gradient column chart (columns match the map's yellow -> red ramp) ---
table.evaluate(function(fc) {
  var dataTable = [['Year', 'Cumulative area (ha)', {role: 'style'}]];
  fc.features.forEach(function(f, i) {
    dataTable.push([
      f.properties.year,
      f.properties.cumulative_ha,
      'color: ' + palette[i]            // older = yellow ... newer = red
    ]);
  });

  var chart = ui.Chart(dataTable, 'ColumnChart', {
    title:  'Amazon forest area affected by mining (within PP) — cumulative (ha)',
    hAxis:  {title: 'Year', slantedText: true},
    vAxis:  {title: 'Cumulative area (ha)'},
    legend: {position: 'none'}
  });
  print(chart);
});