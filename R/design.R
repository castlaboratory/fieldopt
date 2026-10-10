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
#' frame <- data.frame(
#'   unit = c("depot", paste0("s", 1:40)),
#'   x = c(5, runif(40, 0, 10)), y = c(5, runif(40, 0, 10))
#' )
#' model <- field_cost_model(
#'   per_travel = 2, per_unit = 30, per_interview = 10,
#'   interviews_per_unit = 4
#' )
#' routed_unit_cost(frame, "depot", model,
#'   n = 12, method = "euclidean", n_rep = 3,
#'   iterations = 20
#' )
routed_unit_cost <- function(frame, depot, cost_model, n, size = NULL, strata = NULL,
                             selection = c("lpm", "systematic", "srs"), replicates = 1, matrix = NULL,
                             method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                             n_rep = 10, iterations = 100, seed = 1) {
  f <- cost_variance_frontier(frame, depot, cost_model,
    n_grid = list(n), size = size, strata = strata,
    selection = selection, replicates = replicates, matrix = matrix, method = method,
    max_length = max_length, max_stops = max_stops, n_rep = n_rep,
    iterations = iterations, seed = seed
  )
  tibble::tibble(
    n = f$n, cost_per_unit = f$cost_per_unit, travel_per_unit = f$travel_mean / f$n,
    cost_mean = f$cost_mean, routes_mean = f$routes_mean, n_rep = n_rep
  )
}

# Routed cost curve ---------------------------------------------------------

# Expected routed cost G(n) of visiting n units, measured by routing at a few
# sample sizes and fitted as G(n) = c0 + a n + b sqrt(n) (Beardwood-Halton-
# Hammersley: the travel of a tour through n scattered points grows like
# sqrt(n); fixed costs per unit and per route add the linear term). The fit is
# monotone and concave, so its derivative, the marginal cost, is positive and
# falls with n.
fit_cost_curve <- function(points) {
  pts <- points[order(points$n), ]
  n <- pts$n
  g <- pts$cost_mean
  if (length(n) < 3L) {
    a <- if (length(n) == 2L) (g[2] - g[1]) / (n[2] - n[1]) else g[1] / n[1]
    coef <- c(c0 = g[1] - max(a, 0) * n[1], a = max(a, 0), b = 0)
  } else {
    X <- cbind(1, n, sqrt(n))
    coef <- stats::setNames(qr.solve(X, g), c("c0", "a", "b"))
    if (coef[["b"]] < 0) coef <- c(stats::setNames(qr.solve(X[, 1:2], g), c("c0", "a")), b = 0)
    if (coef[["a"]] < 0) coef <- c(stats::setNames(qr.solve(X[, c(1, 3)], g), c("c0", "b")), a = 0)[c("c0", "a", "b")]
  }
  coef
}
curve_G <- function(coef, n) coef[["c0"]] + coef[["a"]] * n + coef[["b"]] * sqrt(n)
curve_Gprime <- function(coef, n) coef[["a"]] + coef[["b"]] / (2 * sqrt(n))

# Route new sample sizes around n and return the measured points.
grow_cost_curve <- function(points, n, n_max, measure) {
  cand <- unique(pmin(n_max, pmax(2L, round(n * c(0.6, 0.8, 1, 1.25, 1.6)))))
  have <- if (is.null(points)) integer() else points$n
  new <- setdiff(cand, have)
  if (!length(new)) {
    return(points)
  }
  rbind(points, measure(new))
}
covered <- function(points, n) !is.null(points) && nrow(points) >= 3L && n >= min(points$n) && n <= max(points$n)

# Largest linearised budget whose allocation really costs at most `budget`.
# `alloc_at(b)` allocates with the linear (marginal) cost and budget b and
# returns NULL when b is too small; `real_cost(a)` prices it on the curve.
fit_budget <- function(budget, alloc_at, real_cost) {
  lo <- 0
  hi <- budget
  best <- NULL
  for (k in 1:40) {
    mid <- (lo + hi) / 2
    a <- alloc_at(mid)
    if (!is.null(a) && real_cost(a) <= budget) {
      best <- a
      lo <- mid
    } else {
      hi <- mid
    }
  }
  if (is.null(best)) {
    a <- alloc_at(budget)
    if (is.null(a)) cli::cli_abort("The budget does not cover the smallest feasible design.")
    best <- a
  }
  best
}

