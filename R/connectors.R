# Connectors: survey, record linkage and the area-frame service ---------------

#' Hand a sample to the survey package
#'
#' Builds a `survey` design object from a [select_units()] sample so that the
#' estimators of that package (calibration, post-stratification, domains,
#' ratios, regression) can be used on the field data. Units not sampled are
#' dropped; the weights are the inverse inclusion probabilities, and the
#' strata of the sample are the strata of the design.
#'
#' * Samples with interpenetrating replicates (`method = "systematic"`,
#'   `replicates > 1`) become a replicate-weight design
#'   ([survey::svrepdesign()]) whose variance is the variance between the
#'   replicate estimates, the one [design_variance()] uses.
#' * Other samples become a [survey::svydesign()]: with `variance =
#'   "brewer"` (default) the without-replacement probability-proportional-to-
#'   size approximation of Brewer, which needs no joint probabilities; with
#'   `variance = "srs"` the finite-population correction of simple random
#'   sampling within strata. Neither uses the spatial balance of the local
#'   pivotal method, so for the variance of a total of a spatially balanced
#'   sample prefer [design_variance()]; use the `survey` object for what it
#'   adds.
#'
#' @param sample A [select_units()] sample.
#' @param variance `"brewer"` or `"srs"` (ignored for replicated samples).
#' @return A `survey.design2` or `svyrep.design` object.
#' @export
#' @examples
#' if (requireNamespace("survey", quietly = TRUE)) {
#'   cells <- expand.grid(x = 1:10, y = 1:10); cells$unit <- paste0("c", 1:100)
#'   cells$crop <- 10 + cells$x + rnorm(100)
#'   s <- select_units(cells, n = 20, seed = 1)
#'   d <- as_svydesign(s)
#'   survey::svytotal(~crop, d)
#'   design_variance(s, "crop")[, c("total", "se")]
#' }
as_svydesign <- function(sample, variance = c("brewer", "srs")) {
  rlang::check_installed("survey", reason = "to build survey design objects.")
  variance <- rlang::arg_match(variance)
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  st <- attr(sample, "strata"); rep_mat <- attr(sample, "replicates")
  s <- sample$sampled
  d <- tibble::as_tibble(unclass(sample))[s, ]
  d$.stratum <- if (is.null(st)) factor("all") else factor(d[[st]])
  if (!is.null(rep_mat)) {
    r <- ncol(rep_mat); pr <- attr(sample, "pi_replicate")[s]
    full <- rowSums(rep_mat[s, , drop = FALSE]) / (pr * r)       # average of the replicate weights
    repw <- rep_mat[s, , drop = FALSE] / pr                        # 1 / (p / r) when in the replicate, 0 otherwise
    repw[!rep_mat[s, , drop = FALSE]] <- 0
    d$.weight <- full
    return(survey::svrepdesign(data = as.data.frame(d), weights = ~.weight, repweights = repw, type = "other",
                               scale = 1 / (r * (r - 1)), rscales = rep(1, r), combined.weights = TRUE))
  }
  d$.prob <- d$pi
  if (variance == "brewer") {
    survey::svydesign(ids = ~1, strata = ~.stratum, probs = ~.prob, fpc = ~.prob, pps = "brewer", data = as.data.frame(d))
  } else {
    N_h <- table(if (is.null(st)) factor(rep("all", nrow(sample))) else factor(sample[[st]]))
    d$.fpc <- as.numeric(N_h[as.character(d$.stratum)])
    survey::svydesign(ids = ~1, strata = ~.stratum, probs = ~.prob, fpc = ~.fpc, data = as.data.frame(d))
  }
}

