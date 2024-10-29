library(shiny)
library(base64enc)
library(sf)
library(dplyr)
library(leaflet)
library(shiny)
library(htmltools)
library(htmlwidgets)

# utilities
source("utilities.R")

# Read the image file and encode it to base64
img <- readBin("www/iceslogo.png", "raw", file.info("www/iceslogo.png")$size)
img_base64 <- base64encode(img)

# Read and process the shapefile
load("data/neafc_areas.RData", envir = .GlobalEnv)

# load grid_data
load("data/grid_data.RData", envir = .GlobalEnv)

# Assuming grid_data is already created and includes a 'year' column
# Get unique species list and years
species_list <- sort(unique(grid_data$species))
year_list <- sort(unique(grid_data$year))

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
      .btn-block {
      margin-bottom: 10px;
      width: 100%;
    }
    .btn-block:hover {
      background-color: #e9ecef;
    }
      .logo img {
        max-height: 50px;
        max-width: 150px;
      }
      .coordinate-labels {
        position: absolute;
        z-index: 1000;
        font-size: 12px;
        font-weight: bold;
        color: #000;
        background-color: rgba(255, 255, 255, 0.9);
        padding: 3px 6px;
        border-radius: 3px;
        border: 1px solid #333;
        pointer-events: none;
      }
      .lat-label-top { top: 10px; left: 50%; transform: translateX(-50%); }
      .lat-label-bottom { bottom: 10px; left: 50%; transform: translateX(-50%); }
      .lon-label-left { top: 50%; left: 10px; transform: translateY(-50%); }
      .lon-label-right { top: 50%; right: 10px; transform: translateY(-50%); }
    "))
  ),
  titlePanel("NEAFC Catch and Spatial Overlap Explorer"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      checkboxInput("single_species", "Single Species View", value = FALSE),
      conditionalPanel(
        condition = "!input.single_species",
        selectInput("species1", "Select Species 1", choices = species_list, selected = "Clupea harengus"),
        selectInput("species2", "Select Species 2", choices = species_list, selected = "Scomber scombrus")
      ),
      conditionalPanel(
        condition = "input.single_species",
        selectInput("species_single", "Select Species", choices = species_list, selected = "Gadus morhua")
      ),
      radioButtons("year", "Select Year",
        choices = year_list,
        selected = max(year_list)
      ),
      tags$div(
        style = "margin-top: 20px;",
        tags$h4("Quick Zoom"),
        tags$p(
          "Data may not be visible when viewed at full scale - zoom in to visualise catch overlaps.",
          style = "font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 15px;"
        ),
        actionButton("zoom_ra1", "NEAFC RA 1", class = "btn-block"),
        actionButton("zoom_ra2", "NEAFC RA 2", class = "btn-block"),
        actionButton("zoom_ra3", "NEAFC RA 3", class = "btn-block")
      ),
      actionButton("update", "Update Map"),
      tags$div(
      style = "margin-top: 30px; border-top: 1px solid #ddd; padding-top: 20px;",
      tags$h5("Recommended citation", 
             style = "font-weight: bold; margin-bottom: 10px;"),
      tags$p(
        "ICES NEAFC Catch Explorer, [date accessed]. ICES, Copenhagen, Denmark.",
        tags$a(
          href = "https://www.ices.dk/advice/Pages/NEAFC-catch-explorer.aspx",
          "https://www.ices.dk/advice/Pages/NEAFC-catch-explorer.aspx",
          target = "_blank",
          style = "word-wrap: break-word;"
        ),
        style = "font-size: 0.8em; color: #666; line-height: 1.4;"
      )
    )
  ),
    mainPanel(
      width = 9,
      div(
        class = "logo",
        tags$img(src = paste0("data:image/png;base64,", img_base64), alt = "ICES Logo")
      ),
      leafletOutput("map")
    )
  )
)