#' Two-stage allocation with the primary-unit cost taken from the routing
#'
#' [two_stage_allocation()] needs the cost `c1` of visiting a primary unit,
#' which is not a constant: a tour shares its travel among the units it
#' visits, so the routed cost `G(n)` of visiting `n` units grows like
#' `c0 + a n + b sqrt(n)` (Beardwood, Halton and Hammersley). This function
#' measures `G(n)` by routing samples at a few sizes around the current
#' allocation, fits that curve, and re-allocates with the **marginal** cost
#' `G'(n)` in place of `c1`; with a non-linear cost the optimal number of
#' secondary units is Cochran's formula with the marginal, not the average,
#' cost per primary unit, as in Hansen, Hurwitz and Madow's travel-cost model.
#' Under a budget the number of primary units then
#' comes from the fitted curve, so the design spends the budget at its real
#' routed cost. It stops when `n` no longer changes (or after `max_iter`
#' rounds; a two-cycle stops with the better of the two designs).
#'
#' Using the average cost `G(n)/n` instead takes too few primary units: in
#' the package's experiments the marginal rule was within 0.2 percent of the
#' cost of the best design found by exhaustive search, the average rule up to
#' 3 percent above it, and a constant `c1` guessed from depot distances 7 to
#' 19 percent above.
#'
#' @inheritParams cost_variance_frontier
#' @inheritParams two_stage_allocation
#' @param m_secondary Secondary units per primary unit in the population.
#' @param c1_start Starting value of the cost per primary unit (default: the
#'   per-visit cost plus the travel cost of the median trip from the depot).
#' @param max_iter Maximum number of rounds.
#' @param n_rep Routed samples per sample size of the cost curve.
#' @return The final `fieldopt_two_stage` allocation, with `cost` the routed
#'   cost `G(n) + c2 n m`, and the extra elements `c1` (the marginal cost
#'   used), `c1_average` (`G(n)/n`), `cost_curve` (the routed points: `n`,
#'   `cost_mean`, `cost_sd`), `cost_coef` (`c0`, `a`, `b`), `history` (one
#'   row per round: `round`, `c1`, `c1_average`, `n`, `m`, `cost`,
#'   `variance_total`) and `converged`.
#' @references Hansen, M. H., Hurwitz, W. N. and Madow, W. G. (1953). *Sample
#'   Survey Methods and Theory*, Vol. II, Section 6.11 (two-stage optimum with a
#'   travel cost proportional to `sqrt(n)`). Cochran, W. G. (1977). *Sampling
#'   Techniques*, 3rd ed., Section 10.6. Beardwood, J., Halton, J. H. and Hammersley, J. M. (1959). The
#'   shortest path through many points. *Proc. Cambridge Phil. Soc.*, 55,
#'   299-327.
#' @export
#' @examples
#' set.seed(2)
#' cells <- expand.grid(x = 1:15, y = 1:15)
#' cells$unit <- paste0("c", seq_len(nrow(cells)))
#' frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
#' model <- field_cost_model(
#'   per_travel = 3, per_unit = 40, per_interview = 20,
#'   interviews_per_unit = 1
#' )
#' two_stage_design(frame, "depot", model,
#'   m_secondary = 12, s2_between = 9, s2_within = 40,
#'   target_cv = 0.05, mean = 10, method = "euclidean", n_rep = 2,
#'   iterations = 20
#' )
two_stage_design <- function(frame, depot, cost_model, m_secondary, s2_between, s2_within,
                             target_variance = NULL, target_cv = NULL, budget = NULL, mean = NULL,
                             c1_start = NULL, max_iter = 8, size = NULL, strata = NULL,
                             selection = c("lpm", "systematic", "srs"), matrix = NULL,
                             method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                             n_rep = 5, iterations = 100, seed = 1) {
  if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
  frame <- tibble::as_tibble(frame)
  if (!"unit" %in% names(frame) || !depot %in% frame$unit) cli::cli_abort("{.arg frame} needs a column {.field unit} that contains {.val {depot}}.")
  selection <- rlang::arg_match(selection)
  method <- rlang::arg_match(method)
  n_primary <- nrow(frame) - 1L
  c2 <- cost_model$per_interview
  if (is.null(matrix)) matrix <- travel_matrix(frame, method = method)
  if (is.null(c1_start)) {
    m <- unclass(matrix)
    d <- which(rownames(m) == depot)
    c1_start <- cost_model$per_unit + cost_model$per_travel * stats::median(m[d, -d])
  }
  # the primary-unit part of the cost: travel, routes and visits, no interviews
  cm <- field_cost_model(
    per_travel = cost_model$per_travel, per_unit = cost_model$per_unit, per_route = cost_model$per_route,
    per_interview = 0, interviews_per_unit = 1, currency = cost_model$currency
  )
  measure <- function(ns) {
    f <- cost_variance_frontier(frame, depot, cm,
      n_grid = as.list(ns), size = size, strata = strata, selection = selection,
      matrix = matrix, max_length = max_length, max_stops = max_stops,
      n_rep = n_rep, iterations = iterations, seed = seed
    )
    tibble::tibble(n = as.integer(f$n), cost_mean = f$cost_mean, cost_sd = f$cost_sd)
  }
  allocate <- function(c1, b = budget) {
    two_stage_allocation(n_primary, m_secondary, s2_between, s2_within,
      c1 = c1, c2 = c2,
      target_variance = target_variance, target_cv = target_cv, budget = b, mean = mean
    )
  }
  points <- NULL
  coef <- NULL
  c1 <- c1_start
  history <- list()
  seen <- list()
  converged <- FALSE
  alloc <- NULL
  for (it in seq_len(max_iter)) {
    if (is.null(budget) || is.null(coef)) {
      alloc <- allocate(c1)
    } else {
      alloc <- fit_budget(budget,
        alloc_at = function(b) tryCatch(allocate(c1, b), error = function(e) NULL),
        real_cost = function(a) curve_G(coef, a$n) + c2 * a$n * a$m
      )
    }
    n <- alloc$n
    if (!covered(points, n)) {
      points <- grow_cost_curve(points, n, n_primary, measure)
      coef <- fit_cost_curve(points)
    }
    real <- curve_G(coef, n) + c2 * n * alloc$m
    history[[it]] <- tibble::tibble(
      round = it, c1 = c1, c1_average = curve_G(coef, n) / n, n = n, m = alloc$m,
      cost = real, variance_total = alloc$variance_total
    )
    seen[[it]] <- alloc
    key <- vapply(history, function(h) h$n * 1e4 + h$m, numeric(1))
    if (it > 1 && key[it] == key[it - 1]) {
      converged <- TRUE
      break
    }
    if (it > 2 && key[it] == key[it - 2]) {
      # two-cycle: keep the better of the two designs
      h <- do.call(rbind, history[(it - 1):it])
      pick <- if (is.null(budget)) which.min(h$cost) else which.min(h$variance_total)
      alloc <- seen[[it - 2 + pick]]
      converged <- TRUE
      break
    }
    c1 <- max(curve_Gprime(coef, n), 1e-9 * curve_G(coef, n) / n)
  }
  n <- alloc$n
  alloc$cost <- curve_G(coef, n) + c2 * n * alloc$m
  if (!is.null(budget)) {
    alloc$mode <- "budget"
  }
  alloc$c1 <- curve_Gprime(coef, n)
  alloc$c1_average <- curve_G(coef, n) / n
  alloc$cost_curve <- points[order(points$n), ]
  alloc$cost_coef <- coef
  alloc$history <- do.call(rbind, history)
  alloc$converged <- converged
  alloc
}