#' Overlap between a list frame and the area frame
#'
#' Finds, for every establishment of a list frame, the cell of the area
#' frame it falls in, and marks its domain: `"ab"` when it lies in a cell of
#' the frame (it can be reached through the area sample as well), `"b"`
#' otherwise. The cells get the count and the names of the listed
#' establishments inside them, which is what field teams need to screen the
#' overlap out of the area sample (the screening design) or what
#' [dual_frame_estimator()] needs as domains.
#'
#' Locations are matched with coordinates: square cells of side `cell_size`
#' around the cell centres (the columns `coords`), or exact polygons when
#' `cells` and `list` are `sf` objects (the `sf` package is then used). A
#' table of `pairs` from record linkage (for example from the `reclin2`
#' package) can add or override matches: rows with the list unit and the
#' cell it belongs to.
#'
#' @param list Data frame of the list frame with a column `unit` and the
#'   coordinate columns (or an `sf` object of points).
#' @param cells The area frame as in [select_units()] (or an `sf` object of
#'   polygons with a `unit` column).
#' @param cell_size Side of the square cells, in the unit of the coordinates
#'   (ignored for polygons).
#' @param coords Names of the coordinate columns in both tables.
#' @param pairs Optional data frame with columns `unit` (list) and `cell`.
#' @return A list with `list` (the list frame with columns `cell` and
#'   `domain`) and `cells` (the area frame with columns `listed`, the number
#'   of listed establishments inside, and `listed_units`, their names).
#' @export
#' @examples
#' cells <- expand.grid(x = 1:5, y = 1:5); cells$unit <- paste0("c", 1:25)
#' farms <- data.frame(unit = c("f1", "f2", "f3"), x = c(1.2, 3.4, 9), y = c(1.1, 2.6, 9))
#' ov <- frame_overlap(farms, cells, cell_size = 1)
#' ov$list
#' ov$cells[ov$cells$listed > 0, ]
frame_overlap <- function(list, cells, cell_size = 1, coords = NULL, pairs = NULL) {
  spatial <- inherits(list, "sf") || inherits(cells, "sf")
  if (spatial) {
    rlang::check_installed("sf", reason = "to match points to polygons.")
    if (!inherits(list, "sf") || !inherits(cells, "sf")) cli::cli_abort("With spatial objects, both {.arg list} and {.arg cells} must be {.cls sf}.")
    if (!"unit" %in% names(cells)) cli::cli_abort("{.arg cells} needs a column {.field unit}.")
    if (!"unit" %in% names(list)) cli::cli_abort("{.arg list} needs a column {.field unit}.")
    hit <- sf::st_join(list, cells[, "unit"], join = sf::st_within, left = TRUE, suffix = c("", ".cell"))
    hit <- hit[!duplicated(hit$unit), ]
    cell <- as.character(hit$unit.cell)[match(list$unit, hit$unit)]
    list_out <- tibble::as_tibble(sf::st_drop_geometry(list)); list_out$unit <- as.character(list$unit)
    cells_out <- tibble::as_tibble(sf::st_drop_geometry(cells)); cells_out$unit <- as.character(cells$unit)
  } else {
    list_out <- tibble::as_tibble(list); cells_out <- tibble::as_tibble(cells)
    if (!"unit" %in% names(cells_out)) cells_out$unit <- paste0("u", seq_len(nrow(cells_out)))
    if (!"unit" %in% names(list_out)) cli::cli_abort("{.arg list} needs a column {.field unit}.")
    if (is.null(coords)) coords <- if (all(c("lat", "lon") %in% names(cells_out))) c("lat", "lon") else c("x", "y")
    for (col in coords) { if (!col %in% names(cells_out)) cli::cli_abort("Column {.field {col}} not found in {.arg cells}."); if (!col %in% names(list_out)) cli::cli_abort("Column {.field {col}} not found in {.arg list}.") }
    if (!is.numeric(cell_size) || cell_size <= 0) cli::cli_abort("{.arg cell_size} must be positive.")
    ca <- as.numeric(cells_out[[coords[1]]]); cb <- as.numeric(cells_out[[coords[2]]])
    la <- as.numeric(list_out[[coords[1]]]); lb <- as.numeric(list_out[[coords[2]]])
    cell <- vapply(seq_along(la), function(i) {
      if (is.na(la[i]) || is.na(lb[i])) return(NA_character_)
      d <- pmax(abs(ca - la[i]), abs(cb - lb[i]))
      k <- which.min(d)
      if (length(k) && d[k] <= cell_size / 2 + 1e-9) as.character(cells_out$unit[k]) else NA_character_
    }, character(1))
    list_out$unit <- as.character(list_out$unit); cells_out$unit <- as.character(cells_out$unit)
  }
  if (!is.null(pairs)) {
    if (!all(c("unit", "cell") %in% names(pairs))) cli::cli_abort("{.arg pairs} needs columns {.field unit} and {.field cell}.")
    bad <- setdiff(as.character(pairs$cell), cells_out$unit); if (length(bad)) cli::cli_abort("Unknown cell{?s} in {.arg pairs}: {.val {bad}}.")
    idx <- match(as.character(pairs$unit), list_out$unit)
    if (anyNA(idx)) cli::cli_abort("Unknown list unit{?s} in {.arg pairs}: {.val {pairs$unit[is.na(idx)]}}.")
    cell[idx] <- as.character(pairs$cell)
  }
  list_out$cell <- cell
  list_out$domain <- ifelse(is.na(cell), "b", "ab")
  counts <- table(factor(cell, levels = cells_out$unit))
  cells_out$listed <- as.integer(counts[cells_out$unit])
  cells_out$listed_units <- lapply(cells_out$unit, function(u) list_out$unit[!is.na(cell) & cell == u])
  list(list = list_out, cells = cells_out)
}

