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
#'   `domain`) and columns `size` (units), `mean` and `sd` of the study
#'   variable.
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
  th <- if (is.null(theta)) -1 else if (identical(theta, "screening")) 0 else { if (!is.numeric(theta) || length(theta) != 1L) cli::cli_abort("{.arg theta} must be a number, {.val screening} or NULL."); theta }
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
#'   units per primary unit (an average when they differ).
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
  res <- two_stage_rs(as.integer(n_primary), as.integer(m_secondary), s2_between, s2_within, c1, c2, as.numeric(target), mode)
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
