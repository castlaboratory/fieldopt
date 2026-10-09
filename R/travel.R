# Travel matrices and the cost model ------------------------------------------

#' Travel matrix between the units of a frame
#'
#' Builds the dense matrix of travel distances (or times) between all units,
#' depot included, from coordinates, or wraps a matrix computed elsewhere, for
#' example on a road network with OSRM. Distances from coordinates are a first
#' approximation; a network matrix is the honest input when it is available.
#'
#' @param coords Data frame or matrix with two coordinate columns: `lat`, `lon`
#'   (degrees) for `method = "haversine"`, or `x`, `y` (planar, any unit) for
#'   `method = "euclidean"`. Row names, or a column `unit`, name the units.
#' @param method `"haversine"` (great-circle distance in kilometres) or
#'   `"euclidean"`.
#' @param matrix Optional square numeric matrix of travel costs already
#'   computed; when given, `coords` is only used for names and plotting.
#' @param unit Label of the travel unit (`"km"`, `"min"`, ...), kept for
#'   reports.
#' @return A square numeric matrix of class `fieldopt_matrix` with unit names
#'   as dimnames and attributes `coords`, `method` and `unit`.
#' @export
#' @examples
#' segments <- data.frame(unit = c("depot", "s1", "s2", "s3"),
#'                        lat = c(-8.05, -8.10, -8.00, -8.12), lon = c(-34.90, -34.95, -34.85, -34.80))
#' travel_matrix(segments)
travel_matrix <- function(coords, method = c("haversine", "euclidean"), matrix = NULL, unit = NULL) {
  method <- rlang::arg_match(method)
  coords <- as.data.frame(coords)
  names_ <- if ("unit" %in% names(coords)) as.character(coords$unit) else if (!is.null(rownames(coords)) && !all(rownames(coords) == seq_len(nrow(coords)))) rownames(coords) else paste0("u", seq_len(nrow(coords)))
  if (anyDuplicated(names_)) cli::cli_abort("Unit names must be distinct.")
  cols <- if (method == "haversine") c("lat", "lon") else c("x", "y")
  if (!all(cols %in% names(coords))) cli::cli_abort("{.arg coords} needs columns {.field {cols}} for method {.val {method}}.")
  a <- as.numeric(coords[[cols[1]]]); b <- as.numeric(coords[[cols[2]]])
  if (anyNA(a) || anyNA(b)) cli::cli_abort("Coordinates must not be missing.")
  n <- length(a)
  if (is.null(matrix)) {
    m <- matrix(travel_matrix_rs(a, b, method), n, n, byrow = TRUE)
    if (is.null(unit)) unit <- if (method == "haversine") "km" else "distance"
  } else {
    if (!is.matrix(matrix) || !is.numeric(matrix) || nrow(matrix) != n || ncol(matrix) != n) {
      cli::cli_abort("{.arg matrix} must be a numeric {n} x {n} matrix matching {.arg coords}.")
    }
    if (anyNA(matrix) || any(matrix < 0)) cli::cli_abort("{.arg matrix} must be non-negative without missing values.")
    m <- unname(matrix)
    if (is.null(unit)) unit <- "travel"
  }
  dimnames(m) <- list(names_, names_)
  structure(m, class = c("fieldopt_matrix", "matrix", "array"),
            coords = data.frame(unit = names_, a = a, b = b, stringsAsFactors = FALSE),
            method = if (is.null(matrix)) method else "supplied", unit = unit)
}

#' @export
print.fieldopt_matrix <- function(x, ...) {
  cli::cli_text("Travel matrix: {nrow(x)} unit{?s}, {attr(x, 'method')} ({attr(x, 'unit')}); mean off-diagonal {signif(mean(x[row(x) != col(x)]), 4)}.")
  invisible(x)
}

#' Field cost model
#'
#' Converts a routing solution and a sample into money (or time): a cost per
#' unit of travel, a fixed cost per visited unit (access, setup) and a cost per
#' interview.
#'
#' @param per_travel Cost per unit of the travel matrix (per km, per minute).
#' @param per_unit Fixed cost of visiting one unit.
#' @param per_interview Cost of one interview.
#' @param interviews_per_unit Expected interviews per visited unit (a single
#'   number or a function of the unit index).
#' @param currency Label for reports.
#' @return An object of class `field_cost_model`.
#' @export
#' @examples
#' field_cost_model(per_travel = 1.2, per_unit = 50, per_interview = 15, interviews_per_unit = 8)
field_cost_model <- function(per_travel = 1, per_unit = 0, per_interview = 0, interviews_per_unit = 1, currency = "cost") {
  for (v in c("per_travel", "per_unit", "per_interview")) {
    val <- get(v)
    if (!is.numeric(val) || length(val) != 1L || is.na(val) || val < 0) cli::cli_abort("{.arg {v}} must be a single non-negative number.")
  }
  if (!is.function(interviews_per_unit) && (!is.numeric(interviews_per_unit) || any(interviews_per_unit < 0))) {
    cli::cli_abort("{.arg interviews_per_unit} must be non-negative numbers or a function.")
  }
  structure(list(per_travel = per_travel, per_unit = per_unit, per_interview = per_interview,
                 interviews_per_unit = interviews_per_unit, currency = currency), class = "field_cost_model")
}

#' @export
print.field_cost_model <- function(x, ...) {
  cli::cli_text("Field cost model ({x$currency}): {x$per_travel} per travel unit, {x$per_unit} per visited unit, {x$per_interview} per interview.")
  invisible(x)
}

# Cost of a set of routes and visited units under a model.
cost_of <- function(model, travel_total, units_visited, unit_index = NULL) {
  interviews <- if (is.function(model$interviews_per_unit)) sum(model$interviews_per_unit(unit_index)) else if (length(model$interviews_per_unit) == 1L) model$interviews_per_unit * units_visited else sum(model$interviews_per_unit[unit_index])
  c(travel = model$per_travel * travel_total, units = model$per_unit * units_visited,
    interviews = model$per_interview * interviews, total = model$per_travel * travel_total + model$per_unit * units_visited + model$per_interview * interviews)
}
