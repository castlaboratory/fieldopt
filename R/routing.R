# Routing of the field work ---------------------------------------------------

#' Route the field work
#'
#' Finds low-cost routes from a depot through the selected units with GRASP
#' (randomised greedy construction, 2-opt and Or-opt local search, optimal
#' split of the tour into routes under the limits). One route when the limits
#' allow it, several otherwise (one per team or per day). The solution is a
#' heuristic; the gap to a lower bound is reported.
#'
#' @param matrix A [travel_matrix()].
#' @param units Names (or indices in the matrix) of the units to visit.
#' @param depot Name (or index) of the depot.
#' @param max_length Maximum travel per route, depot to depot; `Inf` for none.
#' @param max_stops Maximum units per route; `Inf` for none.
#' @param iterations GRASP iterations.
#' @param alpha Greediness of the construction in `[0, 1]` (0 greedy, 1 random).
#' @param seed Seed of the solver.
#' @param cost_model Optional [field_cost_model()] to price the solution.
#' @return An object of class `fieldopt_routes`: `routes` (a tibble with
#'   columns `route`, `stop`, `unit`), `lengths`, `total`, `lower_bound`,
#'   `gap`, `best_iteration`, `cost` (when a model is given) and the inputs.
#' @export
#' @examples
#' set.seed(1)
#' pts <- data.frame(unit = c("depot", paste0("s", 1:12)),
#'                   x = c(0, runif(12, 0, 10)), y = c(0, runif(12, 0, 10)))
#' m <- travel_matrix(pts, method = "euclidean")
#' r <- route_fieldwork(m, units = paste0("s", 1:12), depot = "depot", max_stops = 5, iterations = 50)
#' r
route_fieldwork <- function(matrix, units, depot, max_length = Inf, max_stops = Inf, iterations = 200,
                            alpha = 0.3, seed = 1, cost_model = NULL) {
  if (!inherits(matrix, "fieldopt_matrix")) cli::cli_abort("{.arg matrix} must come from {.fn travel_matrix}.")
  nm <- rownames(matrix)
  idx <- function(v, what) {
    if (is.character(v)) { bad <- setdiff(v, nm); if (length(bad)) cli::cli_abort("Unknown {what} {.val {bad}}."); match(v, nm) }
    else { v <- as.integer(v); if (any(is.na(v) | v < 1 | v > length(nm))) cli::cli_abort("{what} indices out of range."); v }
  }
  u <- idx(units, "units"); d <- idx(depot, "depot")
  if (length(d) != 1L) cli::cli_abort("{.arg depot} must be a single unit.")
  if (anyDuplicated(u)) cli::cli_abort("{.arg units} must be distinct.")
  if (d %in% u) cli::cli_abort("The depot cannot be among the units to visit.")
  for (v in c("iterations", "alpha", "seed")) if (!is.numeric(get(v)) || length(get(v)) != 1L) cli::cli_abort("{.arg {v}} must be a single number.")
  if (is.finite(max_length)) {
    far <- nm[u][2 * unclass(matrix)[d, u] > max_length]
    if (length(far)) cli::cli_abort(c("A route from {.val {nm[d]}} to {.val {far}} and back exceeds {.arg max_length} = {max_length}.",
                                      i = "Raise {.arg max_length}, move the depot or drop {cli::qty(length(far))}{?this unit/these units}."))
  }
  if (is.finite(max_stops) && max_stops < 1) cli::cli_abort("{.arg max_stops} must be at least 1.")
  res <- route_rs(as.numeric(t(unclass(matrix))), nrow(matrix), d - 1L, u - 1L, as.numeric(max_length), as.numeric(max_stops),
                  as.integer(iterations), alpha, seed)
  routes <- do.call(rbind, lapply(seq_along(res$routes), function(k) {
    r <- res$routes[[k]] + 1L
    tibble::tibble(route = k, stop = seq_along(r), unit = nm[r])
  }))
  out <- list(routes = routes, lengths = res$lengths, total = res$total, lower_bound = res$lower_bound,
              gap = if (res$lower_bound > 0) (res$total - res$lower_bound) / res$lower_bound else NA_real_,
              best_iteration = res$best_iteration,
              n_routes = length(res$routes), depot = nm[d], units = nm[u],
              limits = c(max_length = max_length, max_stops = max_stops),
              options = list(iterations = iterations, alpha = alpha, seed = seed),
              travel_unit = attr(matrix, "unit"), coords = attr(matrix, "coords"), method = attr(matrix, "method"))
  if (!is.null(cost_model)) {
    if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
    out$cost <- cost_of(cost_model, res$total, length(u), u)
    out$cost_model <- cost_model
  }
  structure(out, class = "fieldopt_routes")
}

