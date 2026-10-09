# Dual-frame and two-stage allocation ------------------------------------------

#' Dual-frame allocation (area frame plus list frame with overlap)
#'
#' Hartley's (1962, 1974) design for two frames whose union covers the
#' population: frame A (typically the area frame, complete but expensive) and
#' frame B (the list, cheap but incomplete). The population splits into the
#' domains `a` (A only), `ab` (both) and `b` (B only), and the total is
#' estimated by `Y_a + theta * Y_ab(A) + (1 - theta) * Y_ab(B) + Y_b`: the
#' overlap is estimated from both samples and mixed with weight `theta`.
#' With simple random sampling in each frame (other designs enter through
#' design effects) the variance is a sum of two frame terms, so for each
#' `theta` the cost-optimal `n_A`, `n_B` follow the cost-weighted Neyman
#' rule; `theta` is then optimised. `theta = 0` is the **screening** design,
#' in which overlap units found in the area sample are not used (the list
#' covers them), the usual practice when the list holds the large producers.
#'
#' The cost per area unit should include the field work: take it from the
#' routing, for example `cost_mean / n` of a [cost_variance_frontier()] at the
#' sample size under consideration, and iterate once or twice.
#'
#' @param domains Data frame with one row per domain `a`, `ab`, `b` (column
#'   `domain`) and columns `size` (units), `mean` and `sd` (standard
#'   deviation with divisor `size - 1`) of the study variable.
#' @param cost_a,cost_b Cost per sampled unit in frame A and frame B.
#' @param deff_a,deff_b Design effects of the two samples relative to simple
#'   random sampling (an area sample of segments or points usually has
#'   `deff_a > 1`).
#' @param theta `NULL` to optimise, a number in `[0, 1]`, or `"screening"`
#'   (zero).
#' @param target_variance,target_cv,budget Exactly one: target variance of the
#'   estimated total, target coefficient of variation (relative to the
#'   population total implied by `domains`), or budget.
#' @return A list of class `fieldopt_dual_frame`: `n_a`, `n_b`, `theta`,
#'   `cost`, `variance`, `se`, `cv`, `total` (implied population total),
#'   `variance_a`, `variance_b`, `overlap_a`, `overlap_b` (expected overlap
#'   units in each sample), `bounded`, and the inputs.
#' @references Hartley, H. O. (1962). Multiple frame surveys. *Proceedings of
#'   the Social Statistics Section, ASA*, 203--206. Hartley, H. O. (1974).
#'   Multiple frame methodology and selected applications. *Sankhya C*, 36,
#'   99--118. Lohr, S. L. and Rao, J. N. K. (2006). Estimation in multiple-frame
#'   surveys. *JASA*, 101(475), 1019--1030.
#' @export
#' @examples
#' domains <- data.frame(domain = c("a", "ab", "b"), size = c(8000, 1500, 500),
#'                       mean = c(5, 40, 60), sd = c(6, 30, 50))
#' dual_frame_allocation(domains, cost_a = 200, cost_b = 40, budget = 1e5)
#' dual_frame_allocation(domains, cost_a = 200, cost_b = 40, theta = "screening", target_cv = 0.05)
dual_frame_allocation <- function(domains, cost_a, cost_b, deff_a = 1, deff_b = 1, theta = NULL,
                                  target_variance = NULL, target_cv = NULL, budget = NULL) {
  domains <- as.data.frame(domains)
  for (col in c("domain", "size", "mean", "sd")) if (!col %in% names(domains)) cli::cli_abort("{.arg domains} needs a column {.field {col}}.")
  if (!setequal(domains$domain, c("a", "ab", "b")) || nrow(domains) != 3L) cli::cli_abort("{.arg domains} must have exactly the rows {.val a}, {.val ab} and {.val b}.")
  d <- domains[match(c("a", "ab", "b"), domains$domain), ]
  given <- c(!is.null(target_variance), !is.null(target_cv), !is.null(budget))
  if (sum(given) != 1L) cli::cli_abort("Give exactly one of {.arg target_variance}, {.arg target_cv} and {.arg budget}.")
  total <- sum(d$size * d$mean)
  if (!is.null(target_cv)) {
    if (total == 0) cli::cli_abort("{.arg target_cv} needs a non-zero population total.")
    target_variance <- (target_cv * total)^2
  }
  mode <- if (is.null(budget)) "variance" else "budget"
  target <- if (mode == "variance") target_variance else budget
  th <- if (is.null(theta)) -1 else if (identical(theta, "screening")) 0 else { if (!is.numeric(theta) || length(theta) != 1L || is.na(theta) || theta < 0 || theta > 1) cli::cli_abort("{.arg theta} must be a number in [0, 1], {.val screening} or NULL."); theta }
  res <- dual_frame_rs(as.integer(d$size), as.numeric(d$mean), as.numeric(d$sd), cost_a, cost_b, deff_a, deff_b, th, as.numeric(target), mode)
  res$se <- sqrt(res$variance); res$cv <- if (total != 0) res$se / abs(total) else NA_real_; res$total <- total
  res$domains <- tibble::as_tibble(d); res$cost_a <- cost_a; res$cost_b <- cost_b; res$deff_a <- deff_a; res$deff_b <- deff_b
  res$mode <- mode; res$target <- target; res$theta_fixed <- !is.null(theta)
  structure(res, class = "fieldopt_dual_frame")
}

