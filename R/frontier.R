# The cost-variance frontier of a design --------------------------------------

#' Cost-variance frontier of a design by simulation
#'
#' For each sample size in `n_grid`, draws `n_rep` spatially balanced samples
#' from the frame, routes the field work from the depot, prices it with the
#' cost model and, when a study variable is given, estimates the variance of
#' the total. The result is the trade-off a survey planner faces: how much the
#' field work costs and how precise the estimate is at each sample size.
#'
#' @param frame Data frame of units as in [select_units()], including the depot
#'   row named in `depot`.
#' @param depot Name of the depot unit in `frame$unit`.
#' @param cost_model A [field_cost_model()].
#' @param n_grid Sample sizes to evaluate: a numeric vector of total sizes
#'   (allocated across strata as in [select_units()]), or a list of vectors
#'   named by stratum, one allocation per grid point.
#' @param y Optional column of the study variable for the whole frame (a
#'   planning value); when given, the variance of the estimated total is
#'   computed with [design_variance()] on each simulated sample.
#' @param size Optional size column for probability-proportional-to-size
#'   selection.
#' @param strata Optional stratum column, passed to [select_units()].
#' @param selection Selection method of [select_units()]: `"lpm"`,
#'   `"systematic"` or `"srs"`.
#' @param replicates Replicates of a `"systematic"` selection.
#' @param matrix Optional [travel_matrix()] of the frame (computed from the
#'   coordinates otherwise).
#' @param method Distance method of [travel_matrix()] when `matrix` is
#'   `NULL` (`"osrm"` queries the road network once for the whole frame).
#' @param max_length,max_stops Route limits passed to [route_fieldwork()].
#' @param n_rep Replications per sample size.
#' @param iterations GRASP iterations per routing.
#' @param seed Seed.
#' @return A tibble of class `fieldopt_frontier` with one row per sample
#'   size: `n`, `cost_mean`, `cost_sd`, `cost_per_unit` (the planning value
#'   for `c1` in [two_stage_allocation()] or `cost_a` in
#'   [dual_frame_allocation()]), `travel_mean`, `routes_mean`,
#'   `variance_mean` and `cv_mean` (when `y` is given), `n_rep`, and
#'   `allocation` (a list column with the stratum sizes) when strata are
#'   used.
#' @export
#' @examples
#' set.seed(3)
#' frame <- data.frame(unit = c("depot", paste0("s", 1:40)),
#'                     x = c(5, runif(40, 0, 10)), y = c(5, runif(40, 0, 10)))
#' frame$crop <- c(NA, 20 + 3 * frame$x[-1] + rnorm(40))
#' model <- field_cost_model(per_travel = 2, per_unit = 30, per_interview = 10,
#'                           interviews_per_unit = 4)
#' cost_variance_frontier(frame, depot = "depot", cost_model = model, n_grid = c(8, 16),
#'                        y = "crop", method = "euclidean", n_rep = 3, iterations = 20)
cost_variance_frontier <- function(frame, depot, cost_model, n_grid, y = NULL, size = NULL, strata = NULL,
                                   selection = c("lpm", "systematic", "srs"), replicates = 1, matrix = NULL,
                                   method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                                   n_rep = 20, iterations = 100, seed = 1) {
  method <- rlang::arg_match(method)
  selection <- rlang::arg_match(selection)
  if (!is.list(n_grid)) n_grid <- as.list(n_grid)
  if (!length(n_grid)) cli::cli_abort("{.arg n_grid} must have at least one sample size.")
  frame <- tibble::as_tibble(frame)
  if (!"unit" %in% names(frame)) cli::cli_abort("{.arg frame} needs a column {.field unit} with names, including the depot.")
  if (!depot %in% frame$unit) cli::cli_abort("Depot {.val {depot}} not found in {.field unit}.")
  if (!inherits(cost_model, "field_cost_model")) cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
  if (is.null(matrix)) matrix <- travel_matrix(frame, method = method)
  units_frame <- frame[frame$unit != depot, ]
  coords <- if (method == "euclidean") c("x", "y") else c("lat", "lon")
  rows <- lapply(seq_along(n_grid), function(k) {
    n <- n_grid[[k]]
    cost <- travel <- nr <- var <- cv <- numeric(n_rep)
    for (r in seq_len(n_rep)) {
      s <- select_units(units_frame, n = n, size = size, coords = coords, strata = strata, method = selection,
                        replicates = replicates, seed = seed * 1000 + k * 10 + r)
      sel <- s$unit[s$sampled]
      rt <- route_fieldwork(matrix, units = sel, depot = depot, max_length = max_length, max_stops = max_stops,
                            iterations = iterations, seed = seed + r, cost_model = cost_model)
      cost[r] <- rt$cost[["total"]]; travel[r] <- rt$total; nr[r] <- rt$n_routes
      if (!is.null(y)) { dv <- design_variance(s, y = y); var[r] <- dv$variance; cv[r] <- dv$cv }
    }
    n_total <- sum(attr(s, "n"))
    out <- tibble::tibble(n = n_total, cost_mean = mean(cost), cost_sd = stats::sd(cost),
                          cost_per_unit = mean(cost) / n_total, travel_mean = mean(travel), routes_mean = mean(nr))
    if (!is.null(y)) { out$variance_mean <- mean(var); out$cv_mean <- mean(cv) }
    out$n_rep <- n_rep
    if (!is.null(strata)) out$allocation <- list(attr(s, "n"))
    out
  })
  structure(do.call(rbind, rows), class = c("fieldopt_frontier", "tbl_df", "tbl", "data.frame"),
            currency = cost_model$currency, selection = selection, replicates = replicates)
}

#' Plot the cost-variance frontier
#'
#' @param object A `fieldopt_frontier`.
#' @param ... Unused.
#' @return A ggplot of mean cost against mean variance (or against `n` when
#'   no study variable was given), labelled by sample size.
#' @exportS3Method ggplot2::autoplot fieldopt_frontier
autoplot.fieldopt_frontier <- function(object, ...) {
  d <- tibble::as_tibble(unclass(object))
  if ("variance_mean" %in% names(d)) {
    ggplot2::ggplot(d, ggplot2::aes(x = .data$variance_mean, y = .data$cost_mean, label = .data$n)) +
      ggplot2::geom_path(colour = "grey50") + ggplot2::geom_point(size = 2) +
      ggplot2::geom_text(vjust = -0.8, size = 3) +
      ggplot2::labs(x = "variance of the estimated total", y = paste0("mean field cost (", attr(object, "currency"), ")")) +
      ggplot2::theme_minimal()
  } else {
    ggplot2::ggplot(d, ggplot2::aes(x = .data$n, y = .data$cost_mean)) +
      ggplot2::geom_line(colour = "grey50") + ggplot2::geom_point(size = 2) +
      ggplot2::labs(x = "sample size", y = paste0("mean field cost (", attr(object, "currency"), ")")) +
      ggplot2::theme_minimal()
  }
}
