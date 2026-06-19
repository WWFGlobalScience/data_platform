// =============================================================
// SECTION 1: HEADER
// =============================================================
// Indicator:    (1) Spatial extent of intact grasslands              [code TBD]
//               (2) Spatial extent of grasslands vulnerable to
//                   conversion                                        [code TBD]
//               (3) Spatial extent of grasslands permanently
//                   converted                                        [code TBD]
// Description:  Derives the spatial extent (area in hectares) and
//               analysis-ready raster layers for three grassland
//               indicators from the CGR Grassland Assessment Map V2.
//               "Total intact" is reported as Core + Vulnerable
//               combined, per Great Plains team validation feedback.
//               Vulnerable and Converted are also produced as
//               standalone layers.
// Author:       Giselle Hall
// Date:         2026-06-18
// Last updated: 2026-06-18 — cleaned to DMAP v3 Section 4.4 structure
// Dependencies: Google Earth Engine JavaScript API (Code Editor).
//               No external libraries or modules required.
// Environment:  Built and run in the GEE Code Editor
//               (code.earthengine.google.com).
// Data source:  CGR Grassland Assessment Map V2 (shared WWF GEE asset).
//               Single-band categorical raster, 30 m, Albers Equal Area.
// Notes:        Driver-level splits (cropland vs woody) are NOT produced
//               here — the V2 product merges both drivers into single
//               class codes (100 = at-risk, 500 = converted). Add on the
//               next GAM update when separable source layers exist.
// =============================================================


// =============================================================
// SECTION 2: USER INPUTS
// =============================================================
// Description: All asset IDs, parameters, and output settings an analyst
//              must review before running. This is the ONLY place these
//              values are set (DMAP 4.4.1 — no hardcoded paths elsewhere).
// Inputs:      none (definitions only)
// Outputs:     variables used throughout the script
// Notes:       Replace ASSET_ID / BOUNDARY_ID with your own as needed.
//              EXPORT_CRS defaults to Web Mercator (EPSG:3857) per DMAP
//              cartographic standard for Conservation Navigator delivery.

var ASSET_ID      = 'projects/ee-wwfgp-projects/assets/CGR_GAM_V2_GP';
var BOUNDARY_ID   = '';            // optional: path to a clip boundary FeatureCollection; '' = no clip
var EXPORT_SCALE  = 90;            // metres: 30 (full), 90 or 150 (coarsened to ease processing)
var CONSOLE_SCALE = 1000;          // coarse scale for instant in-console area review (avoids timeouts)
var EXPORT_CRS    = 'EPSG:3857';   // DMAP delivery standard (Web Mercator). Use 'EPSG:4326' only if required.
var DRIVE_FOLDER  = 'GEE_Exports'; // Google Drive folder for all exports


// =============================================================
// SECTION 3: LOAD LIBRARIES
// =============================================================
// Description: External library / module loading.
// Inputs:      none
// Outputs:     none
// Notes:       The Earth Engine API ('ee') is available natively in the
//              Code Editor; no libraries are loaded. Section retained for
//              DMAP 4.4 structural consistency. Any require() module
//              imports would be placed here.


// =============================================================
// SECTION 4: LOAD & INSPECT
// =============================================================
// Description: Load the source asset and print key properties to confirm
//              it is the expected single-band categorical raster.
// Inputs:      ASSET_ID
// Outputs:     GRM (ee.Image); diagnostic prints in the console
// Notes:       Confirm band count = 1 and review the native projection
//              before trusting downstream results.

var GRM = ee.Image(ASSET_ID);

print('Asset band names (expect one band):', GRM.bandNames());
print('Native projection / CRS:', GRM.projection());
print('Native nominal scale (m):', GRM.projection().nominalScale());


// =============================================================
// SECTION 5: CLEANING
// =============================================================
// Description: Remap the raw class codes to sequential values, optionally
//              clip to a boundary, and isolate the three indicator classes.
// Inputs:      GRM, BOUNDARY_ID
// Outputs:     core, vulnerable, converted, intactTotal (ee.Image masks)
// Notes:       Remap scheme confirmed with the dataset manager:
//                5   -> 1  Core            (Intact)
//                100 -> 3  Vulnerable      (at risk, still intact)
//                500 -> 4  Plowed/Encroached (Converted)
//              Other codes (0,7,1000,2000,5000) are background/masked
//              non-grassland classes and are excluded.

