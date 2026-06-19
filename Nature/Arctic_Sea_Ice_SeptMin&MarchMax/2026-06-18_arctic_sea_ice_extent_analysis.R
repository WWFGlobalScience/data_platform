# =============================================================
# SECTION 1: HEADER
# =============================================================
# Indicator:    (1) Annual change in September minimum sea ice extent  [code TBD]
#               (2) Annual change in the March maximum sea ice extent   [code TBD]
# Description:  End-to-end analysis of Arctic September-minimum and March-
#               maximum sea ice extent. Produces annual trend graphs and
#               5-year directional trend tables from the NSIDC daily extent
#               CSV, and 5-year per-period change shapefiles and change maps
#               from the NSIDC monthly extent polygon shapefiles.
# Author:       Giselle Hall
# Date:         2026-06-18
# Last updated: 2026-06-18 — time-series and spatial scripts for both indicators
# Dependencies: tidyverse, sf, rvest, patchwork, scales, ggrepel, knitr,
#               kableExtra, svglite
#               (webshot2 optional, only to save colour tables as PNG)
# Environment:  Built in R [version] on Windows / RStudio
# =============================================================


# =============================================================
# SECTION 2: USER INPUTS
# =============================================================
# Description: All file paths, source URLs, and parameters an analyst must
#              update before running. No hardcoded local paths below this
#              section (per DMAP 4.4.1).
# Inputs:      none (definitions only)
# Outputs:     path + parameter variables used throughout the script
# Notes:       The NSIDC URLs are stable public hosted sources (DMAP 3.4),
#              kept as inputs in case NSIDC changes their directory structure.
# =============================================================

# --- Paths (replace placeholders) ---
source_data_path <- "path/to/source/data/N_seaice_extent_daily_v4.0.csv"  # daily CSV (time series)
output_path      <- "path/to/output/folder/"
shapefile_dir    <- "path/to/output/folder/shapefiles_5yr/"               # downloaded shapefiles land here

# --- Source URLs (NSIDC monthly EXTENT polygon shapefiles) ---
march_url <- "https://noaadata.apps.nsidc.org/NOAA/G02135/north/monthly/shapefiles/shp_extent/03_Mar/"
sept_url  <- "https://noaadata.apps.nsidc.org/NOAA/G02135/north/monthly/shapefiles/shp_extent/09_Sep/"

# --- Parameters ---
break_start <- 1980     # first breakpoint year (trend table + change maps)
break_end   <- 2025     # last breakpoint year (change maps)
break_step  <- 5        # interval (years)
breaks      <- seq(break_start, break_end, by = break_step)
sd_flag     <- 1        # trend graph: flag peaks/dips this many SD from the mean

# --- CRS settings ---
analysis_crs <- 6931    # EPSG:6931 = NSIDC EASE-Grid 2.0 North (equal area), for area calcs
storage_crs  <- 4326    # EPSG:4326 = WGS 84, DMAP 4.1 storage CRS for vector deliverables

# --- Display colours ---
col_loss   <- "#d7301f"   # red               – ice lost / dips
col_gain   <- "#2c7fb8"   # blue              – ice gained / peaks
col_remain <- "#a6cee3"   # light blue        – ice present in BOTH years
col_bg     <- "#eef5fb"   # even lighter blue – map background

# --- Output naming helper (ISO-date prefix) ---
# NOTE: confirm the exact SCRIPT/output naming convention in DMAP Appendix B.
iso_date <- format(Sys.Date(), "%Y-%m-%d")
out_file <- function(indicator_slug, suffix, ext) {
  file.path(output_path,
            paste0(iso_date, "_", indicator_slug, "__", suffix, ".", ext))
}


# =============================================================
# SECTION 3: LOAD LIBRARIES AND SOURCE FILES
# =============================================================
# Description: Load all packages required by this analysis.
# Inputs:      none
# Outputs:     attached packages
# Notes:       Missing packages are installed automatically on first run.
#              tidyverse provides ggplot2, dplyr, readr, tibble, etc.
# =============================================================

required_packages <- c("tidyverse", "sf", "rvest", "patchwork",
                       "scales", "ggrepel", "knitr", "kableExtra", "svglite")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
