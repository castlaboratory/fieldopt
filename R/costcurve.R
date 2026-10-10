# Routed cost curve ----------------------------------------------------------

#' Routed cost curve of a design: the travel constant of Hansen, Hurwitz and Madow
#'
#' Selects samples of each size in `n_grid`, routes each one from the depot
#' (or bases), prices it with the cost model, and fits the expected cost as
#' `G(n) = c0 + a n + b sqrt(n)`. This is the cost function of Hansen, Hurwitz
#' and Madow (1953, Vol. I, Chapter 6, Section 12), `C0 sqrt(m) + C1 m`, with `b` in
#' the role of their travel constant `C0` and `a` of the cost per primary unit
#' `C1`. They derived `C0` from points on a regular grid and called it a rough
#' approximation; here it is measured on the frame, with its roads (when the
#' matrix comes from OSRM), its depots and its route limits. The travel of a
#' tour through `n` scattered points grows like `sqrt(n)` (Beardwood, Halton
#' and Hammersley 1959), and fixed costs per visit and per route add the
#' linear term.
#'
#' The fit is constrained to be increasing and concave (`a >= 0`, `b >= 0`),
#' so the marginal cost `G'(n) = a + b / (2 sqrt(n))` is positive and falls
#' with `n`. The marginal cost is the one the classical allocation formulas
#' need (see [two_stage_design()]).
#'
#' @inheritParams cost_variance_frontier
#' @param n_grid Sample sizes to route (at least three distinct values for the
#'   three coefficients).
#' @param n_rep Routed samples per sample size.
#' @return An object of class `fieldopt_cost_curve`: a list with `points` (a
#'   tibble with `n`, `cost_mean`, `cost_sd`, `travel_mean`, `routes_mean` per
#'   routed size), `coef` (`c0`, `a`, `b`), `r_squared`, `currency` and the
#'   settings. `predict()` gives the total, average or marginal cost at any
#'   `n`; `tidy()`, `glance()` and `autoplot()` are available.
#' @references Hansen, M. H., Hurwitz, W. N. and Madow, W. G. (1953). *Sample
#'   Survey Methods and Theory*, Vol. I, Chapter 6, Sections 11-15, and Vol.
#'   II, Chapter 6, Section 11. Wiley. Beardwood, J., Halton, J. H. and
#'   Hammersley, J. M. (1959). The shortest path through many points. *Proc.
#'   Cambridge Phil. Soc.*, 55, 299-327.
#' @export
#' @examples
#' set.seed(2)
#' cells <- expand.grid(x = 1:15, y = 1:15)
#' cells$unit <- paste0("c", seq_len(nrow(cells)))
#' frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
#' model <- field_cost_model(per_travel = 3, per_unit = 40)
#' curve <- routed_cost_curve(frame, "depot", model,
#'   n_grid = c(10, 20, 40, 80), method = "euclidean", n_rep = 2,
#'   iterations = 20
#' )
#' curve
#' predict(curve, c(30, 60), type = "marginal")
routed_cost_curve <- function(frame, depot, cost_model, n_grid, size = NULL, strata = NULL,
                              selection = c("lpm", "systematic", "srs"), replicates = 1, matrix = NULL,
                              method = c("haversine", "euclidean", "osrm"), max_length = Inf, max_stops = Inf,
                              n_rep = 10, iterations = 100, seed = 1) {
  selection <- rlang::arg_match(selection)
  method <- rlang::arg_match(method)
  if (length(unique(unlist(n_grid))) < 3L) cli::cli_abort("{.arg n_grid} needs at least three distinct sample sizes.")
  f <- cost_variance_frontier(frame, depot, cost_model,
    n_grid = n_grid, size = size, strata = strata,
    selection = selection, replicates = replicates, matrix = matrix, method = method,
    max_length = max_length, max_stops = max_stops, n_rep = n_rep,
    iterations = iterations, seed = seed
  )
  points <- tibble::tibble(
    n = as.integer(f$n), cost_mean = f$cost_mean, cost_sd = f$cost_sd,
    travel_mean = f$travel_mean, routes_mean = f$routes_mean
  )
  coef <- fit_cost_curve(points)
  fitted <- curve_G(coef, points$n)
  ss_tot <- sum((points$cost_mean - mean(points$cost_mean))^2)
  r2 <- if (ss_tot > 0) 1 - sum((points$cost_mean - fitted)^2) / ss_tot else NA_real_
  structure(list(
    points = points, coef = coef, r_squared = r2, currency = cost_model$currency,
    selection = selection, n_rep = n_rep, max_length = max_length
  ), class = "fieldopt_cost_curve")
}