var GRMremapped = GRM.remap(
  [0, 5, 7, 100, 500, 1000, 2000, 5000],
  [0, 1, 2, 3,   4,   5,    6,    7]
).rename('remapped');

// Optional clip (only if a boundary asset was supplied in USER INPUTS).
var REGION;
if (BOUNDARY_ID !== '') {
  var boundary = ee.FeatureCollection(BOUNDARY_ID);
  GRMremapped = GRMremapped.clip(boundary);
  REGION = boundary.geometry();
} else {
  REGION = GRM.geometry();
}

// Isolate indicator classes.
var core       = GRMremapped.eq(1);  // Intact / Core
var vulnerable = GRMremapped.eq(3);  // Vulnerable to conversion
var converted  = GRMremapped.eq(4);  // Plowed / Encroached (converted)

// Total intact = Core OR Vulnerable (team feedback: at-risk is still intact).
var intactTotal = core.or(vulnerable);


// =============================================================
// SECTION 6: ANALYSIS
// =============================================================
// Description: Compute spatial extent (hectares) per indicator and build
//              the combined classified layer used for display.
// Inputs:      core, vulnerable, converted, intactTotal, REGION, scales
// Outputs:     area prints; combinedView (ee.Image)
// Notes:       Areas use ee.Image.pixelArea(), computed on the WGS84
//              ellipsoid, so the EXPORT_CRS choice does NOT bias hectares.
//              Console figures at CONSOLE_SCALE are approximate; precise
//              figures come from the EXPORT_SCALE CSV in Section 8.

// Reusable area helper: returns masked area (ha) as a Feature row.
function classAreaFeature(maskImg, label, scale) {
  var areaHa = ee.Image.pixelArea().divide(10000).updateMask(maskImg);
  var summed = areaHa.reduceRegion({
    reducer: ee.Reducer.sum(),
    geometry: REGION,
    scale: scale,
    maxPixels: 1e13,
    bestEffort: true
  });
  return ee.Feature(null, { indicator: label, area_ha: summed.get('area') });
}

// Quick look in the console (coarse, instant).
print('--- Approximate areas at ' + CONSOLE_SCALE + 'm (quick look) ---');
print('Intact / Core (ha):',          classAreaFeature(core,        'Intact / Core', CONSOLE_SCALE).get('area_ha'));
print('Vulnerable (ha):',             classAreaFeature(vulnerable,  'Vulnerable',    CONSOLE_SCALE).get('area_ha'));
print('Converted (ha):',              classAreaFeature(converted,   'Converted',     CONSOLE_SCALE).get('area_ha'));
print('TOTAL INTACT Core+Vuln (ha):', classAreaFeature(intactTotal, 'Total intact',  CONSOLE_SCALE).get('area_ha'));

// Combined 3-class layer (intact=1, vulnerable=2, converted=3).
var combinedView = core.multiply(1)
  .add(vulnerable.multiply(2))
  .add(converted.multiply(3))
  .selfMask();


// =============================================================
// SECTION 7: QUALITY CHECKS
// =============================================================
// Description: Verify the indicator classes exist and that excluded areas
//              are NoData (not 0), per DMAP zero/no-data QA.
// Inputs:      GRMremapped, masks
// Outputs:     diagnostic prints
// Notes:       DMAP 4.1 — missing data must be NoData/NA, never 0.
//              selfMask() makes non-indicator pixels NoData on export.
//              For categorical reprojection, Earth Engine resamples with
//              nearest-neighbour by default, which preserves class codes —
//              do NOT add .resample('bilinear') to these layers.

// Confirm the three remapped codes are present in the data.
var histogram = GRMremapped.reduceRegion({
  reducer: ee.Reducer.frequencyHistogram(),
  geometry: REGION,
  scale: CONSOLE_SCALE,
  maxPixels: 1e13,
  bestEffort: true
});
print('Remapped value histogram (expect keys incl. 1, 3, 4):', histogram);


// =============================================================
// SECTION 8: EXPORT
// =============================================================
// Description: Export the per-indicator area table (CSV) and the
//              analysis-ready rasters (Cloud-Optimized GeoTIFF).
// Inputs:      masks, combinedView, EXPORT_SCALE, EXPORT_CRS, DRIVE_FOLDER
// Outputs:     1 CSV + 4 COG GeoTIFFs in DRIVE_FOLDER
// Notes:       DMAP requires Cloud-Optimized GeoTIFF for raster delivery
//              and EPSG:3857 for the CN application. The per-indicator
//              standalone layers are the delivery products; the combined
//              layer is an overview/QA product.
//              VERIFY in current GEE docs that
//              `formatOptions:{cloudOptimized:true}` is accepted for your
//              export type before relying on it for delivery.

