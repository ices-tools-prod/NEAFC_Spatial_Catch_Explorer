## Preprocess data, write TAF data tables

## Before:
## After:

library(icesTAF)

mkdir("data")

source.taf("data_neafc_areas.R")

source.taf("data_process.R")
