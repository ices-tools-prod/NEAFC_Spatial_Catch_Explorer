## Before:
## After:

library(icesTAF)

# create all folders
mkdir("shiny")
mkdir("shiny/data")

# copy in www data
cp(taf.data.path("www"), "shiny")

# copy NEAFC area shapefile
cp(taf.data.path("NEAFC_areas"), "shiny/data")

# copy in server data
cp("data/grid_data.RData", "shiny/data")

# copy in utilities
cp("utilities.R", "shiny/utilities.R")

# copy in server and ui scripts
cp("shiny_ui.R", "shiny/ui.R")
cp("shiny_server.R", "shiny/server.R")

msg("Created shiny app. To run, use: \n\n\tlibrary(shiny)\n\trunApp('shiny')\n\n")
