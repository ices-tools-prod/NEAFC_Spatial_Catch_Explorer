
# the app logic
server <- function(input, output, session) {
  filtered_data <- eventReactive(input$update, {
    req(input$year)
    if (input$single_species) {
      req(input$species_single)
      result <- grid_data %>%
        dplyr::filter(
          species == input$species_single,
          year == input$year
        )
    } else {
      req(input$species1, input$species2)
      result <- grid_data %>%
        dplyr::filter(
          species %in% c(input$species1, input$species2),
          year == input$year
        )
    }
    result
  })

  output$map <- renderLeaflet({
    leaflet(options = leafletOptions(zoomControl = FALSE)) %>%
      addTiles(
        urlTemplate = "https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}",
        attribution = "Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri"
      ) %>%
      addTiles(
        urlTemplate = "https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Reference/MapServer/tile/{z}/{y}/{x}",
        attribution = "Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri"
      ) %>%
      addPolygons(
        data = neafc_areas,
        fillColor = "transparent",
        color = "black",
        weight = 2,
        opacity = 1,
        fillOpacity = 0,
        group = "NEAFC Areas"
      ) %>%
      addGraticule(interval = 10, style = list(color = "#999", weight = 0.5, opacity = 0.5)) %>%
      addGraticule(interval = 5, style = list(color = "#999", weight = 0.25, opacity = 0.3)) %>%
      onRender("
        function(el, x) {
          console.log('Map render function called');
          L.control.zoom({position:'topright'}).addTo(this);

          // Create labels for coordinates
          var latLabelTop = L.DomUtil.create('div', 'coordinate-labels lat-label-top');
          var latLabelBottom = L.DomUtil.create('div', 'coordinate-labels lat-label-bottom');
          var lonLabelLeft = L.DomUtil.create('div', 'coordinate-labels lon-label-left');
          var lonLabelRight = L.DomUtil.create('div', 'coordinate-labels lon-label-right');

          el.appendChild(latLabelTop);
          el.appendChild(latLabelBottom);
          el.appendChild(lonLabelLeft);
          el.appendChild(lonLabelRight);
          console.log('Labels created');

          // Function to update coordinate labels
          function updateCoordinateLabels() {
            var bounds = this.getBounds();
            var northLat = bounds.getNorth().toFixed(2);
            var southLat = bounds.getSouth().toFixed(2);
            var westLon = bounds.getWest().toFixed(2);
            var eastLon = bounds.getEast().toFixed(2);

            latLabelTop.innerHTML = Math.abs(northLat) + '°' + (northLat >= 0 ? 'N' : 'S');
            latLabelBottom.innerHTML = Math.abs(southLat) + '°' + (southLat >= 0 ? 'N' : 'S');
            lonLabelLeft.innerHTML = Math.abs(westLon) + '°' + (westLon >= 0 ? 'E' : 'W');
            lonLabelRight.innerHTML = Math.abs(eastLon) + '°' + (eastLon >= 0 ? 'E' : 'W');

            console.log('Updating labels:', northLat, southLat, westLon, eastLon);
          }

          // Update labels on initial load and whenever the map moves
          this.on('load moveend', updateCoordinateLabels);

          // Initial update
          updateCoordinateLabels.call(this);
        }")
  })

  observe({
    req(input$update)
    data <- filtered_data()

    if (input$single_species) {
      if (nrow(data) == 0 || all(is.na(data$total_catch))) {
        leafletProxy("map") %>%
          clearGroup("Catches") %>%
          clearControls()
      } else {
        valid_data <- data %>%
          dplyr::filter(!is.na(total_catch), total_catch > 0)

        if (nrow(valid_data) > 0) {
          pal <- colorNumeric("viridis", domain = range(valid_data$total_catch))

          leafletProxy("map") %>%
            clearGroup("Catches") %>%
            clearControls() %>%
            addRectangles(
              data = valid_data,
              lng1 = ~lon_bin, lat1 = ~lat_bin,
              lng2 = ~ lon_bin + 0.05, lat2 = ~ lat_bin + 0.05,
              fillColor = ~ pal(total_catch),
              color = "transparent",
              weight = 0,
              opacity = 1,
              fillOpacity = 0.7,
              popup = ~ paste(species, ": ", round(total_catch, 2), " kg"),
              group = "Catches"
            ) %>%
            addLegend(
              position = "bottomright",
              pal = pal,
              values = valid_data$total_catch,
              title = paste(input$species_single, "Catch -", input$year),
              opacity = 1
            )
        } else {
          leafletProxy("map") %>%
            clearGroup("Catches") %>%
            clearControls()
        }
      }
    } else {
      data1 <- data %>% dplyr::filter(species == input$species1)
      data2 <- data %>% dplyr::filter(species == input$species2)

      if (nrow(data1) == 0 && nrow(data2) == 0) {
        leafletProxy("map") %>%
          clearGroup("Catches") %>%
          clearControls() %>%
          addLegend("bottomright",
            colors = "gray",
            labels = "No data",
            title = paste("No data for", input$year),
            opacity = 1
          )
      } else {
        combined_data <- dplyr::full_join(
          data1 %>% dplyr::select(lon_bin, lat_bin, catch1 = total_catch),
          data2 %>% dplyr::select(lon_bin, lat_bin, catch2 = total_catch),
          by = c("lon_bin", "lat_bin")
        ) %>%
          tidyr::replace_na(list(catch1 = 0, catch2 = 0)) %>%
          dplyr::mutate(color = get_cell_color(catch1, catch2))

        leafletProxy("map") %>%
          clearGroup("Catches") %>%
          addRectangles(
            data = combined_data,
            lng1 = ~lon_bin, lat1 = ~lat_bin,
            lng2 = ~ lon_bin + 0.05, lat2 = ~ lat_bin + 0.05,
            fillColor = ~color,
            color = "transparent",
            weight = 0,
            opacity = 1,
            fillOpacity = 0.7,
            popup = ~ paste(
              input$species1, ": ", round(catch1, 2), " kg<br>",
              input$species2, ": ", round(catch2, 2), " kg"
            ),
            group = "Catches"
          ) %>%
          clearControls() %>%
          addLegend("bottomright",
            colors = c("red", "blue", "purple"),
            labels = c(input$species1, input$species2, "Both species"),
            title = paste("Species Presence -", input$year),
            opacity = 1
          )
      }
    }
  })
}