// 8a. Area table (CSV), one row per indicator, at EXPORT_SCALE.
var areaTable = ee.FeatureCollection([
  classAreaFeature(core,        'Intact_Core',                 EXPORT_SCALE),
  classAreaFeature(vulnerable,  'Vulnerable',                  EXPORT_SCALE),
  classAreaFeature(converted,   'Converted',                   EXPORT_SCALE),
  classAreaFeature(intactTotal, 'Total_Intact_Core_plus_Vuln', EXPORT_SCALE)
]);

Export.table.toDrive({
  collection: areaTable,
  description: 'CGR_Grassland_Area_ha_' + EXPORT_SCALE + 'm',
  folder: DRIVE_FOLDER,
  fileNamePrefix: 'CGR_Grassland_Area_ha_' + EXPORT_SCALE + 'm',
  fileFormat: 'CSV'
});

// 8b. Combined classified raster (overview / QA product).
//     .expression() + .toByte() forces the integer class codes to survive.
var combinedExport = GRMremapped.expression(
  "(b('remapped') == 1) ? 1" +   // Intact
  ": (b('remapped') == 3) ? 2" + // Vulnerable
  ": (b('remapped') == 4) ? 3" + // Converted
  ": 0"
).rename('classification').selfMask().toByte();

Export.image.toDrive({
  image: combinedExport,
  description: 'CGR_Grassland_Combined_' + EXPORT_SCALE + 'm',
  folder: DRIVE_FOLDER,
  fileNamePrefix: 'CGR_Grassland_Combined_' + EXPORT_SCALE + 'm',
  scale: EXPORT_SCALE,
  region: REGION,
  crs: EXPORT_CRS,
  maxPixels: 1e13,
  fileFormat: 'GeoTIFF',
  formatOptions: { cloudOptimized: true }
});

// 8c. Per-indicator standalone rasters (delivery products).
//     Helper keeps the four export calls consistent.
function exportLayer(maskImg, name) {
  Export.image.toDrive({
    image: maskImg.selfMask().toByte(),
    description: name + '_' + EXPORT_SCALE + 'm',
    folder: DRIVE_FOLDER,
    fileNamePrefix: name + '_' + EXPORT_SCALE + 'm',
    scale: EXPORT_SCALE,
    region: REGION,
    crs: EXPORT_CRS,
    maxPixels: 1e13,
    fileFormat: 'GeoTIFF',
    formatOptions: { cloudOptimized: true }
  });
}

exportLayer(core,        'CGR_Intact_Core');
exportLayer(vulnerable,  'CGR_Vulnerable');
exportLayer(converted,   'CGR_Converted');
exportLayer(intactTotal, 'CGR_Total_Intact');


// =============================================================
// SECTION 9: VISUALISATION
// =============================================================
// Description: On-screen display for QA, plus the written visualisation
//              specification handed to the application integrator.
// Inputs:      combinedView, masks
// Outputs:     Map layers (for QA only)
// Notes:       Per DMAP, static thematic map exports are NOT produced from
//              this script; the deliverables are the analysis-ready files
//              (Section 8) plus this written viz spec. Map.addLayer below
//              is for the analyst's visual QA only.
//
//   VISUALISATION SPEC FOR INTEGRATOR (combined classified raster):
//     class 1  Intact / Core         -> #2d8a4e (green)
//     class 2  Vulnerable            -> #f5c518 (yellow)
//     class 3  Converted             -> #8b1a8b (purple)
//     Convention: warm = concern, cool = resilience.
//     NoData = transparent (no value).

var vizCombined = { min: 1, max: 3, palette: ['2d8a4e', 'f5c518', '8b1a8b'] };
Map.addLayer(combinedView,        vizCombined,             'Combined 3-class (QA)');
Map.addLayer(core.selfMask(),       {palette: ['2d8a4e']}, 'Intact / Core (QA)');
Map.addLayer(vulnerable.selfMask(), {palette: ['f5c518']}, 'Vulnerable (QA)');
Map.addLayer(converted.selfMask(),  {palette: ['8b1a8b']}, 'Converted (QA)');
Map.addLayer(intactTotal.selfMask(),{palette: ['1b5e3f']}, 'Total intact Core+Vuln (QA)');

// State-level zoom to stay within GEE display memory limits.
Map.setCenter(-98.5, 37.5, 7);