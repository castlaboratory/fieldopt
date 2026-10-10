# The vrpr engine ---------------------------------------------------------------

# Solve a routing problem with the vrpr package (PyVRP's C++ core). Several
# bases are allowed: `bases` names the depots and `vehicles` gives, per base,
# the number of routes that may leave it. Measures are scaled to integers as
# PyVRP requires. Returns the routes (a list of character vectors of unit
# names) and the base of each route.
route_with_vrpr <- function(matrix, units, bases, vehicles, max_length, max_stops, service, demand, capacity,
                            per_route = 0, per_travel = 1, time_limit = 5, seed = 1) {
  rlang::check_installed("vrpr", reason = "to use the vrpr routing engine.")
  nm <- rownames(matrix)
  m <- unclass(matrix)
  co <- attr(matrix, "coords")
  if (is.finite(max_stops) && is.finite(capacity)) {
    cli::cli_abort(c("The {.val vrpr} engine takes one of {.arg max_stops} and {.arg capacity}, not both.",
      i = "Express the stop limit as a demand of 1 per unit and a capacity equal to the maximum stops."
    ))
  }
  if (is.finite(max_stops)) {
    demand <- rep(1, length(nm))
    capacity <- max_stops
  }
  big <- max(m, if (is.finite(max_length)) max_length else 0, service)
  scale <- if (big > 0) 10^max(0, 6 - ceiling(log10(big))) else 1 # about six significant digits, within int32
  nodes <- c(bases, units)
  ui <- match(units, nm)
  bi <- match(bases, nm)
  idx <- c(bi, ui)
  model <- vrpr::vrp_model()
  for (b in bi) model <- vrpr::add_depot(model, x = co$a[b], y = co$b[b])
  clients <- tibble::tibble(x = co$a[ui], y = co$b[ui], demand = demand[ui], service = round(service[ui] * scale))
  model <- vrpr::add_clients(model, clients)
  fixed <- if (per_travel > 0) round(per_route / per_travel * scale) else 0
  for (k in seq_along(bases)) {
    model <- vrpr::add_vehicle_type(model,
      num_available = as.integer(if (vehicles[k] < 0) length(units) else vehicles[k]), capacity = if (is.finite(capacity)) capacity else sum(demand[ui]) + 1,
      fixed_cost = fixed, max_duration = if (is.finite(max_length)) round(max_length * scale) else Inf, depot = k
    )
  }
  dist <- round(m[idx, idx, drop = FALSE] * scale)
  dimnames(dist) <- NULL
  pd <- vrpr::vrp_problem_data(model, distance = dist, duration = dist)
  res <- vrpr::vrp_solve(pd, stop = vrpr::max_runtime(time_limit), seed = as.integer(seed), display = FALSE)
  rt <- vrpr::routes(res)
  rt <- rt[rt$activity == "client", ]
  if (length(unique(rt$client)) != length(units)) cli::cli_abort("The vrpr engine left units unplanned: raise the number of routes available or relax the limits.")
  ids <- sort(unique(rt$route_id))
  routes <- lapply(ids, function(i) units[rt$client[rt$route_id == i][order(rt$position[rt$route_id == i])]])
  base_of <- vapply(ids, function(i) bases[rt$depot[rt$route_id == i][1]], character(1))
  list(routes = routes, base = base_of, cost = vrpr::cost(res) / scale, scale = scale)
}