#' Dual-frame allocation with the area-frame cost taken from the routing
#'
#' [dual_frame_allocation()] needs the cost per unit of the area frame, which
#' is not a constant: the routed cost `G(n_a)` of visiting `n_a` area units
#' grows like `c0 + a n_a + b sqrt(n_a)`. As [two_stage_design()], this
#' function measures that curve by routing samples at a few sizes, fits it,
#' and re-allocates with the **marginal** cost `G'(n_a)` as `cost_a`, which
#' sets the split between the frames and `theta`; under a budget the sample
#' sizes then come from the fitted curve, keeping that split, so the design
#' spends the budget at its real routed cost. The cost model prices the area
#' units (visits, interviews and travel); `cost_b` is the list cost per unit.
#'
#' @inheritParams cost_variance_frontier
#' @inheritParams dual_frame_allocation
#' @param cost_b Cost per sampled unit of the list frame.
#' @param interviews_per_unit Expected interviews per visited area unit (for
#'   the cost model; the model's own value is used when `NULL`).
#' @param cost_a_start Starting value of the cost per area unit.
#' @param max_iter Maximum number of rounds.
#' @param n_rep Routed samples per sample size of the cost curve.
#' @return The final `fieldopt_dual_frame` allocation, with `cost` the routed
#'   cost `G(n_a) + cost_b n_b`, `cost_a` the marginal cost used,
#'   `cost_a_average` (`G(n_a)/n_a`), `cost_curve`, `cost_coef`, `history`
#'   (one row per round: `round`, `cost_a`, `cost_a_average`, `n_a`, `n_b`,
#'   `theta`, `cost`, `variance`) and `converged`.
#' @export
#' @examples
#' set.seed(3)
#' cells <- expand.grid(x = 1:15, y = 1:15)
#' cells$unit <- paste0("c", seq_len(nrow(cells)))
#' frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
#' model <- field_cost_model(
#'   per_travel = 3, per_unit = 40, per_interview = 20,
#'   interviews_per_unit = 3
#' )
#' domains <- data.frame(
#'   domain = c("a", "ab", "b"), size = c(600, 80, 20),
#'   mean = c(6, 30, 45), sd = c(5, 20, 35)
#' )
#' dual_frame_design(frame, "depot", model, domains,
#'   cost_b = 45, deff_a = 1.5,
#'   target_cv = 0.05, method = "euclidean", n_rep = 2, iterations = 20
#' )
dual_frame_design <- function(frame, depot, cost_model, domains, cost_b, deff_a = 1, deff_b = 1, theta = NULL,
                              target_variance = NULL, target_cv = NULL, budget = NULL,
                              interviews_per_unit = NULL, cost_a_start = NULL, max_iter = 8,
                              size = NULL, strata = NULL, selection = c("lpm", "systematic", "srs"), matrix = NULL,
                              method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                              n_rep = 5, iterations = 100, seed = 1) {
  if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
  frame <- tibble::as_tibble(frame)
  if (!"unit" %in% names(frame) || !depot %in% frame$unit) cli::cli_abort("{.arg frame} needs a column {.field unit} that contains {.val {depot}}.")
  selection <- rlang::arg_match(selection)
  method <- rlang::arg_match(method)
  if (!is.null(interviews_per_unit)) cost_model$interviews_per_unit <- interviews_per_unit
  n_units <- nrow(frame) - 1L
  if (is.null(matrix)) matrix <- travel_matrix(frame, method = method)
  if (is.null(cost_a_start)) {
    m <- unclass(matrix)
    d <- which(rownames(m) == depot)
    ipu <- if (is.function(cost_model$interviews_per_unit)) 1 else mean(cost_model$interviews_per_unit)
    cost_a_start <- cost_model$per_unit + cost_model$per_interview * ipu + cost_model$per_travel * stats::median(m[d, -d])
  }
  measure <- function(ns) {
    f <- cost_variance_frontier(frame, depot, cost_model,
      n_grid = as.list(ns), size = size, strata = strata, selection = selection,
      matrix = matrix, max_length = max_length, max_stops = max_stops,
      n_rep = n_rep, iterations = iterations, seed = seed
    )
    tibble::tibble(n = as.integer(f$n), cost_mean = f$cost_mean, cost_sd = f$cost_sd)
  }
  allocate <- function(ca, b = budget) {
    dual_frame_allocation(domains,
      cost_a = ca, cost_b = cost_b, deff_a = deff_a, deff_b = deff_b, theta = theta,
      target_variance = target_variance, target_cv = target_cv, budget = b
    )
  }
  points <- NULL
  coef <- NULL
  cost_a <- cost_a_start
  history <- list()
  seen <- list()
  converged <- FALSE
  alloc <- NULL
  for (it in seq_len(max_iter)) {
    if (is.null(budget) || is.null(coef)) {
      alloc <- allocate(cost_a)
    } else {
      alloc <- fit_budget(budget,
        alloc_at = function(b) tryCatch(allocate(cost_a, b), error = function(e) NULL),
        real_cost = function(a) curve_G(coef, min(a$n_a, n_units)) + cost_b * a$n_b
      )
    }
    n_a <- min(alloc$n_a, n_units)
    if (!covered(points, n_a)) {
      points <- grow_cost_curve(points, n_a, n_units, measure)
      coef <- fit_cost_curve(points)
    }
    history[[it]] <- tibble::tibble(
      round = it, cost_a = cost_a, cost_a_average = curve_G(coef, n_a) / n_a, n_a = alloc$n_a,
      n_b = alloc$n_b, theta = alloc$theta, cost = curve_G(coef, n_a) + cost_b * alloc$n_b, variance = alloc$variance
    )
    seen[[it]] <- alloc
    key <- vapply(history, function(h) h$n_a * 1e6 + h$n_b, numeric(1))
    if (it > 1 && key[it] == key[it - 1]) {
      converged <- TRUE
      break
    }
    if (it > 2 && key[it] == key[it - 2]) {
      h <- do.call(rbind, history[(it - 1):it])
      pick <- if (is.null(budget)) which.min(h$cost) else which.min(h$variance)
      alloc <- seen[[it - 2 + pick]]
      converged <- TRUE
      break
    }
    cost_a <- max(curve_Gprime(coef, n_a), 1e-9 * curve_G(coef, n_a) / n_a)
  }
  n_a <- min(alloc$n_a, n_units)
  alloc$cost <- curve_G(coef, n_a) + cost_b * alloc$n_b
  if (!is.null(budget)) {
    alloc$target <- budget
  }
  alloc$cost_a <- curve_Gprime(coef, n_a)
  alloc$cost_a_average <- curve_G(coef, n_a) / n_a
  alloc$cost_curve <- points[order(points$n), ]
  alloc$cost_coef <- coef
  alloc$history <- do.call(rbind, history)
  alloc$converged <- converged
  alloc
}
