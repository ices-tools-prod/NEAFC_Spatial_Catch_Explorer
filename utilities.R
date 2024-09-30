# extras
get_cell_color <- function(catch1, catch2) {
  dplyr::case_when(
    catch1 > 0 & catch2 > 0 ~ "purple", # Both species present
    catch1 > 0 ~ "red", # Only species 1 present
    catch2 > 0 ~ "blue", # Only species 2 present
    TRUE ~ "transparent" # Neither species present
  )
}