library(tidyverse)   # ggplot2 + dplyr + readr + tibble + stringr + purrr
library(sf)          # vector spatial processing
library(rvest)       # read the NSIDC directory listing
library(patchwork)   # arrange the map panels
library(scales)      # axis formatting
library(ggrepel)     # non-overlapping point labels
library(knitr)       # tables
library(kableExtra)  # colour-coded tables
library(svglite)     # SVG export device for ggsave


# =============================================================
# SECTION 4: LOAD AND INSPECT SOURCE DATA
# =============================================================
# Description: Read the daily extent CSV found in Sharepoint (time series), and download +
#              inspect the monthly extent polygon shapefiles (spatial).
# Inputs:      source_data_path; march_url, sept_url, breaks, shapefile_dir
# Outputs:     `raw` (daily CSV); unzipped SOURCE shapefiles under shapefile_dir
# Notes:       The CSV has a units row ("10^6 sq km") below the header that is
#              not data. The shapefile download ACQUIRES existing NSIDC files
#              (it does not generate any); the exact zip filename is matched
#              from the live directory listing rather than hardcoded, because
#              NSIDC has changed their v4 naming.
# =============================================================

# --- 4a. Daily extent CSV (time series source) ---
raw <- readr::read_csv(source_data_path, show_col_types = FALSE)
print(names(raw))     # confirm column names
print(head(raw, 3))   # confirm whether row 1 is a units row

# --- 4b. Download monthly extent shapefiles (spatial source) ---
download_month_shapefiles <- function(dir_url, month_num, years, dest_folder) {
  dir.create(dest_folder, showWarnings = FALSE, recursive = TRUE)
  mm     <- sprintf("%02d", month_num)
  tokens <- paste0(years, mm)                       # e.g. "198003","198503",...
  pat    <- paste0("_(", paste(tokens, collapse = "|"), ")_")

  page  <- read_html(dir_url)
  links <- page |> html_elements("a") |> html_attr("href")
  links <- links[!is.na(links)]
  zips  <- links[grepl("polygon", links, ignore.case = TRUE) &
                 grepl("\\.zip$", links, ignore.case = TRUE) &
                 grepl(pat, links)]

  if (length(zips) == 0)
    warning("No matching zips in: ", dir_url, " -- check current filenames.")

  for (z in zips) {
    dest_zip <- file.path(dest_folder, basename(z))
    if (!file.exists(dest_zip)) {
      message("Downloading ", basename(z))
      download.file(paste0(dir_url, z), dest_zip, mode = "wb")
    }
    unzip(dest_zip,
          exdir = file.path(dest_folder, tools::file_path_sans_ext(basename(z))))
  }
  message("Done: ", dir_url)
}

download_month_shapefiles(march_url, 3, breaks, file.path(shapefile_dir, "March"))
download_month_shapefiles(sept_url,  9, breaks, file.path(shapefile_dir, "September"))

