# Routing of the field work ---------------------------------------------------

#' Route the field work
#'
#' Finds low-cost routes from a depot through the selected units: one route
#' when the limits allow it, several otherwise (one per team or per day).
#' Instances of up to 13 units are solved exactly (dynamic programming over
#' subsets). Larger ones go to a hybrid genetic search (Vidal 2022): a
#' population of giant tours, order crossover, the optimal split of Prins
#' (2004) under the limits, and a local search with granular neighbourhoods
#' (2-opt, Or-opt, relocate, swap, 2-opt*). The `gap` to a lower bound is
#' reported: the Held-Karp bound for a single tour on a symmetric matrix
#' (usually within a few percent of the optimum), a loose bound otherwise;
#' `optimal` says when the solution is proven optimal.
#'
#' @param matrix A [travel_matrix()].
#' @param units Names (or indices in the matrix) of the units to visit.
#' @param depot Name (or index) of the depot.
#' @param max_length Maximum length of a route, depot to depot: travel plus
#'   the service time of its units when `service_time` is given; `Inf` for
#'   none.
#' @param max_stops Maximum units per route; `Inf` for none.
#' @param service_time Time spent at each unit (interviews, measurements), in
#'   the unit of the travel matrix: a single number, or a vector named by
#'   unit. It counts towards `max_length` and is reported in `durations`.
#' @param demand Load each unit adds to its route (interviews to make,
#'   samples to carry): a single number or a vector named by unit.
#' @param capacity Maximum load of a route; `Inf` for none.
#' @param iterations Offspring of the genetic search (ignored when the
#'   instance is solved exactly or when `time_limit` is given).
#' @param time_limit Seconds of search instead of `iterations` (`NULL` for
#'   none); the only stopping rule of the `"vrpr"` engine (default 5 s).
#' @param engine `"fieldopt"` (the built-in solver) or `"vrpr"`, the PyVRP
#'   solver through the `vrpr` package (in Suggests), with the same inputs and
#'   outputs, except that it takes one of `max_stops` and `capacity` and gives
#'   no lower bound. Both engines charge a cost model's `per_route` inside the
#'   objective (as `per_route / per_travel` travel units per route), so the
#'   number of routes is itself optimised when a cost model is given.
#' @param alpha Greediness of the constructions that seed the population, in
#'   `[0, 1]` (0 greedy, 1 random).
#' @param seed Seed of the solver.
#' @param cost_model Optional [field_cost_model()] to price the solution.
#' @return An object of class `fieldopt_routes`: `routes` (a tibble with
#'   columns `route`, `stop`, `unit`), `lengths` (travel per route),
#'   `durations` (travel plus service), `loads`, `total`, `lower_bound`,
#'   `gap`, `optimal`, `best_iteration`, `cost` (when a model is given), the
#'   inputs and the travel matrix.
#' @references Vidal, T. (2022). Hybrid genetic search for the CVRP:
#'   open-source implementation and SWAP* neighborhood. *Computers &
#'   Operations Research*, 140, 105643. Prins, C. (2004). A simple and
#'   effective evolutionary algorithm for the vehicle routing problem.
#'   *Computers & Operations Research*, 31, 1985-2002. Held, M. and Karp,
#'   R. M. (1971). The traveling-salesman problem and minimum spanning trees:
#'   part II. *Mathematical Programming*, 1, 6-25.
#' @export
#' @examples
#' set.seed(1)
#' pts <- data.frame(unit = c("depot", paste0("s", 1:12)),
#'                   x = c(0, runif(12, 0, 10)), y = c(0, runif(12, 0, 10)))
#' m <- travel_matrix(pts, method = "euclidean")
#' r <- route_fieldwork(m, units = paste0("s", 1:12), depot = "depot", max_stops = 5,
#'                      iterations = 50)
#' r
route_fieldwork <- function(matrix, units, depot, max_length = Inf, max_stops = Inf, service_time = 0,
                            demand = 0, capacity = Inf, iterations = 200, time_limit = NULL, alpha = 0.3, seed = 1,
                            cost_model = NULL, engine = c("fieldopt", "vrpr")) {
  engine <- rlang::arg_match(engine)
  if (!is.null(time_limit) && (!is.numeric(time_limit) || length(time_limit) != 1L || is.na(time_limit) || time_limit <= 0)) cli::cli_abort("{.arg time_limit} must be a positive number of seconds.")
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
  for (v in c("iterations", "alpha")) if (!is.numeric(get(v)) || length(get(v)) != 1L) cli::cli_abort("{.arg {v}} must be a single number.")
  check_seed(seed)
  service <- service_vector(service_time, nm)
  dem <- service_vector(demand, nm, arg = "demand")
  if (!is.numeric(capacity) || length(capacity) != 1L || is.na(capacity) || capacity < 0) cli::cli_abort("{.arg capacity} must be a single non-negative number.")
  heavy <- nm[u][dem[u] > capacity]
  if (length(heavy)) cli::cli_abort("The demand of {.val {heavy}} exceeds {.arg capacity} = {capacity}.")
  if (is.finite(max_length)) {
    far <- nm[u][unclass(matrix)[d, u] + unclass(matrix)[u, d] + service[u] > max_length]
    if (length(far)) cli::cli_abort(c("A route from {.val {nm[d]}} to {.val {far}} and back exceeds {.arg max_length} = {max_length}.",
                                      i = "Raise {.arg max_length}, move the depot or drop {cli::qty(length(far))}{?this unit/these units}."))
  }
  if (is.finite(max_stops) && max_stops < 1) cli::cli_abort("{.arg max_stops} must be at least 1.")
  if (engine == "vrpr") {
    if (!is.null(cost_model) && !inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
    v <- route_with_vrpr(matrix, units = nm[u], bases = nm[d], vehicles = length(u), max_length = max_length, max_stops = max_stops,
                         service = service, demand = dem, capacity = capacity,
                         per_route = if (is.null(cost_model)) 0 else cost_model$per_route, per_travel = if (is.null(cost_model)) 1 else cost_model$per_travel,
                         time_limit = if (is.null(time_limit)) 5 else time_limit, seed = seed)
    mm <- unclass(matrix)
    res <- list(routes = lapply(v$routes, function(r) match(r, nm) - 1L))
    res$lengths <- vapply(v$routes, function(r) mm[nm[d], r[1]] + sum(mm[cbind(r[-length(r)], r[-1])]) + mm[r[length(r)], nm[d]], numeric(1))
    res$durations <- res$lengths + vapply(v$routes, function(r) sum(service[match(r, nm)]), numeric(1))
    res$loads <- vapply(v$routes, function(r) sum(dem[match(r, nm)]), numeric(1))
    res$total <- sum(res$lengths); res$lower_bound <- NA_real_; res$optimal <- FALSE; res$best_iteration <- NA_integer_
  } else {
    fixed <- if (!is.null(cost_model) && cost_model$per_route > 0 && cost_model$per_travel > 0) cost_model$per_route / cost_model$per_travel else 0
    res <- route_rs(as.numeric(t(unclass(matrix))), nrow(matrix), d - 1L, -1, fixed, u - 1L, service, dem, as.numeric(max_length),
                    as.numeric(max_stops), as.numeric(capacity), as.integer(iterations), if (is.null(time_limit)) Inf else as.numeric(time_limit), alpha, seed)
  }
  routes <- do.call(rbind, lapply(seq_along(res$routes), function(k) {
    r <- res$routes[[k]] + 1L
    tibble::tibble(route = k, stop = seq_along(r), unit = nm[r])
  }))
  out <- list(routes = routes, lengths = res$lengths, durations = res$durations, loads = res$loads, total = res$total,
              lower_bound = res$lower_bound, optimal = res$optimal,
              gap = if (!is.na(res$lower_bound) && res$lower_bound > 0) (res$total - res$lower_bound) / res$lower_bound else NA_real_,
              best_iteration = res$best_iteration,
              n_routes = length(res$routes), depot = nm[d], units = nm[u],
              limits = c(max_length = max_length, max_stops = max_stops, capacity = capacity), service_time = service, demand = dem,
              options = list(iterations = iterations, time_limit = time_limit, alpha = alpha, seed = seed), engine = engine,
              travel_unit = attr(matrix, "unit"), coords = attr(matrix, "coords"), method = attr(matrix, "method"),
              matrix = matrix)
  if (!is.null(cost_model)) {
    if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
    out$cost <- cost_of(cost_model, res$total, length(u), u, n_routes = length(res$routes))
    out$cost_model <- cost_model
  }
  structure(out, class = "fieldopt_routes")
}

# Service time as a vector over the rows of the matrix (names `nm`).
service_vector <- function(service_time, nm, arg = "service_time") {
  if (!is.numeric(service_time) || anyNA(service_time) || any(service_time < 0)) cli::cli_abort("{.arg {arg}} must be non-negative numbers.")
  if (length(service_time) == 1L) return(rep(as.numeric(service_time), length(nm)))
  if (!is.null(names(service_time))) {
    out <- rep(0, length(nm)); hit <- match(names(service_time), nm)
    bad <- names(service_time)[is.na(hit)]
    if (length(bad)) cli::cli_abort("Unknown {cli::qty(length(bad))}unit{?s} in {.arg {arg}}: {.val {bad}}.")
    out[hit] <- as.numeric(service_time); return(out)
  }
  if (length(service_time) != length(nm)) cli::cli_abort("{.arg {arg}} must be a single number, a vector named by unit, or one value per row of the matrix.")
  as.numeric(service_time)
}

#' @export
print.fieldopt_routes <- function(x, ...) {
  cli::cli_h1("Field routes")
  tail <- if (isTRUE(x$optimal)) " (proven optimal)" else if (identical(x$engine, "vrpr")) " (vrpr engine)" else paste0(" (lower bound ", signif(x$lower_bound, 4), if (is.na(x$gap)) "" else paste0(", gap ", signif(100 * x$gap, 3), "%"), ")")
  cli::cli_text("{x$n_routes} route{?s} from {.val {x$depot}} through {length(x$units)} unit{?s}: total travel {signif(x$total, 4)} {x$travel_unit}{tail}.")
  served <- any(x$service_time > 0)
  for (k in seq_len(x$n_routes)) {
    r <- x$routes$unit[x$routes$route == k]
    cli::cli_text("Route {k} ({signif(x$lengths[k], 4)}{if (served) paste0(', duration ', signif(x$durations[k], 4)) else ''}): {paste(r, collapse = ' > ')}")
  }
  if (!is.null(x$cost)) cli::cli_text("Cost ({x$cost_model$currency}): travel {signif(x$cost[['travel']], 4)} + routes {signif(x$cost[['routes']], 4)} + units {signif(x$cost[['units']], 4)} + interviews {signif(x$cost[['interviews']], 4)} = {signif(x$cost[['total']], 4)}.")
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

# Build a `fieldopt_routes` object from routes given as character vectors of
# unit names (used by the schedule and by the vrpr engine).
routes_object <- function(matrix, route_list, depot, service, demand, limits, cost_model = NULL, engine = "fieldopt",
                          lower_bound = NA_real_, optimal = FALSE, best_iteration = NA_integer_) {
  nm <- rownames(matrix); mm <- unclass(matrix)
  lengths <- vapply(route_list, function(r) mm[depot, r[1]] + sum(mm[cbind(r[-length(r)], r[-1])]) + mm[r[length(r)], depot], numeric(1))
  durations <- lengths + vapply(route_list, function(r) sum(service[match(r, nm)]), numeric(1))
  loads <- vapply(route_list, function(r) sum(demand[match(r, nm)]), numeric(1))
  units <- unlist(route_list); u <- match(units, nm)
  routes <- do.call(rbind, lapply(seq_along(route_list), function(k) tibble::tibble(route = k, stop = seq_along(route_list[[k]]), unit = route_list[[k]])))
  total <- sum(lengths)
  out <- list(routes = routes, lengths = lengths, durations = durations, loads = loads, total = total, lower_bound = lower_bound,
              optimal = optimal, gap = if (!is.na(lower_bound) && lower_bound > 0) (total - lower_bound) / lower_bound else NA_real_,
              best_iteration = best_iteration, n_routes = length(route_list), depot = depot, units = units, limits = limits,
              service_time = service, demand = demand, options = list(), engine = engine,
              travel_unit = attr(matrix, "unit"), coords = attr(matrix, "coords"), method = attr(matrix, "method"), matrix = matrix)
  if (!is.null(cost_model)) {
    out$cost <- cost_of(cost_model, total, length(u), u, n_routes = length(route_list))
    out$cost_model <- cost_model
  }
  structure(out, class = "fieldopt_routes")
}
