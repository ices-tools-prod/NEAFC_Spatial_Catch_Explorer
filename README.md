# NEAFC Catch and Spatial Overlap Explorer

## Overview

This repository contains the code for the NEAFC Catch and Spatial Overlap Explorer Shiny app, developed in response to ICES Advice sr.2024.14: "NEAFC request on advice on discarding in the NEAFC regulatory area".

The app visualizes the spatial distribution of fish catches in the NEAFC Regulatory Area across different species and years, using VMS (Vessel Monitoring System) and catch report data.

## Features

- Interactive maps using Leaflet with ESRI's Ocean Base Map
- Dynamic filtering by year and species
- Single species and two-species comparison views
- Catch intensity representation through color gradients
- NEAFC area overlay

## Data

The app processes NEAFC VMS and catch report data, shared in an anonymised form with ICES under a data sharing agreement, aggregating catches into a 0.05° x 0.05° latitude-longitude grid using the c-square geocoding protocol.

## Related Resources

- Full ICES Advice: [DOI: 10.17895/ices.advice.26947132](https://doi.org/10.17895/ices.advice.26947132)
- Release Date: 30 September 2024

## Citation

ICES. 2024. NEAFC request on advice on discarding in the NEAFC regulatory area. In Report of the ICES Advisory Committee, 2024. ICES Advice 2024, sr.2024.14. https://doi.org/10.17895/ices.advice.26947132

## License

This software is licenced under a CC0 1.0 Universal licence [Creative Commons](https://creativecommons.org/publicdomain/zero/1.0/)

## Contact
Neil Campbell neil.campbell@ices.dk
Colin Millar colin.millar@ices.dk
