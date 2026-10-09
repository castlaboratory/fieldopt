# tidy() and glance() for the allocations --------------------------------------

#' Tidy and glance methods for allocations
#'
#' `tidy()` returns one row per stratum, frame or stage; `glance()` one row
#' with the totals.
#'
#' @param x A `fieldopt_allocation`, `fieldopt_dual_frame` or
#'   `fieldopt_two_stage`.
#' @param ... Unused.
#' @return A tibble.
#' @name allocation-methods
#' @examples
#' strata <- data.frame(stratum = c("list", "area"), size = c(2000, 800),
#'                      sd = c(12, 30), cost = c(40, 180))
#' a <- frame_allocation(strata, budget = 20000)
#' tidy(a); glance(a)
NULL

#' @rdname allocation-methods
#' @method tidy fieldopt_allocation
#' @export
tidy.fieldopt_allocation <- function(x, ...) {
  d <- tibble::as_tibble(unclass(x))
  d$cost_total <- d$cost * d$n
  d$variance <- d$size^2 * d$sd^2 / d$n * (1 - d$n / d$size)
  d[, c("stratum", "size", "sd", "cost", "n", "cost_total", "variance")]
}

#' @rdname allocation-methods
#' @method glance fieldopt_allocation
#' @export
glance.fieldopt_allocation <- function(x, ...) {
  tibble::tibble(mode = attr(x, "mode"), target = attr(x, "target"), n = sum(x$n), cost = attr(x, "cost"),
                 variance = attr(x, "variance"), bounded = attr(x, "bounded"))
}

#' @rdname allocation-methods
#' @method tidy fieldopt_dual_frame
#' @export
tidy.fieldopt_dual_frame <- function(x, ...) {
  tibble::tibble(frame = c("A", "B"), n = c(x$n_a, x$n_b), cost_per_unit = c(x$cost_a, x$cost_b),
                 cost = c(x$cost_a * x$n_a, x$cost_b * x$n_b), deff = c(x$deff_a, x$deff_b),
                 variance = c(x$variance_a, x$variance_b), overlap_units = c(x$overlap_a, x$overlap_b),
                 weight_on_overlap = c(x$theta, 1 - x$theta))
}

#' @rdname allocation-methods
#' @method glance fieldopt_dual_frame
#' @export
glance.fieldopt_dual_frame <- function(x, ...) {
  tibble::tibble(mode = x$mode, target = x$target, n_a = x$n_a, n_b = x$n_b, theta = x$theta, cost = x$cost,
                 variance = x$variance, se = x$se, cv = x$cv, total = x$total, bounded = x$bounded)
}

#' @rdname allocation-methods
#' @method tidy fieldopt_two_stage
#' @export
tidy.fieldopt_two_stage <- function(x, ...) {
  i <- x$inputs
  tibble::tibble(stage = c("primary", "secondary"), units = c(x$n, x$n * x$m), per_unit = c(x$n, x$m),
                 cost_per_unit = c(i$c1, i$c2), cost = c(i$c1 * x$n, i$c2 * x$n * x$m),
                 variance_component = c(i$s2_between, i$s2_within))
}

#' @rdname allocation-methods
#' @method glance fieldopt_two_stage
#' @export
glance.fieldopt_two_stage <- function(x, ...) {
  tibble::tibble(mode = x$mode, n = x$n, m = x$m, m_optimal = x$m_optimal, cost = x$cost,
                 variance_total = x$variance_total, se_total = x$se_total, cv = x$cv, bounded = x$bounded)
}

#' Tidy and glance methods for routes and frontiers
#'
#' `tidy()` of a `fieldopt_routes` returns one row per stop (`route`, `stop`,
#' `unit`, and `leg`, the travel from the previous stop or the depot);
#' `glance()` one row with the total travel, the lower bound, the gap, the
#' number of routes and the cost when a model was given. `glance()` of a
#' `fieldopt_frontier` returns one row with the range of sample sizes, costs
#' and variances covered, the selection method and the replicates.
#'
#' @param x A `fieldopt_routes` or `fieldopt_frontier`.
#' @param ... Unused.
#' @return A tibble.
#' @name routes-methods
#' @examples
#' set.seed(1)
#' pts <- data.frame(unit = c("depot", paste0("s", 1:8)), x = c(0, runif(8)), y = c(0, runif(8)))
#' r <- route_fieldwork(travel_matrix(pts, method = "euclidean"), paste0("s", 1:8), "depot",
#'                      max_stops = 4, iterations = 20)
#' tidy(r); glance(r)
NULL

#' @rdname routes-methods
#' @method tidy fieldopt_routes
#' @export
tidy.fieldopt_routes <- function(x, ...) {
  d <- x$routes
  m <- unclass(x$matrix)
  prev <- ifelse(d$stop == 1, x$depot, c(NA_character_, d$unit[-nrow(d)]))
  d$leg <- m[cbind(match(prev, rownames(m)), match(d$unit, rownames(m)))]
  d
}

#' @rdname routes-methods
#' @method glance fieldopt_routes
#' @export
glance.fieldopt_routes <- function(x, ...) {
  out <- tibble::tibble(n_units = length(x$units), n_routes = x$n_routes, total = x$total, lower_bound = x$lower_bound,
                        gap = x$gap, longest_route = max(x$lengths), travel_unit = x$travel_unit)
  if (!is.null(x$cost)) out$cost <- x$cost[["total"]]
  out
}

#' @rdname routes-methods
#' @method glance fieldopt_frontier
#' @export
glance.fieldopt_frontier <- function(x, ...) {
  d <- tibble::as_tibble(unclass(x))
  out <- tibble::tibble(n_grid = nrow(d), n_min = min(d$n), n_max = max(d$n), cost_min = min(d$cost_mean), cost_max = max(d$cost_mean))
  if ("variance_mean" %in% names(d)) { out$variance_min <- min(d$variance_mean); out$variance_max <- max(d$variance_mean) }
  out$selection <- attr(x, "selection"); out$replicates <- attr(x, "replicates"); out$n_rep <- d$n_rep[1]
  out
}
