# Allocations with a routed field cost ---------------------------------------

#' Field cost per sampled unit at a given sample size, from the routing
#'
#' Selects `n` units from the frame `n_rep` times, routes each sample from
#' the depot, prices it with the cost model and returns the mean cost per
#' sampled unit. This is the planning value of the cost of a primary unit
#' (`c1` in [two_stage_allocation()]) or of an area-frame unit (`cost_a` in
#' [dual_frame_allocation()]); it depends on `n` because a larger sample is
#' denser and cheaper to reach per unit.
#'
#' @inheritParams cost_variance_frontier
#' @param n Sample size (a number, or a vector named by stratum).
#' @return A one-row tibble: `n`, `cost_per_unit`, `travel_per_unit`,
#'   `cost_mean`, `routes_mean`, `n_rep`.
#' @export
#' @examples
#' set.seed(1)
#' frame <- data.frame(unit = c("depot", paste0("s", 1:40)),
#'                     x = c(5, runif(40, 0, 10)), y = c(5, runif(40, 0, 10)))
#' model <- field_cost_model(per_travel = 2, per_unit = 30, per_interview = 10,
#'                           interviews_per_unit = 4)
#' routed_unit_cost(frame, "depot", model, n = 12, method = "euclidean", n_rep = 3,
#'                  iterations = 20)
routed_unit_cost <- function(frame, depot, cost_model, n, size = NULL, strata = NULL,
                             selection = c("lpm", "systematic", "srs"), replicates = 1, matrix = NULL,
                             method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                             n_rep = 10, iterations = 100, seed = 1) {
  f <- cost_variance_frontier(frame, depot, cost_model, n_grid = list(n), size = size, strata = strata,
                              selection = selection, replicates = replicates, matrix = matrix, method = method,
                              max_length = max_length, max_stops = max_stops, n_rep = n_rep,
                              iterations = iterations, seed = seed)
  tibble::tibble(n = f$n, cost_per_unit = f$cost_per_unit, travel_per_unit = f$travel_mean / f$n,
                 cost_mean = f$cost_mean, routes_mean = f$routes_mean, n_rep = n_rep)
}

#' Two-stage allocation with the primary-unit cost taken from the routing
#'
#' [two_stage_allocation()] needs the cost `c1` of visiting a primary unit,
#' which depends on how many units are visited. This function iterates: it
#' allocates with a starting `c1`, routes a sample of the allocated size to
#' measure the cost per unit, allocates again, and stops when the number of
#' primary units no longer changes (or after `max_iter` rounds). The cost
#' model's per-interview cost is `c2`; the travel and per-visit costs make
#' `c1`.
#'
#' @inheritParams cost_variance_frontier
#' @inheritParams two_stage_allocation
#' @param m_secondary Secondary units per primary unit in the population.
#' @param c1_start Starting value of the cost per primary unit.
#' @param max_iter Maximum number of rounds.
#' @param n_rep Routed samples per round.
#' @return The final `fieldopt_two_stage` allocation with an extra element
#'   `history` (a tibble with one row per round: `round`, `c1`, `n`, `m`,
#'   `cost`, `variance_total`) and `c1`.
#' @export
#' @examples
#' set.seed(2)
#' cells <- expand.grid(x = 1:15, y = 1:15); cells$unit <- paste0("c", seq_len(nrow(cells)))
#' frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
#' model <- field_cost_model(per_travel = 3, per_unit = 40, per_interview = 20,
#'                           interviews_per_unit = 1)
#' two_stage_design(frame, "depot", model, m_secondary = 12, s2_between = 9, s2_within = 40,
#'                  target_cv = 0.05, mean = 10, method = "euclidean", n_rep = 2,
#'                  iterations = 20)
two_stage_design <- function(frame, depot, cost_model, m_secondary, s2_between, s2_within,
                             target_variance = NULL, target_cv = NULL, budget = NULL, mean = NULL,
                             c1_start = NULL, max_iter = 6, size = NULL, strata = NULL,
                             selection = c("lpm", "systematic", "srs"), matrix = NULL,
                             method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                             n_rep = 5, iterations = 100, seed = 1) {
  if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
  frame <- tibble::as_tibble(frame)
  if (!"unit" %in% names(frame) || !depot %in% frame$unit) cli::cli_abort("{.arg frame} needs a column {.field unit} that contains {.val {depot}}.")
  n_primary <- nrow(frame) - 1L
  c2 <- cost_model$per_interview
  if (is.null(c1_start)) {
    method <- rlang::arg_match(method)
    if (is.null(matrix)) matrix <- travel_matrix(frame, method = method)
    m <- unclass(matrix); d <- which(rownames(m) == depot)
    c1_start <- cost_model$per_unit + cost_model$per_travel * stats::median(m[d, -d])
  }
  history <- list(); c1 <- c1_start; n_prev <- NA_integer_; alloc <- NULL; converged <- FALSE
  for (it in seq_len(max_iter)) {
    alloc <- two_stage_allocation(n_primary, m_secondary, s2_between, s2_within, c1 = c1, c2 = c2,
                                  target_variance = target_variance, target_cv = target_cv, budget = budget, mean = mean)
    history[[it]] <- tibble::tibble(round = it, c1 = c1, n = alloc$n, m = alloc$m, cost = alloc$cost, variance_total = alloc$variance_total)
    if (identical(alloc$n, n_prev)) { converged <- TRUE; break }
    n_prev <- alloc$n
    # unit cost of the frame at n (the cost model is applied with the allocated interviews per cell)
    cm <- field_cost_model(per_travel = cost_model$per_travel, per_unit = cost_model$per_unit, per_route = cost_model$per_route,
                           per_interview = 0, interviews_per_unit = 1, currency = cost_model$currency)
    ru <- routed_unit_cost(frame, depot, cm, n = alloc$n, size = size, strata = strata, selection = selection,
                           matrix = matrix, method = method, max_length = max_length, max_stops = max_stops,
                           n_rep = n_rep, iterations = iterations, seed = seed + it)
    c1 <- ru$cost_per_unit
  }
  alloc$c1 <- c1; alloc$history <- do.call(rbind, history); alloc$converged <- converged
  alloc
}