#' @export
print.fieldopt_dual_frame <- function(x, ...) {
  cli::cli_h1("Dual-frame allocation")
  cli::cli_text("{if (x$mode == 'variance') 'Minimum cost for target variance' else 'Minimum variance for budget'} {signif(x$target, 4)}: n_A = {x$n_a} (frame A, cost {signif(x$cost_a, 4)}/unit), n_B = {x$n_b} (frame B, cost {signif(x$cost_b, 4)}/unit), theta = {round(x$theta, 3)}{if (x$theta_fixed) ' (fixed)' else ' (optimised)'}.")
  cli::cli_text("Cost {signif(x$cost, 4)}; variance {signif(x$variance, 4)} (frame A {signif(x$variance_a, 3)}, frame B {signif(x$variance_b, 3)}); CV {signif(100 * x$cv, 3)}% of the total {signif(x$total, 4)}.")
  cli::cli_text("Expected overlap units: {round(x$overlap_a, 1)} in the A sample, {round(x$overlap_b, 1)} in the B sample{if (x$bounded) '; a bound on a sample size was active' else ''}.")
  invisible(x)
}

#' Two-stage allocation with a field cost function
#'
#' `n` primary units (segments, grid cells) are visited and `m` secondary
#' units (points, tracts, establishments) are observed in each, at a cost
#' `c1 * n + c2 * n * m`. With `s2_between` the variance among primary-unit
#' means and `s2_within` the variance within primary units, the variance of
#' the estimated mean per secondary unit is
#' `(1 - n/N) s2_between / n + (1 - m/M) s2_within / (n m)` and the
#' cost-optimal `m` is `sqrt(c1 s2_within / (c2 (s2_between - s2_within / M)))`
#' (Cochran 1977, Section 10.6). The cost `c1` of visiting a primary unit is
#' where the routing enters: it is not a constant but depends on how spread
#' the sample is; take it from [cost_variance_frontier()] at the candidate
#' `n` and iterate.
#'
#' @param n_primary,m_secondary Primary units in the population and secondary
#'   units per primary unit (an average when they differ; need not be a whole
#'   number). The allocation tries every whole `m` up to `m_secondary` and
#'   keeps the cheapest pair meeting the target (or the least variance within
#'   the budget), so small populations are handled exactly.
#' @param s2_between,s2_within Variance among primary-unit means and within
#'   primary units.
#' @param c1,c2 Cost per primary unit visited and per secondary unit observed.
#' @param target_variance,target_cv,budget Exactly one: target variance of the
#'   estimated **total**, target coefficient of variation (needs `mean`), or
#'   budget.
#' @param mean Population mean per secondary unit, for `target_cv`.
#' @return A list of class `fieldopt_two_stage`: `n`, `m`, `m_optimal`,
#'   `cost`, `variance_mean`, `variance_total`, `se_total`, `cv` (when `mean`
#'   is given), `bounded`.
#' @export
#' @examples
#' two_stage_allocation(n_primary = 5000, m_secondary = 20, s2_between = 4, s2_within = 25,
#'                      c1 = 300, c2 = 20, budget = 1e5)
#' two_stage_allocation(5000, 20, 4, 25, c1 = 300, c2 = 20, target_cv = 0.03, mean = 12)
two_stage_allocation <- function(n_primary, m_secondary, s2_between, s2_within, c1, c2,
                                 target_variance = NULL, target_cv = NULL, budget = NULL, mean = NULL) {
  given <- c(!is.null(target_variance), !is.null(target_cv), !is.null(budget))
  if (sum(given) != 1L) cli::cli_abort("Give exactly one of {.arg target_variance}, {.arg target_cv} and {.arg budget}.")
  scale <- (n_primary * m_secondary)^2
  if (!is.null(target_cv)) {
    if (is.null(mean)) cli::cli_abort("{.arg target_cv} needs {.arg mean}.")
    target_variance <- (target_cv * mean * n_primary * m_secondary)^2
  }
  mode <- if (is.null(budget)) "variance" else "budget"
  target <- if (mode == "variance") target_variance / scale else budget
  res <- two_stage_rs(as.integer(n_primary), as.numeric(m_secondary), s2_between, s2_within, c1, c2, as.numeric(target), mode)
  res$se_total <- sqrt(res$variance_total)
  res$cv <- if (!is.null(mean) && mean != 0) res$se_total / abs(mean * n_primary * m_secondary) else NA_real_
  res$mode <- mode; res$inputs <- list(n_primary = n_primary, m_secondary = m_secondary, s2_between = s2_between, s2_within = s2_within, c1 = c1, c2 = c2)
  structure(res, class = "fieldopt_two_stage")
}

