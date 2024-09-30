

library(icesTAF)

mkdir("data")

# Read and process the shapefile
neafc_areas <- sf::st_read("boot/data/NEAFC_areas/NEAFC_areas.shp", quiet = TRUE) %>%
  sf::st_transform(4326) # Transform to WGS84 (EPSG:4326)

save(neafc_areas, file = "data/neafc_areas.RData")
