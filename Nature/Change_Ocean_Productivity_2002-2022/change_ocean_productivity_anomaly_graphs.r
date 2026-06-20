# =============================================================================
# SECTION 1: HEADER
# =============================================================================
# Indicator:    Change in ocean productivity over time (chlorophyll-a)
#               — proxy for fish stock movement  [indicator code TBD]
# Description:  R-side statistics and figures for the MODIS-Aqua chlorophyll-a
#               productivity indicator. Reads the GEE-exported regional anomaly
#               CSVs and global GeoTIFFs, and produces: a 4-region anomaly
#               time-series with trendlines, a global trend (slope) map, an
#               early-vs-late difference map, and a combined 2-panel figure.
# Author:       Giselle Hall
# Date:         2026-05-11
# Last updated: 2026-06-20 — reformatted to DMAP v3 Section 4.4 structure
# Dependencies: readr, dplyr, ggplot2, scales, lubridate, terra, tidyterra,
#               sf, rnaturalearth, rnaturalearthdata, patchwork, trend
# Environment:  R [version] on Windows / RStudio
#
# NOTES:
#   - The Earth Engine side (climatology, anomaly, pixel-wise trend, early/late
#     difference) is a SEPARATE GEE script;run the GEE scripts first to get
#     the anomaly .csv files to be able to create the line graphs with trend
#     lines.
#     This script is the R stage only.
# =============================================================================


# =============================================================================
# SECTION 2: USER INPUTS
# =============================================================================
# Description: Paths and filenames to set before running. No hardcoded local
#              paths below this section (DMAP 4.4.1).
# Inputs:      none (definitions only)
# Outputs:     path + filename variables used throughout
# Notes:       The GeoTIFFs were often saved to a different folder than the
#              CSVs (e.g. Downloads) — `tif_dir` is separate for that reason.
#              Fix any filename that differs from your saved files.
# =============================================================================

# --- Folders (replace placeholders) ---
project_dir <- "path/to/Ocean Productivity/"   # holds the CSVs; PNGs written here
tif_dir     <- "path/to/geotiffs"              # holds the GeoTIFFs (often Downloads)

# --- Source filenames ---
csv_files <- c("chl_anomaly_arctic.csv",
               "chl_anomaly_east_pacific.csv",
               "chl_anomaly_sw_indian.csv",
               "chl_anomaly_west_pacific.csv")
slope_tif <- "chl_trend_slope_global.tif"      # pixel-wise trend (slope)
diff_tif  <- "chl_early_vs_late.tif"           # late minus early mean log10 CHL


# =============================================================================
# SECTION 3: LOAD LIBRARIES
# =============================================================================
# Description: Install (if missing) and load required packages.
# Inputs:      none
# Outputs:     attached packages
# Notes:       Installs only packages not already present.
# =============================================================================

required <- c("readr","dplyr","ggplot2","scales","lubridate",
              "terra","tidyterra","sf","rnaturalearth","rnaturalearthdata",
              "patchwork","trend")
for (p in required) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

library(readr); library(dplyr); library(ggplot2); library(scales)
library(lubridate); library(terra); library(tidyterra); library(sf)
library(rnaturalearth); library(patchwork); library(trend)


# =============================================================================
# SECTION 4: LOAD AND INSPECT SOURCE DATA
# =============================================================================
# Description: Set the working directory, load and stack the four regional
#              anomaly CSVs, confirm the two GeoTIFFs exist and load them, and
#              load the world land layer.
# Inputs:      project_dir, tif_dir, csv_files, slope_tif, diff_tif
# Outputs:     ts_raw, slope_r, diff_r, world
# Notes:       If a GeoTIFF is not found, the script lists the .tif files it
#              CAN see in tif_dir and stops, so you can correct the name/folder.
# =============================================================================

setwd(project_dir)

# --- Regional anomaly CSVs (region, date, mean) ---
ts_raw <- csv_files |>
  lapply(read_csv, show_col_types = FALSE) |>
  bind_rows()

cat("CSV rows loaded:", nrow(ts_raw), "\n")
print(table(ts_raw$region))

# --- GeoTIFFs: confirm presence, then load ---
slope_path <- file.path(tif_dir, slope_tif)
diff_path  <- file.path(tif_dir, diff_tif)