#' @export
print.fieldopt_two_stage <- function(x, ...) {
  cli::cli_h1("Two-stage allocation")
  cli::cli_text("n = {x$n} primary units with m = {x$m} secondary units each (optimal m {round(x$m_optimal, 2)}): cost {signif(x$cost, 4)}, variance of the total {signif(x$variance_total, 4)} (SE {signif(x$se_total, 4)}{if (!is.na(x$cv)) paste0(', CV ', signif(100 * x$cv, 3), '%') else ''}){if (x$bounded) '; a bound was active' else ''}.")
  invisible(x)
}

# Covariance of two Horvitz-Thompson totals under the design of a sample:
# var(z1 + z2) - var(z1) - var(z2), halved, with the sample's own estimator.
cov_ht <- function(sample, z1, z2) {
  (ht_variance(sample, z1 + z2)$variance - ht_variance(sample, z1)$variance - ht_variance(sample, z2)$variance) / 2
}

#' Dual-frame estimate of a total
#'
#' Combines the sample of frame A (the area frame) and the sample of frame B
#' (the list) into one estimate of the population total of `y`. Each sampled
#' unit carries its domain: `"a"` or `"ab"` in the A sample, `"b"` or `"ab"`
#' in the B sample. Two estimators:
#'
#' * **Hartley (1962)**: `Y_a + theta * Y_ab(A) + (1 - theta) * Y_ab(B) +
#'   Y_b`, with `theta` fixed, `"screening"` (`theta = 0`: overlap units
#'   found in the area sample are dropped, as when the list is enumerated
#'   completely) or estimated as the value that minimises the variance;
#' * **Fuller and Burmeister (1972)**: adds a second term in the difference
#'   between the two estimates of the overlap size, with coefficients chosen
#'   to minimise the variance.
#'
#' Variances and covariances of the domain totals come from the variance
#' estimator of each sample's design ([design_variance()]), the two samples
#' being independent. The estimated `theta` and the Fuller-Burmeister
#' coefficients make the variances slightly optimistic in small samples.
#'
#' @param sample_a,sample_b [select_units()] samples of frame A and frame B
#'   with columns `y` and `domain` (unsampled rows may hold `NA`).
#' @param y Column of the study variable.
#' @param domain Column with the domain of each unit.
#' @param theta Mixing weight of the overlap for Hartley: a number in
#'   `[0, 1]`, `"screening"`, or `NULL` to estimate it.
#' @param estimator `"hartley"` or `"fuller-burmeister"`.
#' @return A one-row tibble: `total`, `variance`, `se`, `cv`, `estimator`,
#'   `theta` (Hartley) or `beta_1`, `beta_2` (Fuller-Burmeister), the domain
#'   totals `y_a`, `y_ab_a`, `y_ab_b`, `y_b`, and `n_a`, `n_b`.
#' @references Hartley, H. O. (1962). Multiple frame surveys. *Proceedings of
#'   the Social Statistics Section, ASA*, 203-206. Fuller, W. A. and
#'   Burmeister, L. F. (1972). Estimators for samples selected from two
#'   overlapping frames. *Proceedings of the Social Statistics Section, ASA*,
#'   245-249. Lohr, S. L. (2009). Multiple-frame surveys. In *Handbook of
#'   Statistics 29A*, 71-88.
#' @export
#' @examples
#' set.seed(7)
#' cells <- expand.grid(x = 1:12, y = 1:12); cells$unit <- paste0("c", 1:144)
#' cells$domain <- ifelse(runif(144) < 0.2, "ab", "a")
#' cells$y <- ifelse(cells$domain == "ab", 80, 10) + rnorm(144, sd = 3)
#' # the list holds the overlap units (same values) plus units of its own
#' ab <- cells[cells$domain == "ab", ]
#' list <- data.frame(unit = c(paste0("l", seq_len(nrow(ab))), paste0("b", 1:11)),
#'                    x = runif(nrow(ab) + 11), y = c(ab$y, 120 + rnorm(11, sd = 5)),
#'                    domain = rep(c("ab", "b"), c(nrow(ab), 11)))
#' list$lon <- runif(nrow(list)); list$lat <- runif(nrow(list))
#' sa <- select_units(cells, n = 30, seed = 1)
#' sb <- select_units(list, n = 15, coords = c("lat", "lon"), method = "srs", seed = 2)
#' dual_frame_estimator(sa, sb, y = "y", domain = "domain")
#' dual_frame_estimator(sa, sb, y = "y", domain = "domain", theta = "screening")
#' dual_frame_estimator(sa, sb, y = "y", domain = "domain", estimator = "fuller-burmeister")
dual_frame_estimator <- function(sample_a, sample_b, y, domain = "domain", theta = NULL,
                                 estimator = c("hartley", "fuller-burmeister")) {
  estimator <- rlang::arg_match(estimator)
  for (s in list(sample_a, sample_b)) {
    if (!inherits(s, "fieldopt_sample")) cli::cli_abort("{.arg sample_a} and {.arg sample_b} must come from {.fn select_units}.")
    for (col in c(y, domain)) if (!col %in% names(s)) cli::cli_abort("Column {.field {col}} not found.")
  }
  dom_a <- as.character(sample_a[[domain]]); dom_b <- as.character(sample_b[[domain]])
  sa <- sample_a$sampled; sb <- sample_b$sampled
  if (!all(dom_a[sa] %in% c("a", "ab"))) cli::cli_abort("Domains in frame A must be {.val a} or {.val ab}.")
  if (!all(dom_b[sb] %in% c("b", "ab"))) cli::cli_abort("Domains in frame B must be {.val b} or {.val ab}.")
  ya <- as.numeric(sample_a[[y]]); yb <- as.numeric(sample_b[[y]])
  if (anyNA(ya[sa]) || anyNA(yb[sb])) cli::cli_abort("{.field {y}} is missing for some sampled units.")
  ya[!sa] <- 0; yb[!sb] <- 0
  dom_a[!sa] <- ""; dom_b[!sb] <- ""
  z_a <- ya * (dom_a == "a"); z_aba <- ya * (dom_a == "ab")
  z_b <- yb * (dom_b == "b"); z_abb <- yb * (dom_b == "ab")
  tot <- function(s, z) ht_total_rs(z, s$pi, s$sampled)
  y_a <- tot(sample_a, z_a); y_aba <- tot(sample_a, z_aba); y_b <- tot(sample_b, z_b); y_abb <- tot(sample_b, z_abb)
  v_a <- ht_variance(sample_a, z_a)$variance; v_aba <- ht_variance(sample_a, z_aba)$variance; c_a <- cov_ht(sample_a, z_a, z_aba)
  v_b <- ht_variance(sample_b, z_b)$variance; v_abb <- ht_variance(sample_b, z_abb)$variance; c_b <- cov_ht(sample_b, z_b, z_abb)
  out <- tibble::tibble(total = NA_real_, variance = NA_real_, se = NA_real_, cv = NA_real_, estimator = estimator)
  if (estimator == "hartley") {
    th <- if (is.null(theta)) {
      den <- v_aba + v_abb
      if (den <= 0) 0.5 else min(1, max(0, (v_abb + c_b - c_a) / den))
    } else if (identical(theta, "screening")) 0 else {
      if (!is.numeric(theta) || length(theta) != 1L || is.na(theta) || theta < 0 || theta > 1) cli::cli_abort("{.arg theta} must be a number in [0, 1], {.val screening} or NULL.")
      theta
    }
    out$total <- y_a + th * y_aba + (1 - th) * y_abb + y_b
    out$variance <- v_a + 2 * th * c_a + th^2 * v_aba + v_b + 2 * (1 - th) * c_b + (1 - th)^2 * v_abb
    out$theta <- th; out$theta_fixed <- !is.null(theta)
  } else {
    ia <- as.numeric(dom_a == "ab"); ib <- as.numeric(dom_b == "ab")
    n_aba <- tot(sample_a, ia); n_abb <- tot(sample_b, ib)
    # base = Y_a + Y_b + Y_ab(B); D1 = Y_ab(A) - Y_ab(B); D2 = N_ab(A) - N_ab(B)
    base <- y_a + y_b + y_abb
    d1 <- y_aba - y_abb; d2 <- n_aba - n_abb
    v_base <- v_a + ht_variance(sample_b, z_b + z_abb)$variance
    v_na <- ht_variance(sample_a, ia)$variance; v_nb <- ht_variance(sample_b, ib)$variance
    s11 <- v_aba + v_abb
    s22 <- v_na + v_nb
    s12 <- cov_ht(sample_a, z_aba, ia) + cov_ht(sample_b, z_abb, ib)
    s1b <- c_a - cov_ht(sample_b, z_abb, z_b + z_abb)
    s2b <- cov_ht(sample_a, ia, z_a) - cov_ht(sample_b, ib, z_b + z_abb)
    S <- matrix(c(s11, s12, s12, s22), 2); r <- c(s1b, s2b)
    beta <- tryCatch(-solve(S, r), error = function(e) c(-s1b / max(s11, 1e-12), 0))
    out$total <- base + beta[1] * d1 + beta[2] * d2
    out$variance <- max(v_base + 2 * sum(beta * r) + as.numeric(t(beta) %*% S %*% beta), 0)
    out$beta_1 <- beta[1]; out$beta_2 <- beta[2]
  }
  out$se <- sqrt(out$variance); out$cv <- if (out$total != 0) out$se / abs(out$total) else NA_real_
  out$y_a <- y_a; out$y_ab_a <- y_aba; out$y_ab_b <- y_abb; out$y_b <- y_b
  out$n_a <- sum(sa); out$n_b <- sum(sb)
  out
}
