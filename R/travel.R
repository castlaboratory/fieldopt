# Travel matrices and the cost model ------------------------------------------

#' Travel matrix between the units of a frame
#'
#' Builds the dense matrix of travel distances or times between all units,
#' depot included, in one of three ways:
#'
#' * from coordinates, as straight-line distances: great-circle (`"haversine"`,
#'   kilometres) with `lat`/`lon`, or Euclidean with planar `x`/`y`. A
#'   `detour` factor (the ratio of road to straight-line distance, typically
#'   1.2 to 1.4 on rural road networks) turns them into a planning estimate of
#'   road distances when no network is available;
#' * from a road network, with `method = "osrm"`: durations (minutes) or
#'   distances (kilometres) from an OSRM server through the `osrm` package,
#'   requested in blocks so that the server's table limit is respected (the
#'   public demo server allows 10 000 cells per request, and is meant for
#'   small tests only: run your own server for a frame);
#' * from a matrix computed elsewhere (`matrix`), with the coordinates used
#'   only for names and plots.
#'
#' Road matrices need not be symmetric (one-way streets, different durations
#' by direction); the routing solver prices every leg in the direction
#' travelled.
#'
#' @param coords Data frame or matrix with two coordinate columns: `lat`, `lon`
#'   (degrees) for `"haversine"` and `"osrm"`, or `x`, `y` (planar, any unit)
#'   for `"euclidean"`. Row names, or a column `unit`, name the units.
#' @param method `"haversine"`, `"euclidean"` or `"osrm"`.
#' @param matrix Optional square numeric matrix of travel costs already
#'   computed; when given, `method` is ignored except for the coordinate
#'   columns it implies.
#' @param unit Label of the travel unit (`"km"`, `"min"`, ...), kept for
#'   reports; set automatically unless a matrix is supplied.
#' @param detour Multiplier applied to straight-line distances (`>= 1`).
#'   Ignored, with a warning, for `"osrm"` and supplied matrices.
#' @param measure For `"osrm"`: `"duration"` (minutes) or `"distance"`
#'   (kilometres on the network).
#' @param server,profile For `"osrm"`: the base URL of the routing server and
#'   the profile (`"car"`, `"bike"`, `"foot"`); default to the `osrm` package
#'   options.
#' @param block For `"osrm"`: number of origins and of destinations per
#'   request (`block^2` cells each).
#' @return A square numeric matrix of class `fieldopt_matrix` with unit names
#'   as dimnames and attributes `coords`, `method`, `unit`, `detour` and, for
#'   `"osrm"`, `snap` (the distance in kilometres from each unit to the point
#'   of the network it was snapped to: large values flag units far from any
#'   road).
#' @export
#' @examples
#' segments <- data.frame(unit = c("depot", "s1", "s2", "s3"),
#'                        lat = c(-8.05, -8.10, -8.00, -8.12),
#'                        lon = c(-34.90, -34.95, -34.85, -34.80))
#' travel_matrix(segments)
#' travel_matrix(segments, detour = 1.3)
#' \dontrun{
#' # road durations from the OSRM demo server (small frames only)
#' travel_matrix(segments, method = "osrm", measure = "duration")
#' }
travel_matrix <- function(coords, method = c("haversine", "euclidean", "osrm"), matrix = NULL, unit = NULL,
                          detour = 1, measure = c("duration", "distance"),
                          server = getOption("osrm.server"), profile = getOption("osrm.profile"), block = 100) {
  method <- rlang::arg_match(method)
  measure <- rlang::arg_match(measure)
  coords <- as.data.frame(coords)
  names_ <- if ("unit" %in% names(coords)) as.character(coords$unit) else if (!is.null(rownames(coords)) && !all(rownames(coords) == seq_len(nrow(coords)))) rownames(coords) else paste0("u", seq_len(nrow(coords)))
  if (anyDuplicated(names_)) cli::cli_abort("Unit names must be distinct.")
  cols <- if (method == "euclidean") c("x", "y") else c("lat", "lon")
  if (!all(cols %in% names(coords))) cli::cli_abort("{.arg coords} needs columns {.field {cols}} for method {.val {method}}.")
  a <- as.numeric(coords[[cols[1]]]); b <- as.numeric(coords[[cols[2]]])
  if (anyNA(a) || anyNA(b)) cli::cli_abort("Coordinates must not be missing.")
  if (!is.numeric(detour) || length(detour) != 1L || is.na(detour) || detour < 1) cli::cli_abort("{.arg detour} must be a single number of at least 1.")
  n <- length(a)
  snap <- NULL
  if (!is.null(matrix)) {
    if (!is.matrix(matrix) || !is.numeric(matrix) || nrow(matrix) != n || ncol(matrix) != n) {
      cli::cli_abort("{.arg matrix} must be a numeric {n} x {n} matrix matching {.arg coords}.")
    }
    if (anyNA(matrix) || any(matrix < 0)) cli::cli_abort("{.arg matrix} must be non-negative without missing values.")
    if (detour != 1) cli::cli_warn("{.arg detour} is ignored when {.arg matrix} is supplied.")
    m <- unname(matrix); detour <- 1
    if (is.null(unit)) unit <- "travel"
    method <- "supplied"
  } else if (method == "osrm") {
    if (detour != 1) cli::cli_warn("{.arg detour} is ignored with {.val osrm}: the network distance is used as is.")
    detour <- 1
    res <- osrm_table(lon = b, lat = a, names = names_, measure = measure, server = server, profile = profile, block = block)
    m <- res$matrix; snap <- res$snap
    if (is.null(unit)) unit <- if (measure == "duration") "min" else "km"
  } else {
    m <- matrix(travel_matrix_rs(a, b, method), n, n, byrow = TRUE) * detour
    if (is.null(unit)) unit <- if (method == "haversine") "km" else "distance"
  }
  dimnames(m) <- list(names_, names_)
  structure(m, class = c("fieldopt_matrix", "matrix", "array"),
            coords = data.frame(unit = names_, a = a, b = b, stringsAsFactors = FALSE),
            method = method, unit = unit, detour = detour, snap = snap)
}