for (f in c(slope_path, diff_path)) {
  if (!file.exists(f)) {
    message("NOT FOUND: ", f)
    message("TIFFs available in ", tif_dir, ":")
    print(list.files(tif_dir, pattern = "\\.tif$", ignore.case = TRUE))
    stop("Fix tif_dir or the filename in Section 2, then re-run.")
  }
}

slope_r <- rast(slope_path); names(slope_r) <- "slope"
diff_r  <- rast(diff_path);  names(diff_r)  <- "diff"

# --- World land layer for map overlays ---
world <- ne_countries(scale = "medium", returnclass = "sf")


# =============================================================================
# SECTION 5: DATA CLEANING AND PREPARATION
# =============================================================================
# Description: Parse dates and the anomaly column, set the region factor order
#              to match the figure layout, and trim extreme raster outliers.
# Inputs:      ts_raw, slope_r, diff_r
# Outputs:     ts (clean long table), region_labels, masked slope_r / diff_r
# Notes:       The CSV column "mean" is the chlorophyll anomaly. Mask thresholds
#              remove coastal outliers for cleaner display — adjust if needed.
# =============================================================================

ts <- ts_raw |>
  mutate(date        = as.Date(date),
         chl_anomaly = as.numeric(mean)) |>
  filter(!is.na(date)) |>
  mutate(region = factor(region,
           levels = c("Arctic","SW_Indian","East_Pacific","West_Pacific")))

region_labels <- c(
  Arctic       = "Arctic Ocean (60-90\u00B0N)",
  SW_Indian    = "SW Indian Ocean",
  East_Pacific = "Eastern Pacific",
  West_Pacific = "Western Pacific"
)

# Trim extreme coastal outliers for cleaner display
slope_r[slope_r >  0.1 | slope_r < -0.1] <- NA
diff_r[ diff_r  >  0.5 | diff_r  < -0.5] <- NA


# =============================================================================
# SECTION 6: ANALYSIS / INDICATOR CALCULATION
# =============================================================================
# Description: Per-region Mann-Kendall trend test and Sen's slope on the
#              chlorophyll anomaly series.
# Inputs:      ts
# Outputs:     mk_results (one row per region)
# Notes:       z via $statistic[["z"]] and tau via $estimates[["tau"]] (using
#              $statistic[["tau"]] errors). The map trend/difference layers are
#              computed in GEE; the R analysis is the statistical testing here.
# =============================================================================

mk_results <- ts |>
  filter(!is.na(chl_anomaly)) |>
  group_by(region) |>
  arrange(date) |>
  summarise(
    n_obs     = n(),
    mean_anom = mean(chl_anomaly),
    mk_z      = mk.test(chl_anomaly)$statistic[["z"]],
    mk_tau    = mk.test(chl_anomaly)$estimates[["tau"]],
    mk_p      = mk.test(chl_anomaly)$p.value,
    sen_slope = as.numeric(sens.slope(chl_anomaly)$estimates),
    .groups   = "drop"
  ) |>
  mutate(trend_dir = ifelse(mk_p < 0.05,
                            ifelse(sen_slope > 0, "Increasing", "Decreasing"),
                            "No significant trend"))


# =============================================================================
# SECTION 7: QUALITY CHECKS
# =============================================================================
# Description: Print the trend results and a per-region data-coverage check.
# Inputs:      ts, mk_results
# Outputs:     console messages
# Notes:       Remember the productivity caveat: "more productive" (green/blue)
#              is not automatically good — interpret by region (upwelling vs
#              eutrophication).
# =============================================================================

print(mk_results)

cat("\nNon-missing daily observations per region:\n")
ts |>
  group_by(region) |>
  summarise(n_total = n(), n_valid = sum(!is.na(chl_anomaly)), .groups = "drop") |>
  print()


# =============================================================================
# SECTION 8 & 9: EXPORT OUTPUTS AND VISUALISATION
# =============================================================================
# Description: Build and save the four deliverable figures.
# Inputs:      ts, region_labels, slope_r, diff_r, world
# Outputs:     chl_anomaly_timeseries.png, chl_trend_global_map.png,
#              chl_early_vs_late_map.png, chl_productivity_combined.png
# Notes:       For figures, build and save are kept together (DMAP's Export and
#              Visualisation steps are combined here by design). Titles match
#              your saved outputs; swap them for the indicator name if you want
#              the indicator-titled version.
# =============================================================================