#' @export
print.fieldopt_cost_curve <- function(x, ...) {
  co <- x$coef
  cli::cli_h1("Routed cost curve")
  cli::cli_text(
    "G(n) = {signif(co[['c0']], 4)} + {signif(co[['a']], 4)} n + {signif(co[['b']], 4)} sqrt(n) ",
    "({x$currency}; {nrow(x$points)} sample sizes from {min(x$points$n)} to {max(x$points$n)}, ",
    "{x$n_rep} routed samples each, {x$selection} selection; R-squared {signif(x$r_squared, 4)})."
  )
  cli::cli_text("In Hansen, Hurwitz and Madow's notation: C0 = {signif(co[['b']], 4)} (travel), C1 = {signif(co[['a']], 4)} (per primary unit).")
  mid <- stats::median(x$points$n)
  cli::cli_text("At n = {mid}: average cost {signif(stats::predict(x, mid, 'average'), 4)}, marginal cost {signif(stats::predict(x, mid, 'marginal'), 4)} per unit.")
  invisible(x)
}

#' @rdname routed_cost_curve
#' @param newdata Sample sizes (a numeric vector) for `predict()`.
#' @param type `"total"` for `G(n)`, `"average"` for `G(n)/n`, `"marginal"`
#'   for `G'(n)`.
#' @export
predict.fieldopt_cost_curve <- function(object, newdata, type = c("total", "average", "marginal"), ...) {
  type <- rlang::arg_match(type)
  n <- as.numeric(newdata)
  switch(type,
    total = curve_G(object$coef, n),
    average = curve_G(object$coef, n) / n,
    marginal = curve_Gprime(object$coef, n)
  )
}

#' @rdname routed_cost_curve
#' @param x,object A `fieldopt_cost_curve`.
#' @param ... Unused.
#' @method tidy fieldopt_cost_curve
#' @export
tidy.fieldopt_cost_curve <- function(x, ...) {
  x$points |>
    dplyr_free_mutate(
      fitted = curve_G(x$coef, x$points$n),
      average = curve_G(x$coef, x$points$n) / x$points$n,
      marginal = curve_Gprime(x$coef, x$points$n)
    )
}

#' @rdname routed_cost_curve
#' @method glance fieldopt_cost_curve
#' @export
glance.fieldopt_cost_curve <- function(x, ...) {
  tibble::tibble(
    c0 = x$coef[["c0"]], a = x$coef[["a"]], b = x$coef[["b"]], r_squared = x$r_squared,
    n_min = min(x$points$n), n_max = max(x$points$n), n_sizes = nrow(x$points), n_rep = x$n_rep
  )
}

#' @rdname routed_cost_curve
#' @method autoplot fieldopt_cost_curve
#' @export
autoplot.fieldopt_cost_curve <- function(object, ...) {
  grid <- seq(min(object$points$n), max(object$points$n), length.out = 200)
  fit <- tibble::tibble(n = grid, cost = curve_G(object$coef, grid))
  ggplot2::ggplot(object$points, ggplot2::aes(x = .data$n, y = .data$cost_mean)) +
    ggplot2::geom_line(data = fit, ggplot2::aes(y = .data$cost), colour = "grey40") +
    ggplot2::geom_pointrange(ggplot2::aes(ymin = .data$cost_mean - .data$cost_sd, ymax = .data$cost_mean + .data$cost_sd), size = 0.3) +
    ggplot2::labs(x = "sample size n", y = paste0("routed cost G(n) (", object$currency, ")")) +
    ggplot2::theme_minimal()
}

# add columns to a tibble without dplyr
dplyr_free_mutate <- function(d, ...) {
  new <- list(...)
  for (nm in names(new)) d[[nm]] <- new[[nm]]
  d
}