# Travel matrix from an OSRM server, requested in blocks of `block` origins by
# `block` destinations. Returns the n x n matrix and the snapping distances.
osrm_table <- function(lon, lat, names, measure, server, profile, block) {
  rlang::check_installed("osrm", reason = "to compute travel matrices on a road network.")
  if (!is.numeric(block) || length(block) != 1L || block < 1) cli::cli_abort("{.arg block} must be a positive number.")
  n <- length(lon)
  pts <- data.frame(lon = lon, lat = lat); rownames(pts) <- names
  m <- matrix(NA_real_, n, n); snap <- rep(NA_real_, n)
  starts <- seq(1, n, by = block)
  for (i0 in starts) {
    ii <- i0:min(i0 + block - 1, n)
    for (j0 in starts) {
      jj <- j0:min(j0 + block - 1, n)
      res <- osrm::osrmTable(src = pts[ii, , drop = FALSE], dst = pts[jj, , drop = FALSE], measure = measure,
                             osrm.server = server, osrm.profile = profile)
      part <- if (measure == "duration") res$durations else res$distances
      if (is.null(part) || !all(dim(part) == c(length(ii), length(jj)))) cli::cli_abort("The OSRM server returned a table of unexpected shape.")
      m[ii, jj] <- unname(as.matrix(part))
      if (j0 == 1 && !is.null(res$sources) && "snap" %in% names(res$sources)) snap[ii] <- res$sources$snap
    }
  }
  if (anyNA(m)) {
    bad <- names[apply(is.na(m), 1, any)]
    cli::cli_abort(c("The network has no route for some pairs of units.", i = "Units involved: {.val {bad}}. Check that they lie near a road the profile can use."))
  }
  m[m < 0] <- 0
  diag(m) <- 0
  list(matrix = m, snap = snap)
}

#' @export
print.fieldopt_matrix <- function(x, ...) {
  det <- attr(x, "detour"); sn <- attr(x, "snap")
  cli::cli_text("Travel matrix: {nrow(x)} unit{?s}, {attr(x, 'method')}{if (!is.null(det) && det != 1) paste0(' x ', det) else ''} ({attr(x, 'unit')}); mean off-diagonal {signif(mean(x[row(x) != col(x)]), 4)}{if (!is.null(sn) && !all(is.na(sn))) paste0('; largest snapping distance ', signif(max(sn, na.rm = TRUE), 3), ' km') else ''}.")
  invisible(x)
}

#' Field cost model
#'
#' Converts a routing solution and a sample into money (or time): a cost per
#' unit of travel, a fixed cost per route (a team-day: allowances, vehicle,
#' lodging), a fixed cost per visited unit (access, setup) and a cost per
#' interview.
#'
#' @param per_travel Cost per unit of the travel matrix (per km, per minute).
#' @param per_route Fixed cost of one route (one team for one day).
#' @param per_unit Fixed cost of visiting one unit.
#' @param per_interview Cost of one interview.
#' @param interviews_per_unit Expected interviews per visited unit: a single
#'   number, a vector with one value per row of the travel matrix (depot
#'   included, in the same order), or a function of the row indices of the
#'   visited units.
#' @param currency Label for reports.
#' @return An object of class `field_cost_model`.
#' @export
#' @examples
#' field_cost_model(per_travel = 1.2, per_unit = 50, per_interview = 15, interviews_per_unit = 8)
field_cost_model <- function(per_travel = 1, per_unit = 0, per_interview = 0, interviews_per_unit = 1, per_route = 0,
                             currency = "cost") {
  for (v in c("per_travel", "per_unit", "per_interview", "per_route")) {
    val <- get(v)
    if (!is.numeric(val) || length(val) != 1L || is.na(val) || val < 0) cli::cli_abort("{.arg {v}} must be a single non-negative number.")
  }
  if (!is.function(interviews_per_unit) && (!is.numeric(interviews_per_unit) || any(interviews_per_unit < 0))) {
    cli::cli_abort("{.arg interviews_per_unit} must be non-negative numbers or a function.")
  }
  structure(list(per_travel = per_travel, per_route = per_route, per_unit = per_unit, per_interview = per_interview,
                 interviews_per_unit = interviews_per_unit, currency = currency), class = "field_cost_model")
}

#' @export
print.field_cost_model <- function(x, ...) {
  cli::cli_text("Field cost model ({x$currency}): {x$per_travel} per travel unit, {x$per_route} per route, {x$per_unit} per visited unit, {x$per_interview} per interview.")
  invisible(x)
}

# Cost of a set of routes and visited units under a model.
cost_of <- function(model, travel_total, units_visited, unit_index = NULL, n_routes = 1) {
  interviews <- if (is.function(model$interviews_per_unit)) sum(model$interviews_per_unit(unit_index)) else if (length(model$interviews_per_unit) == 1L) model$interviews_per_unit * units_visited else sum(model$interviews_per_unit[unit_index])
  per_route <- if (is.null(model$per_route)) 0 else model$per_route
  parts <- c(travel = model$per_travel * travel_total, routes = per_route * n_routes, units = model$per_unit * units_visited,
             interviews = model$per_interview * interviews)
  c(parts, total = sum(parts))
}