# Locate a .shp for a given year/month anywhere under a download folder
find_shp <- function(root, year, month_num) {
  yyyymm <- paste0(year, sprintf("%02d", month_num))
  hits <- list.files(root,
                     pattern = paste0("extent_N_", yyyymm, "_polygon.*\\.shp$"),
                     recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  if (length(hits) == 0)
    stop("Shapefile not found for ", yyyymm, " under ", root)
  hits[1]
}

# Inspection: eyeball the earliest March file before processing all of it
plot(st_geometry(st_read(find_shp(file.path(shapefile_dir, "March"),
                                  break_start, 3), quiet = TRUE)),
     main = paste("Inspection:", break_start, "March extent"))


# =============================================================
# SECTION 5: DATA CLEANING AND PREPARATION
# =============================================================
# Description: Clean the daily CSV from Sharepoint into monthly means; define the helper that
#              reads each shapefile into a single equal-area extent polygon.
# Inputs:      `raw`, analysis_crs, find_shp()
# Outputs:     `sea`, `monthly`; read_extent() helper
# Notes:       Coercing to numeric turns the units row and blanks into NA,
#              which are dropped (DMAP 4.1: missing = NA, never 0/blank).
#              Column names are trimmed (the NSIDC file can carry leading
#              spaces). st_union dissolves the extent polygons into one
#              geometry; st_make_valid guards against topology errors.
# =============================================================

# --- 5a. Daily CSV -> monthly means ---
names(raw) <- trimws(names(raw))

sea <- raw |>
  mutate(
    Year   = suppressWarnings(as.integer(Year)),
    Month  = suppressWarnings(as.integer(Month)),
    Extent = suppressWarnings(as.numeric(Extent))
  ) |>
  filter(!is.na(Year), !is.na(Month), !is.na(Extent))

monthly <- sea |>
  group_by(Year, Month) |>
  summarise(extent = mean(Extent, na.rm = TRUE),
            n_days = n(), .groups = "drop")

# --- 5b. Shapefile -> single equal-area extent geometry ---
read_extent <- function(root, year, month_num) {
  st_read(find_shp(root, year, month_num), quiet = TRUE) |>
    st_transform(analysis_crs) |>
    st_make_valid() |>
    st_union()
}


# =============================================================
# SECTION 6: ANALYSIS / INDICATOR CALCULATION
# =============================================================
# Description: Derive the annual extent series and 5-year directional trend
#              tables (time series), and the per-period lost/gained/remaining
#              geometries, net change, and change maps (spatial).
# Inputs:      `monthly`; read_extent(), breaks, colour parameters
# Outputs:     march_max/sept_min, tbl_march/tbl_sept; march_res/sept_res
# Notes:       "Annual change" = this year minus last year (via lag()).
#              Net km^2 values are APPROXIMATE (geometry-derived from the
#              equal-area projection, not NSIDC's grid-cell count) and are
#              labelled as such. Near-pole differences on the earliest maps
#              may reflect changing sensor coverage, not real ice change
#              (DMAP 4.3: document comparability breaks).
# =============================================================

# --- 6a. Annual series + directional trend tables (time series) ---
march_max <- monthly |>
  filter(Month == 3) |>
  arrange(Year) |>
  transmute(Year, extent,
            yoy_change = extent - lag(extent),
            pct_change = (extent - lag(extent)) / lag(extent) * 100)

sept_min <- monthly |>
  filter(Month == 9) |>
  arrange(Year) |>
  transmute(Year, extent,
            yoy_change = extent - lag(extent),
            pct_change = (extent - lag(extent)) / lag(extent) * 100)

make_trend_table <- function(df) {
  brks <- seq(break_start, max(df$Year, na.rm = TRUE), by = break_step)
  vals <- df |> filter(Year %in% brks) |> select(Year, extent)

  tibble(start = head(brks, -1), end = tail(brks, -1)) |>
    left_join(vals, by = c("start" = "Year")) |> rename(start_extent = extent) |>
    left_join(vals, by = c("end"   = "Year")) |> rename(end_extent   = extent) |>
    mutate(
      Period       = paste0(start, "\u2013", end),
      Change       = end_extent - start_extent,
      `Change (%)` = (end_extent - start_extent) / start_extent * 100,
      Direction    = case_when(is.na(Change) ~ "Data missing",
                               Change > 0    ~ "Increase",
                               Change < 0    ~ "Decrease",
                               TRUE          ~ "No change")
    )
}

tbl_march <- make_trend_table(march_max)
tbl_sept  <- make_trend_table(sept_min)

# --- 6b. Per-period change geometries + maps (spatial) ---
poly_only <- function(g) {
  g <- suppressWarnings(st_make_valid(g))
  if (any(st_geometry_type(g) == "GEOMETRYCOLLECTION"))
    g <- suppressWarnings(st_collection_extract(g, "POLYGON"))
  g
}

make_diff_map <- function(root, year_early, year_late, month_num) {
  e <- read_extent(root, year_early, month_num)
  l <- read_extent(root, year_late,  month_num)

  remaining <- poly_only(suppressWarnings(st_intersection(e, l)))  # ice in BOTH
  lost      <- poly_only(suppressWarnings(st_difference(e, l)))    # ice lost
  gained    <- poly_only(suppressWarnings(st_difference(l, e)))    # ice gained

  period_lab <- paste0(year_early, "\u2013", year_late)

  add_layer <- function(g, lab) {
    if (length(g) == 0 || all(st_is_empty(g))) return(NULL)
    st_sf(period = period_lab, layer = lab, geometry = st_geometry(g))
  }
  parts <- do.call(rbind, Filter(Negate(is.null), list(
    add_layer(remaining, "Remaining ice"),
    add_layer(lost,      "Ice lost"),
    add_layer(gained,    "Ice gained"))))
  parts$layer <- factor(parts$layer,
                        levels = c("Remaining ice", "Ice lost", "Ice gained"))

  net_mkm2 <- as.numeric(st_area(l) - st_area(e)) / 1e12   # +ve gain, -ve loss
  box_fill <- ifelse(net_mkm2 >= 0, col_gain, col_loss)
  box_txt  <- sprintf("Net %s: %+.2f million km\u00B2 (approx.)",
                      ifelse(net_mkm2 >= 0, "gain", "loss"), net_mkm2)
  bb <- st_bbox(parts)
  lx <- bb["xmin"] + 0.02 * (bb["xmax"] - bb["xmin"])
  ly <- bb["ymax"] - 0.02 * (bb["ymax"] - bb["ymin"])

  p <- ggplot() +
    geom_sf(data = parts, aes(fill = layer), colour = NA) +
    scale_fill_manual(values = c("Remaining ice" = col_remain,
                                 "Ice lost"      = col_loss,
                                 "Ice gained"    = col_gain),
                      drop = FALSE, name = NULL) +
    annotate("label", x = lx, y = ly, hjust = 0, vjust = 1,
             label = box_txt, size = 3, colour = "white",
             fill = box_fill, label.size = 0, fontface = "bold") +
    labs(subtitle = paste0(year_early, " \u2192 ", year_late)) +
    theme_void(base_size = 11) +
    theme(plot.subtitle    = element_text(hjust = 0.5, face = "bold"),
          panel.background = element_rect(fill = col_bg, colour = NA))

  list(plot = p, net = net_mkm2, parts = parts)
}

analyse_indicator <- function(root, month_num) {
  periods <- tibble(early = head(breaks, -1), late = tail(breaks, -1))
  res <- Map(function(a, b) make_diff_map(root, a, b, month_num),
             periods$early, periods$late)
  nets <- tibble(Period = paste0(periods$early, "\u2013", periods$late),
                 net_change_million_km2 = vapply(res, `[[`, numeric(1), "net"))
  geom <- do.call(rbind, lapply(res, `[[`, "parts"))
  geom <- dplyr::left_join(geom, nets, by = c("period" = "Period"))
  list(plots = lapply(res, `[[`, "plot"), nets = nets, geom = geom)
}

march_res <- analyse_indicator(file.path(shapefile_dir, "March"),     3)
sept_res  <- analyse_indicator(file.path(shapefile_dir, "September"), 9)


# =============================================================
# SECTION 7: QUALITY CHECKS
# =============================================================
# Description: Range/coverage checks on the series; presence, finiteness, and
#              validity checks on the spatial outputs.
# Inputs:      sea, march_max, sept_min; breaks, shapefile_dir, *_res
# Outputs:     console messages only
# Notes:       Arctic monthly extent should sit roughly between 3 and 17
#              million km^2; values outside warrant investigation.
# =============================================================

cat("Daily record year range:", min(sea$Year), "to", max(sea$Year), "\n")
rng_ok <- function(df, label) {
  bad <- df |> filter(extent < 3 | extent > 17)
  if (nrow(bad) > 0) warning(label, ": ", nrow(bad), " value(s) outside 3-17 range.")
  else cat(label, ": all extent values within plausible range.\n")
}
rng_ok(march_max, "March maximum")
rng_ok(sept_min,  "September minimum")

check_files <- function(root, month_num, label) {
  miss <- breaks[!vapply(breaks, function(y) {
    length(list.files(root,
      pattern = paste0("extent_N_", y, sprintf("%02d", month_num),
                       "_polygon.*\\.shp$"),
      recursive = TRUE)) > 0, logical(1))]
  if (length(miss)) cat(label, "missing shapefiles for:", miss, "\n")
  else cat(label, ": all breakpoint shapefiles present.\n")
}
check_files(file.path(shapefile_dir, "March"),     3, "March")
check_files(file.path(shapefile_dir, "September"), 9, "September")

if (any(!is.finite(march_res$nets$net_change_million_km2)))
  warning("Non-finite net change value(s) in March results.")
if (any(!is.finite(sept_res$nets$net_change_million_km2)))
  warning("Non-finite net change value(s) in September results.")


# =============================================================
# SECTION 8: EXPORT OUTPUTS
# =============================================================
# Description: Write tabular outputs (CSV), the consolidated change
#              geometries (one Shapefile per indicator), and net-change CSVs.
# Inputs:      sea, march_max/sept_min, tbl_march/tbl_sept; *_res
# Outputs:     CSVs; one .shp per indicator (period + change-type attributes)
# Notes:       DMAP 4.1: a single consolidated vector file per indicator with
#              the temporal dimension held as an attribute field, in EPSG:4326,
#              as Shapefile.Net values approximate.
# =============================================================

# --- 8a. Tabular outputs ---
readr::write_csv(sea,       out_file("arctic_sea_ice_extent",           "daily_cleaned",  "csv"))
readr::write_csv(march_max, out_file("march_maximum_sea_ice_extent",     "annual_series",  "csv"))
readr::write_csv(sept_min,  out_file("september_minimum_sea_ice_extent", "annual_series",  "csv"))
readr::write_csv(tbl_march, out_file("march_maximum_sea_ice_extent",     "trend_table",    "csv"))
readr::write_csv(tbl_sept,  out_file("september_minimum_sea_ice_extent", "trend_table",    "csv"))

# --- 8b. Consolidated change shapefiles (one per indicator) ---
write_change_shp <- function(geom_sf, indicator_slug) {
  out <- geom_sf |>
    st_transform(storage_crs) |>                 # EPSG:4326 for storage
    dplyr::transmute(
      period   = gsub("\u2013", "-", period),     # ASCII hyphen for the .dbf
      chg_type = as.character(layer),             # Remaining ice / Ice lost / Ice gained
      net_mkm2 = round(net_change_million_km2, 4) # approximate net change
    )
  dest <- out_file(indicator_slug, "change_5yr", "shp")
  sf::st_write(out, dest, delete_dsn = TRUE, quiet = TRUE)  # driver = ESRI Shapefile
  message("Wrote shapefile: ", dest)
}
write_change_shp(march_res$geom, "march_maximum_sea_ice_extent")
write_change_shp(sept_res$geom,  "september_minimum_sea_ice_extent")

# --- 8c. Net-change summary tables ---
readr::write_csv(march_res$nets, out_file("march_maximum_sea_ice_extent",     "net_change_5yr", "csv"))
readr::write_csv(sept_res$nets,  out_file("september_minimum_sea_ice_extent", "net_change_5yr", "csv"))


# =============================================================
# SECTION 9: VISUALISATION
# =============================================================
# Description: Trend graphs (line + linear trend, peaks/dips flagged),
#              colour-coded directional trend tables, and per-period change
#              map panels. Headings use the full indicator name.
# Inputs:      march_max/sept_min, tbl_march/tbl_sept, *_res, sd_flag
# Outputs:     trend graph PNG+SVG; colour table objects + HTML/PNG; change
#              map panel PNG per indicator
# Notes:       PNG table export needs {webshot2} + a Chrome/Chromium install;
#              the HTML export always works and is the fallback.
# =============================================================

# --- 9a. Trend graphs ---
make_trend_plot <- function(df, indicator_name, line_colour) {
  m <- mean(df$extent, na.rm = TRUE)
  s <- sd(df$extent,   na.rm = TRUE)
  df <- df |>
    mutate(flag = case_when(extent > m + sd_flag * s ~ "Peak",
                            extent < m - sd_flag * s ~ "Dip",
                            TRUE                     ~ NA_character_))
  ggplot(df, aes(Year, extent)) +
    geom_line(colour = line_colour, linewidth = 0.9) +
    geom_point(colour = line_colour, size = 1.6) +
    geom_smooth(method = "lm", se = FALSE, linetype = "dashed",
                colour = "grey40", linewidth = 0.7) +
    geom_point(data = ~ filter(.x, !is.na(flag)), aes(colour = flag), size = 3) +
    ggrepel::geom_text_repel(data = ~ filter(.x, !is.na(flag)),
               aes(label = Year), size = 3, seed = 1) +
    scale_colour_manual(values = c(Peak = col_gain, Dip = col_loss),
                        name = NULL, na.translate = FALSE) +
    scale_x_continuous(breaks = scales::breaks_width(5)) +
    labs(title = indicator_name, x = NULL,
         y = expression("Sea ice extent (million km"^2*")"),
         caption = "Source: NSIDC Sea Ice Index v4 (G02135)") +
    theme_minimal(base_size = 12)
}

p_march <- make_trend_plot(march_max,
             "Annual change in the March maximum sea ice extent", "#1f78b4")
p_sept  <- make_trend_plot(sept_min,
             "Annual change in September minimum sea ice extent", "#e6550d")
print(p_march); print(p_sept)

ggsave(out_file("march_maximum_sea_ice_extent",     "trend_graph", "png"), p_march, width = 9, height = 5.5, dpi = 300)
ggsave(out_file("march_maximum_sea_ice_extent",     "trend_graph", "svg"), p_march, width = 9, height = 5.5)
ggsave(out_file("september_minimum_sea_ice_extent", "trend_graph", "png"), p_sept,  width = 9, height = 5.5, dpi = 300)
ggsave(out_file("september_minimum_sea_ice_extent", "trend_graph", "svg"), p_sept,  width = 9, height = 5.5)

# --- 9b. Colour-coded directional trend tables (kept as objects) ---
render_trend_table <- function(tbl, indicator_name) {
  out <- tbl |>
    transmute(Period,
              `Extent change (million km^2)` = round(Change, 3),
              `Change (%)` = round(`Change (%)`, 1),
              Direction)
  colours <- ifelse(is.na(tbl$Change), "black",
              ifelse(tbl$Change >= 0, "darkgreen", "red"))
  out |>
    kbl(caption = indicator_name, align = "lccc") |>
    kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover")) |>
    column_spec(2, color = colours) |>
    column_spec(3, color = colours) |>
    column_spec(4, color = colours)
}

kbl_march <- render_trend_table(tbl_march,
               "Annual change in the March maximum sea ice extent")
kbl_sept  <- render_trend_table(tbl_sept,
               "Annual change in September minimum sea ice extent")
kbl_march
kbl_sept

kableExtra::save_kable(kbl_march, out_file("march_maximum_sea_ice_extent",     "trend_table", "html"), self_contained = TRUE)
kableExtra::save_kable(kbl_sept,  out_file("september_minimum_sea_ice_extent", "trend_table", "html"), self_contained = TRUE)
if (requireNamespace("webshot2", quietly = TRUE)) {
  kableExtra::save_kable(kbl_march, out_file("march_maximum_sea_ice_extent",     "trend_table", "png"), zoom = 2)
  kableExtra::save_kable(kbl_sept,  out_file("september_minimum_sea_ice_extent", "trend_table", "png"), zoom = 2)
} else {
  message("Install {webshot2} to also save the colour tables as PNG; HTML versions were written.")
}

# --- 9c. Per-period change map panels ---
assemble_panel <- function(plots, indicator_name) {
  patchwork::wrap_plots(plots, ncol = 3, guides = "collect") +
    patchwork::plot_annotation(
      title    = indicator_name,
      subtitle = "Light blue = remaining ice | red = ice lost | blue = ice gained",
      caption  = "Source: NSIDC Sea Ice Index v4 (G02135). Net values approximate.") &
    theme(legend.position = "bottom")
}

march_panel <- assemble_panel(march_res$plots,
                 "Annual change in the March maximum sea ice extent")
sept_panel  <- assemble_panel(sept_res$plots,
                 "Annual change in September minimum sea ice extent")
print(march_panel); print(sept_panel)

ggsave(out_file("march_maximum_sea_ice_extent",     "change_maps_5yr", "png"), march_panel, width = 12, height = 12, dpi = 300)
ggsave(out_file("september_minimum_sea_ice_extent", "change_maps_5yr", "png"), sept_panel,  width = 12, height = 12, dpi = 300)

