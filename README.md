# Conservation Navigator Code
This repository contains the codebase used by the WWF Conservation Navigator team to retrieve, process, and analyze data for specific landscapes across the Conservation Navigator framework. Scripts are organized by dimension and cover all key indicators tracked in the platform.

The codebase is made available so that users can explore the methods behind the data, adapt scripts to fit their own analytical needs, and get a head start on their own analysis. The repository is continually updated and improved as new data sources and indicators are added.

> **Note:** This repository is continually updated and cleaned. Check back regularly for new scripts and improved methods.
---
## Contact
For questions on how to use this repository or the Conservation Navigator platform, please reach out to the team at:
**navigator@wwf.org**

## Repository Structure
Scripts are organized into folders by framework dimension. Each folder contains scripts for retrieving source data, processing it to different spatial scales - landscape level and/or country etc, and generating outputs (CSVs, GeoPackages, and charts).
```
data_platform/
├── Climate/                  # Climate and carbon indicators
├── Nature/                   # Biodiversity and ecosystem extent
├── People/                   # Human development and wellbeing
├── Governance/               # Institutional quality and rights
├── Conservation_Activities/  # Protected areas and conservation status
├── Pressures_Drivers/        # Human pressures and environmental drivers
├── data_inputs/              # Reference geospatial layers and overlap data
├── Scapes_GDL_Trends/        # Generated gender inequality trend charts by landscape
└── Scapes_GDL_Poverty_Trends/# Generated poverty trend charts by landscape
```

## Dimensions
### Climate
Scripts for climate and carbon-related indicators including above-ground biomass, drought index, burned area, greenhouse gas emissions, and flood risk. Raw data comes from sources such as the ESA Climate Change Initiative and Google Earth Engine.
### Nature
Scripts for biodiversity and ecosystem extent indicators including forest cover, mangroves, coral reefs, peatlands, seagrass, tidal marsh, free-flowing rivers, Red List Index, and species occurrence for WWF focal species. Includes both remote sensing processing and occurrence data from GBIF.
### People
Scripts for human development and wellbeing indicators covering health (child and maternal mortality, vaccination coverage, water and sanitation), nutrition (stunting, wasting, food insecurity), education, gender inequality, poverty (multidimensional, subnational, and international), income inequality, child labor, and reproductive rights. Data sources include WHO, World Bank, and Global Data Lab datasets.
### Governance
Scripts for institutional and governance indicators including the Corruption Perceptions Index, subnational corruption measures, armed conflict events (ACLED), environmental defender deaths, and land tenure security. Outputs are joined to country boundaries and exported as GeoPackages.
### Conservation Activities
Scripts for quantifying protected areas (WDPA), Other Effective Conservation Measures (OECMs), Indigenous and Community Conserved Areas (ICCAs), Key Biodiversity Areas (KBAs), and protected area downlisting/degazettement (PADDD). Also includes threatened species assessments from the IUCN Red List.
### Pressures & Drivers
Google Earth Engine scripts for quantifying human pressures on landscapes including the Global Human Modification Index, water stress, water use efficiency, activity at sea, dam density, invasive species, forest production rates, food loss and waste, and mismanaged plastic waste.
---
## Scripting Languages
Scripts are provided in multiple languages depending on the data source and processing requirements:
| Language | Use |
|---|---|
| **R** | Data cleaning, statistical analysis, and visualization (ggplot2, tidyverse, sf) |
| **Python** | Geospatial raster and vector processing (GDAL, numpy, ecoshard, arcpy) |
| **JavaScript** | Google Earth Engine cloud-based remote sensing computations |
All scripts can be modified to fit your own analysis needs.
--
## Reference Data

The `data_inputs/` folder contains the reference geospatial layers used across all dimensions - note that due to size constraints not all input data is stored in this repository:
- **Prod_countries_EE/** — Production country shapefile with ISO3 codes used to spatially filter data to relevant landscapes
- **GDL overlap tables** — Linkage between Global Data Lab poverty zones and the 243 pilot landscapes
--
## Outputs

Depending on the dimension, scripts produce:
- **CSV files** — Time-series indicator tables filtered to pilot landscapes, named with the indicator and export date
- **GeoPackages (.gpkg)** — Spatial indicator layers joined to country or landscape boundaries, ready for use in GIS
- **PNG charts** — Landscape-specific trend visualizations
---
## Getting Started
1. Clone this repository to your local machine.
2. Navigate to the dimension folder relevant to your indicator of interest.
3. Open the script in R, Python, or a Google Earth Engine code editor as appropriate.
4. Update any file paths to point to your local data sources.
5. Modify the script as needed for your landscape or analysis scope.


