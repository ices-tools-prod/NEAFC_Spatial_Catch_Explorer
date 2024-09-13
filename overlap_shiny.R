
library(base64enc)

# Read the image file
img <- readBin("www/iceslogo.png", "raw", file.info("www/iceslogo.png")$size)
# Encode it to base64
img_base64 <- base64encode(img)

# Read and process the shapefile outside of the Shiny app
neafc_areas <- sf::st_read("NEAFC_areas.shp") %>%
  sf::st_transform(4326)  # Transform to WGS84 (EPSG:4326)



# Assuming grid_data is already created and includes a 'year' column
# Get unique species list and years
species_list <- sort(unique(grid_data$species))
   year_list <- sort(unique(grid_data$year))

   get_cell_color <- function(catch1, catch2) {
     dplyr::case_when(
       catch1 > 0 & catch2 > 0 ~ "purple",  # Both species present
       catch1 > 0 ~ "red",                  # Only species 1 present
       catch2 > 0 ~ "blue",                 # Only species 2 present
       TRUE ~ "transparent"                 # Neither species present
     )
   }

   ui <- fluidPage(
     tags$head(
       tags$style(HTML("
      #map {height: calc(100vh - 80px) !important;}
      .leaflet-container {height: 100% !important;}
      .logo {
        position: absolute;
        top: 10px;
        left: 30px;
        z-index: 1000;
      }
      .logo img {
        max-height: 50px;
        max-width: 150px;
      }
    "))
     ),
     titlePanel("NEAFC Catch and Spatial Overlap Explorer"),
     sidebarLayout(
       sidebarPanel(
         width = 3,  # Reduce the width of the sidebar
         checkboxInput("single_species", "Single Species View", value = FALSE),
         conditionalPanel(
           condition = "!input.single_species",
           selectInput("species1", "Select Species 1", choices = species_list),
           selectInput("species2", "Select Species 2", choices = species_list)
         ),
         conditionalPanel(
           condition = "input.single_species",
           selectInput("species_single", "Select Species", choices = species_list)
         ),
         radioButtons("year", "Select Year", 
                      choices = year_list,
                      selected = max(year_list)),
         actionButton("update", "Update Map")
       ),
       mainPanel(
         width = 9,  # Increase the width of the main panel
         div(class = "logo",
             tags$img(src = paste0("data:image/png;base64,", img_base64), alt = "ICES Logo")
         ),
         leafletOutput("map")
       )
     )
   )
   
   
   server <- function(input, output, session) {
     print(file.exists("www/iceslogo.png"))
     filtered_data <- eventReactive(input$update, {
       req(input$year)  # Ensure that a year is selected
       if (input$single_species) {
         req(input$species_single)  # Ensure that a species is selected
         result <- grid_data %>%
           dplyr::filter(species == input$species_single,
                         year == input$year)
         print(paste("Single species filtered data rows:", nrow(result)))
         print(paste("Columns:", paste(colnames(result), collapse = ", ")))
         print(paste("Total catch range:", paste(range(result$total_catch, na.rm = TRUE), collapse = " - ")))
         print(paste("NA count in total_catch:", sum(is.na(result$total_catch))))
       } else {
         req(input$species1, input$species2)  # Ensure that both species are selected
         result <- grid_data %>%
           dplyr::filter(species %in% c(input$species1, input$species2),
                         year == input$year)
       }
       print(paste("Filtered data rows:", nrow(result)))  # Debug print
       print(paste("Columns:", paste(colnames(result), collapse = ", ")))  # Debug print
       result
     })
     
     # Create the base map
     output$map <- renderLeaflet({
       leaflet(options = leafletOptions(zoomControl = FALSE)) %>%
         addTiles(urlTemplate = "https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}",
                  attribution = "Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri") %>%
         addTiles(urlTemplate = "https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Reference/MapServer/tile/{z}/{y}/{x}",
                  attribution = "Tiles &copy; Esri &mdash; Sources: GEBCO, NOAA, CHS, OSU, UNH, CSUMB, National Geographic, DeLorme, NAVTEQ, and Esri") %>%
         addPolygons(data = neafc_areas,
                     fillColor = "transparent",
                     color = "black",
                     weight = 2,
                     opacity = 1,
                     fillOpacity = 0,
                     group = "NEAFC Areas") %>%
         onRender(
           "function(el, x) {
          L.control.zoom({position:'topright'}).addTo(this);
        }")
     })
     
     # Update the map based on user input
     observe({
       req(input$update)
       data <- filtered_data()
       
       print(paste("Number of rows in data:", nrow(data)))
       print(paste("Columns in data:", paste(colnames(data), collapse = ", ")))
       
       if (input$single_species) {
         print(paste("Single species mode:", input$species_single))
         
         if (nrow(data) == 0 || all(is.na(data$total_catch))) {
           print("No data or all NA total_catch")
           leafletProxy("map") %>%
             clearGroup("Catches") %>%
             clearControls()
         } else {
           valid_data <- data %>% 
             dplyr::filter(!is.na(total_catch), total_catch > 0)
           
           print(paste("Valid data rows:", nrow(valid_data)))
           print(paste("Total catch range:", paste(range(valid_data$total_catch), collapse = " - ")))
           
           if (nrow(valid_data) > 0) {
             pal <- colorNumeric("viridis", domain = range(valid_data$total_catch))
             
             leafletProxy("map") %>%
               clearGroup("Catches") %>%
               clearControls() %>%
               addRectangles(
                 data = valid_data,
                 lng1 = ~lon_bin, lat1 = ~lat_bin,
                 lng2 = ~lon_bin + 0.05, lat2 = ~lat_bin + 0.05,
                 fillColor = ~pal(total_catch),
                 color = "transparent",
                 weight = 0,
                 opacity = 1,
                 fillOpacity = 0.7,
                 popup = ~paste(species, ": ", round(total_catch, 2), " kg"),
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
         # Two species mode
         print(paste("Two species mode:", input$species1, "and", input$species2))
         
         data1 <- data %>% dplyr::filter(species == input$species1)
         data2 <- data %>% dplyr::filter(species == input$species2)
         
         # Debug print
         print(paste("Rows in data1:", nrow(data1), "Rows in data2:", nrow(data2)))
         
         if (nrow(data1) == 0 && nrow(data2) == 0) {
           # Handle case where there's no data for either species
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
               lng2 = ~lon_bin + 0.05, lat2 = ~lat_bin + 0.05,
               fillColor = ~color,
               color = "transparent",
               weight = 0,
               opacity = 1,
               fillOpacity = 0.7,
               popup = ~paste(input$species1, ": ", round(catch1, 2), " kg<br>",
                              input$species2, ": ", round(catch2, 2), " kg"),
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
   # Run the application 
  shinyApp(ui = ui, server = server)