#' @export
print.fieldopt_routes <- function(x, ...) {
  cli::cli_h1("Field routes")
  cli::cli_text("{x$n_routes} route{?s} from {.val {x$depot}} through {length(x$units)} unit{?s}: total travel {signif(x$total, 4)} {x$travel_unit} (lower bound {signif(x$lower_bound, 4)}{if (is.na(x$gap)) '' else paste0(', gap ', signif(100 * x$gap, 3), '%')}).")
  for (k in seq_len(x$n_routes)) {
    r <- x$routes$unit[x$routes$route == k]
    cli::cli_text("Route {k} ({signif(x$lengths[k], 4)}): {paste(r, collapse = ' > ')}")
  }
  if (!is.null(x$cost)) cli::cli_text("Cost ({x$cost_model$currency}): travel {signif(x$cost[['travel']], 4)} + units {signif(x$cost[['units']], 4)} + interviews {signif(x$cost[['interviews']], 4)} = {signif(x$cost[['total']], 4)}.")
  invisible(x)
}

#' Plot the routes
#'
#' @param object A `fieldopt_routes`.
#' @param ... Unused.
#' @return A ggplot with the units, the depot and the routes in the coordinate
#'   space of the travel matrix.
#' @exportS3Method ggplot2::autoplot fieldopt_routes
#' @examples
#' set.seed(1)
#' pts <- data.frame(unit = c("depot", paste0("s", 1:12)),
#'                   x = c(0, runif(12, 0, 10)), y = c(0, runif(12, 0, 10)))
#' r <- route_fieldwork(travel_matrix(pts, method = "euclidean"), paste0("s", 1:12),
#'                      depot = "depot", max_stops = 5, iterations = 50)
#' autoplot(r)
autoplot.fieldopt_routes <- function(object, ...) {
  co <- object$coords
  pos <- function(u) co[match(u, co$unit), c("a", "b")]
  segs <- do.call(rbind, lapply(seq_len(object$n_routes), function(k) {
    r <- c(object$depot, object$routes$unit[object$routes$route == k], object$depot)
    p <- pos(r)
    data.frame(route = factor(k), x = p$a[-nrow(p)], y = p$b[-nrow(p)], xend = p$a[-1], yend = p$b[-1])
  }))
  pts <- co[co$unit %in% object$units, ]
  dep <- co[co$unit == object$depot, ]
  geo <- identical(object$method, "haversine")
  if (geo) {  # coordinates are (lat, lon): plot longitude on x
    segs <- data.frame(route = segs$route, x = segs$y, y = segs$x, xend = segs$yend, yend = segs$xend)
    pts <- data.frame(a = pts$b, b = pts$a); dep <- data.frame(a = dep$b, b = dep$a)
  }
  ggplot2::ggplot() +
    ggplot2::geom_segment(data = segs, ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend, colour = .data$route), linewidth = 0.6) +
    ggplot2::geom_point(data = pts, ggplot2::aes(x = .data$a, y = .data$b), size = 2) +
    ggplot2::geom_point(data = dep, ggplot2::aes(x = .data$a, y = .data$b), shape = 17, size = 3.5, colour = "#B4432B") +
    ggplot2::labs(x = if (geo) "longitude" else "x", y = if (geo) "latitude" else "y", colour = "route") +
    (if (geo) ggplot2::coord_quickmap() else ggplot2::coord_equal()) +
    ggplot2::theme_minimal() + ggplot2::theme(legend.position = "bottom")
}