#' Dual-frame allocation with the area-frame cost taken from the routing
#'
#' [dual_frame_allocation()] needs the cost per unit of the area frame, which
#' depends on how many area units are visited. This function iterates between
#' the allocation and the routing of a sample of `n_a` area units until
#' `n_a` stabilises. The cost model prices the area units; `cost_b` is the
#' list cost per unit.
#'
#' @inheritParams cost_variance_frontier
#' @inheritParams dual_frame_allocation
#' @param cost_b Cost per sampled unit of the list frame.
#' @param interviews_per_unit Expected interviews per visited area unit (for
#'   the cost model; the model's own value is used when `NULL`).
#' @param cost_a_start Starting value of the cost per area unit.
#' @param max_iter Maximum number of rounds.
#' @param n_rep Routed samples per round.
#' @return The final `fieldopt_dual_frame` allocation with `history` (one row
#'   per round: `round`, `cost_a`, `n_a`, `n_b`, `theta`, `cost`, `variance`).
#' @export
#' @examples
#' set.seed(3)
#' cells <- expand.grid(x = 1:15, y = 1:15); cells$unit <- paste0("c", seq_len(nrow(cells)))
#' frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
#' model <- field_cost_model(per_travel = 3, per_unit = 40, per_interview = 20,
#'                           interviews_per_unit = 3)
#' domains <- data.frame(domain = c("a", "ab", "b"), size = c(600, 80, 20),
#'                       mean = c(6, 30, 45), sd = c(5, 20, 35))
#' dual_frame_design(frame, "depot", model, domains, cost_b = 45, deff_a = 1.5,
#'                   target_cv = 0.05, method = "euclidean", n_rep = 2, iterations = 20)
dual_frame_design <- function(frame, depot, cost_model, domains, cost_b, deff_a = 1, deff_b = 1, theta = NULL,
                              target_variance = NULL, target_cv = NULL, budget = NULL,
                              interviews_per_unit = NULL, cost_a_start = NULL, max_iter = 6,
                              size = NULL, strata = NULL, selection = c("lpm", "systematic", "srs"), matrix = NULL,
                              method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                              n_rep = 5, iterations = 100, seed = 1) {
  if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
  frame <- tibble::as_tibble(frame)
  if (!"unit" %in% names(frame) || !depot %in% frame$unit) cli::cli_abort("{.arg frame} needs a column {.field unit} that contains {.val {depot}}.")
  if (!is.null(interviews_per_unit)) cost_model$interviews_per_unit <- interviews_per_unit
  if (is.null(cost_a_start)) {
    method <- rlang::arg_match(method)
    if (is.null(matrix)) matrix <- travel_matrix(frame, method = method)
    m <- unclass(matrix); d <- which(rownames(m) == depot)
    ipu <- if (is.function(cost_model$interviews_per_unit)) 1 else mean(cost_model$interviews_per_unit)
    cost_a_start <- cost_model$per_unit + cost_model$per_interview * ipu + cost_model$per_travel * stats::median(m[d, -d])
  }
  history <- list(); cost_a <- cost_a_start; n_prev <- NA_integer_; alloc <- NULL; converged <- FALSE
  for (it in seq_len(max_iter)) {
    alloc <- dual_frame_allocation(domains, cost_a = cost_a, cost_b = cost_b, deff_a = deff_a, deff_b = deff_b, theta = theta,
                                   target_variance = target_variance, target_cv = target_cv, budget = budget)
    history[[it]] <- tibble::tibble(round = it, cost_a = cost_a, n_a = alloc$n_a, n_b = alloc$n_b, theta = alloc$theta, cost = alloc$cost, variance = alloc$variance)
    if (identical(alloc$n_a, n_prev)) { converged <- TRUE; break }
    n_prev <- alloc$n_a
    n_units <- min(alloc$n_a, nrow(frame) - 1L)
    ru <- routed_unit_cost(frame, depot, cost_model, n = n_units, size = size, strata = strata, selection = selection,
                           matrix = matrix, method = method, max_length = max_length, max_stops = max_stops,
                           n_rep = n_rep, iterations = iterations, seed = seed + it)
    cost_a <- ru$cost_per_unit
  }
  alloc$history <- do.call(rbind, history); alloc$converged <- converged
  alloc
}