# --- OUTPUT 1: Regional anomaly time series with trendlines ---
p_ts <- ggplot(ts, aes(x = date, y = chl_anomaly)) +
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.4, linetype = "dashed") +
  geom_line(colour = "#6baed6", alpha = 0.6, linewidth = 0.3) +
  geom_smooth(method = "lm", colour = "#c0392b", linewidth = 1.0, se = TRUE, fill = "grey70") +
  facet_wrap(~ region, ncol = 2, labeller = labeller(region = region_labels)) +
  scale_x_date(date_breaks = "4 years", date_labels = "%Y") +
  labs(
    title    = "Change in Ocean Productivity 2002-2022",
    subtitle = "Monthly log10(chlorophyll-a) anomaly relative to 2002-2022 climatology\nRed line = linear trend | Shading = 95% confidence interval",
    x        = NULL,
    y        = "CHL anomaly (log10 mg/m3)",
    caption  = "Source: MODIS-Aqua L3SMI, NASA OB.DAAC | Analysis via Google Earth Engine"
  ) +
  theme_bw(base_size = 12) +
  theme(strip.background = element_rect(fill = "grey92"),
        panel.grid.minor = element_blank())

ggsave("chl_anomaly_timeseries.png", p_ts, width = 14, height = 9, dpi = 300, bg = "white")
print(p_ts)

# --- OUTPUT 2: Global trend (slope) map ---
p_trend <- ggplot() +
  geom_spatraster(data = slope_r) +
  geom_sf(data = world, fill = "grey25", colour = "grey40", linewidth = 0.1) +
  scale_fill_gradient2(
    low = "#d73027", mid = "white", high = "#4575b4", midpoint = 0,
    limits = c(-0.04, 0.04), oob = squish,
    name = "log10(CHL)\nper year", na.value = "transparent"
  ) +
  coord_sf(expand = FALSE) +
  labs(
    title    = "Change in Ocean Productivity 2002-2022",
    subtitle = "Rate of change in chlorophyll-a concentration (log10 mg m^-3 per year)\nBlue = increasing productivity | Red = declining productivity",
    caption  = "Source: MODIS-Aqua L3SMI, NASA OB.DAAC | Analysis via Google Earth Engine"
  ) +
  theme_bw(base_size = 12) +
  theme(legend.position = "right")

ggsave("chl_trend_global_map.png", p_trend, width = 14, height = 7, dpi = 300, bg = "white")
print(p_trend)

# --- OUTPUT 3: Early vs late difference map ---
p_diff <- ggplot() +
  geom_spatraster(data = diff_r) +
  geom_sf(data = world, fill = "grey25", colour = "grey40", linewidth = 0.1) +
  scale_fill_gradient2(
    low = "#d73027", mid = "white", high = "#1a9641", midpoint = 0,
    limits = c(-0.4, 0.4), oob = squish,
    name = "Delta log10(CHL)", na.value = "transparent"
  ) +
  coord_sf(expand = FALSE) +
  labs(
    title    = "Shift in Ocean Productivity: 2016-2022 vs 2002-2007",
    subtitle = "Difference in mean log10(CHL) between recent and early MODIS-Aqua periods\nGreen = more productive recently | Red = less productive recently",
    caption  = "Source: MODIS-Aqua L3SMI, NASA OB.DAAC | Analysis via Google Earth Engine"
  ) +
  theme_bw(base_size = 12) +
  theme(legend.position = "right")

ggsave("chl_early_vs_late_map.png", p_diff, width = 14, height = 7, dpi = 300, bg = "white")
print(p_diff)

# --- OUTPUT 4: Combined two-panel figure (trend over difference) ---
p_combined <- p_trend / p_diff +
  plot_annotation(
    title   = "Ocean Productivity Change Indicator - MODIS-Aqua 2002-2022",
    caption = "Top: pixel-wise linear trend slope | Bottom: difference between 2016-2022 and 2002-2007 mean CHL",
    theme   = theme(plot.title = element_text(size = 15, face = "bold"))
  )

ggsave("chl_productivity_combined.png", p_combined, width = 14, height = 14, dpi = 300, bg = "white")
print(p_combined)