#' Read the cells of an area frame exported by the areaframe service
#'
#' Reads a frame of grid cells as exported by the area-frame service (a
#' Parquet file with `cell_index`, `centroid_lon`, `centroid_lat`, `area_m2`
#' and the geometry as WKB, plus any stratum or covariate columns) or any
#' spatial file `sf` can read (GeoPackage, GeoJSON, shapefile), and returns
#' the plain frame [select_units()] works on: `unit`, `lat`, `lon`, `area`
#' in square kilometres (also used as `size`), and the other columns. With
#' `sf = TRUE` the geometries are kept and an `sf` object is returned instead
#' (see [as_frame()] and [as_sf()]).
#'
#' @param path Path to the file.
#' @param sf Return an `sf` object with the geometries.
#' @return A tibble, or an `sf` object.
#' @export
#' @examples
#' \dontrun{
#' cells <- read_areaframe("cells.parquet")
#' s <- select_units(cells, n = 300, size = "area", strata = "stratum")
#' }
read_areaframe <- function(path, sf = FALSE) {
  if (!file.exists(path)) cli::cli_abort("File {.path {path}} not found.")
  ext <- tolower(tools::file_ext(path))
  if (ext == "parquet") {
    rlang::check_installed("arrow", reason = "to read Parquet files.")
    d <- tibble::as_tibble(arrow::read_parquet(path))
    for (col in c("cell_index", "centroid_lon", "centroid_lat")) if (!col %in% names(d)) cli::cli_abort("The file needs a column {.field {col}}.")
    out <- tibble::tibble(unit = paste0("c", d$cell_index), lat = as.numeric(d$centroid_lat), lon = as.numeric(d$centroid_lon))
    if ("area_m2" %in% names(d)) out$area <- as.numeric(d$area_m2) / 1e6
    extra <- setdiff(names(d), c("cell_index", "centroid_lon", "centroid_lat", "area_m2", "geom_wkb"))
    for (col in extra) out[[col]] <- d[[col]]
    if (sf) {
      rlang::check_installed("sf", reason = "to keep the geometries.")
      if (!"geom_wkb" %in% names(d)) cli::cli_abort("The file has no {.field geom_wkb} column.")
      geom <- sf::st_as_sfc(structure(lapply(d$geom_wkb, function(g) as.raw(g)), class = "WKB"), EWKB = FALSE, crs = 4326)
      return(sf::st_sf(out, geometry = geom))
    }
    out
  } else {
    rlang::check_installed("sf", reason = "to read spatial files.")
    x <- sf::st_read(path, quiet = TRUE)
    if (sf) return(x)
    as_frame(x)
  }
}
