# Load required libraries
library(shiny)
library(leaflet)
library(dplyr)
library(tidyr)
library(raster)
library(lubridate)
library(htmlwidgets)
library(sf)

grid_out <- NULL

for (i in 2018:2023) {
  vms <- read.csv(paste0("data/NEAFC_TACSAT_", i, ".csv"))

  vms <- vms %>%
    filter(SI_SP >= 1 & SI_SP <= 6)

  catch <- read.csv(paste0("data/NEAFC_EFLALO_", i, ".csv"))


  # Helper function to convert date and time strings to POSIXct
  convert_datetime <- function(date, time) {
    paste(date, time) %>% dmy_hm()
  }

  # Process VMS data
  vms <- vms %>%
    mutate(datetime = convert_datetime(SI_DATE, SI_TIME))

  # Process catch data
  catch <- catch %>%
    mutate(
      trip_start = convert_datetime(FT_DDAT, FT_DTIME),
      trip_end = convert_datetime(FT_LDAT, FT_LTIME)
    )

  # Extract species names
  species_cols <- grep("^LE_KG_", names(catch), value = TRUE)
  species_names <- sub("^LE_KG_", "", species_cols)

  # Reshape catch data from wide to long format
  catch_long <- catch %>%
    pivot_longer(
      cols = all_of(species_cols),
      names_to = "species",
      values_to = "catch_kg"
    ) %>%
    mutate(species = sub("^LE_KG_", "", species)) %>%
    filter(!is.na(catch_kg) & catch_kg > 0)


  # Process VMS data
  vms_processed <- vms %>%
    mutate(
      date = as.Date(SI_DATE, format = "%d/%m/%Y"),
      trip_day_id = paste(VE_REF, format(date, "%Y%m%d"), sep = "_")
    )

  # Process catch data
  catch_processed <- catch_long %>%
    mutate(
      trip_start = as.Date(FT_DDAT, format = "%d/%m/%Y"),
      trip_end = as.Date(FT_LDAT, format = "%d/%m/%Y"),
      trip_length = as.numeric(trip_end - trip_start) + 1
    ) %>%
    filter(!is.na(trip_start) & !is.na(trip_end)) %>%
    rowwise() %>%
    mutate(
      trip_days = list(seq(trip_start, trip_end, by = "day"))
    ) %>%
    unnest(trip_days) %>%
    mutate(
      trip_day_id = paste(VE_REF, format(trip_days, "%Y%m%d"), sep = "_")
    ) %>%
    group_by(trip_day_id, species) %>%
    summarise(total_catch = sum(catch_kg, na.rm = TRUE), .groups = "drop")

  # Merge VMS and catch data
  merged_data <- vms_processed %>%
    left_join(catch_processed, by = "trip_day_id", relationship = "many-to-many") %>%
    filter(!is.na(total_catch)) %>% # Remove VMS points not associated with a catch
    group_by(trip_day_id, species) %>%
    mutate(
      points_per_day = n(),
      distributed_catch = total_catch / points_per_day
    ) %>%
    ungroup()

  # Create 0.05 x 0.05 degree grid
  grid_data <- merged_data %>%
    mutate(
      lat_bin = floor(SI_LATI / 0.05) * 0.05,
      lon_bin = floor(SI_LONG / 0.05) * 0.05
    ) %>%
    group_by(lat_bin, lon_bin, species) %>%
    summarise(total_catch = sum(distributed_catch, na.rm = TRUE), .groups = "drop")

  grid_data$year <- i

  grid_out <- rbind(grid_out, grid_data)
}

grid_data <- grid_out


# Convert grid_data to an sf object
grid_data_sf <- st_as_sf(grid_data, coords = c("lon_bin", "lat_bin"), crs = 4326)

neafc_areas <- sf::st_read("NEAFC_areas.shp")

# Filter grid_data to only include cells inside neafc_areas
filtered_grid_data <- grid_data_sf %>%
  filter(lengths(st_intersects(., neafc_areas)) > 0)

# If you want to convert back to a regular dataframe (tibble)
grid_data <- filtered_grid_data %>%
  st_drop_geometry() %>%
  bind_cols(st_coordinates(filtered_grid_data) %>% as_tibble()) %>%
  rename(lon_bin = X, lat_bin = Y)
