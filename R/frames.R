# Frames from spatial objects --------------------------------------------------

#' Turn a spatial object into a frame
#'
#' Converts an `sf` object (points or polygons) into the plain data frame that
#' [travel_matrix()] and [select_units()] expect: a column `unit`, the
#' coordinates `lat`/`lon` (centroids for polygons, in WGS 84) and, for
#' polygons, their `area` in square kilometres, next to the other columns of
#' the object. Nothing spatial is kept: use [as_sf()] to put the results back
#' on the geometries.
#'
#' @param x An `sf` object (the `sf` package must be installed), or a data
#'   frame returned unchanged.
#' @param unit Name of the column with the unit names; made from the row
#'   numbers when `NULL` and no `unit` column exists.
#' @return A tibble with `unit`, `lat`, `lon`, `area` (polygons only) and the
#'   attribute columns.
#' @export
#' @examples
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   sq <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)))),
#'     crs = 4326
#'   )
#'   cells <- sf::st_sf(crop = 3, geometry = sf::st_make_grid(sq, n = 3))
#'   as_frame(cells)
#' }
as_frame <- function(x, unit = NULL) {
  if (!inherits(x, "sf")) {
    return(tibble::as_tibble(x))
  }
  rlang::check_installed("sf", reason = "to read spatial frames.")
  geom <- sf::st_geometry(x)
  if (is.na(sf::st_crs(geom))) cli::cli_abort("{.arg x} needs a coordinate reference system.")
  is_poly <- any(sf::st_geometry_type(geom) %in% c("POLYGON", "MULTIPOLYGON"))
  d <- sf::st_drop_geometry(x)
  d <- tibble::as_tibble(d)
  if (!is.null(unit)) {
    if (!unit %in% names(d)) cli::cli_abort("Column {.field {unit}} not found.")
    d$unit <- as.character(d[[unit]])
  } else if (!"unit" %in% names(d)) d$unit <- paste0("u", seq_len(nrow(d)))
  pts <- if (is_poly) suppressWarnings(sf::st_centroid(geom)) else geom
  ll <- sf::st_coordinates(sf::st_transform(pts, 4326))
  d$lat <- ll[, 2]
  d$lon <- ll[, 1]
  if (is_poly) d$area <- as.numeric(sf::st_area(geom)) / 1e6
  d[, c("unit", "lat", "lon", if (is_poly) "area", setdiff(names(d), c("unit", "lat", "lon", "area")))]
}

#' Put results back on the geometries of a spatial frame
#'
#' Joins a sample, a frontier allocation or any data frame with a `unit`
#' column to the geometries of the `sf` object the frame came from, for maps.
#'
#' @param x A data frame with a `unit` column (a `fieldopt_sample`, for
#'   example).
#' @param sf The `sf` object that [as_frame()] was applied to.
#' @param unit Name of the column with the unit names in `sf`, as in
#'   [as_frame()].
#' @return An `sf` object with the columns of `x`.
#' @export
#' @examples
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   sq <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)))),
#'     crs = 4326
#'   )
#'   cells <- sf::st_sf(geometry = sf::st_make_grid(sq, n = 4))
#'   s <- select_units(as_frame(cells), n = 4, seed = 1)
#'   as_sf(s, cells)
#' }
as_sf <- function(x, sf, unit = NULL) {
  rlang::check_installed("sf", reason = "to build spatial objects.")
  if (!inherits(sf, "sf")) cli::cli_abort("{.arg sf} must be an {.cls sf} object.")
  if (!"unit" %in% names(x)) cli::cli_abort("{.arg x} needs a column {.field unit}.")
  key <- if (!is.null(unit)) as.character(sf[[unit]]) else if ("unit" %in% names(sf)) as.character(sf$unit) else paste0("u", seq_len(nrow(sf)))
  idx <- match(as.character(x$unit), key)
  if (anyNA(idx)) cli::cli_abort("Unit{?s} {.val {x$unit[is.na(idx)]}} not found in {.arg sf}.")
  out <- sf[idx, setdiff(names(sf), setdiff(names(x), "unit")), drop = FALSE]
  d <- tibble::as_tibble(unclass(x))
  for (col in setdiff(names(d), "unit")) out[[col]] <- d[[col]]
  out
}
