# Multivariate allocation ------------------------------------------------------

#' Cost-aware allocation for several study variables
#'
#' Minimum cost `sum c_h n_h` such that the variance of the estimated total
#' of every study variable is at most its target (Bethel 1989; Chromy 1987).
#' This is [frame_allocation()] with one constraint per variable: a survey
#' that must estimate several crops, or a crop and the number of farms, with
#' stated precisions. The multipliers tell which constraints bind.
#'
#' @param strata Data frame with columns `size`, `cost`, optionally `stratum`,
#'   and one standard-deviation column per study variable.
#' @param sd Names of the standard-deviation columns, one per variable.
#' @param target_variance Target variance of each variable's total, in the
#'   order of `sd` (give this or `target_cv`).
#' @param target_cv Target coefficient of variation of each total; needs
#'   `totals`.
#' @param totals Population totals of the variables, for `target_cv`.
#' @return The strata with a column `n`, of class
#'   `fieldopt_multi_allocation`, with attributes `cost`, `targets`,
#'   `attained` (variance of each variable), `multipliers`, `bounded`.
#' @references Bethel, J. (1989). Sample allocation in multivariate surveys.
#'   *Survey Methodology*, 15, 47-57. Chromy, J. R. (1987). Design optimization
#'   with multiple objectives. *Proceedings of the Survey Research Methods
#'   Section, ASA*, 194-199.
#' @export
#' @examples
#' strata <- data.frame(stratum = c("high", "mid", "low"), size = c(300, 800, 2000),
#'                      cost = c(250, 180, 150), sd_corn = c(40, 25, 8), sd_cattle = c(15, 30, 12))
#' multivariate_allocation(strata, sd = c("sd_corn", "sd_cattle"),
#'                         target_cv = c(0.05, 0.08), totals = c(90000, 60000))
multivariate_allocation <- function(strata, sd, target_variance = NULL, target_cv = NULL, totals = NULL) {
  strata <- tibble::as_tibble(strata)
  for (col in c("size", "cost", sd)) if (!col %in% names(strata)) cli::cli_abort("{.arg strata} needs a column {.field {col}}.")
  if (is.null(target_variance) == is.null(target_cv)) cli::cli_abort("Give exactly one of {.arg target_variance} and {.arg target_cv}.")
  if (!is.null(target_cv)) {
    if (is.null(totals) || length(totals) != length(sd)) cli::cli_abort("{.arg target_cv} needs {.arg totals}, one per variable.")
    target_variance <- (target_cv * totals)^2
  }
  if (length(target_variance) != length(sd)) cli::cli_abort("One target per variable in {.arg sd} is needed.")
  S <- as.matrix(strata[, sd]); storage.mode(S) <- "double"
  res <- allocate_multi_rs(as.integer(strata$size), as.numeric(strata$cost), as.numeric(t(S)), as.numeric(target_variance))
  strata$n <- res$n
  if (!"stratum" %in% names(strata)) strata$stratum <- paste0("h", seq_len(nrow(strata)))
  names(res$attained) <- names(res$multipliers) <- sd
  targets <- stats::setNames(as.numeric(target_variance), sd)
  structure(strata, class = c("fieldopt_multi_allocation", class(strata)), cost = res$cost, targets = targets,
            attained = res$attained, multipliers = res$multipliers, bounded = res$bounded)
}

#' @export
print.fieldopt_multi_allocation <- function(x, ...) {
  cli::cli_h1("Multivariate allocation")
  cli::cli_text("Minimum cost {signif(attr(x, 'cost'), 4)} for {length(attr(x, 'targets'))} target{?s}{if (attr(x, 'bounded')) ' (a bound on n_h was active)' else ''}.")
  for (v in names(attr(x, "targets"))) {
    cli::cli_text("{v}: target {signif(attr(x, 'targets')[[v]], 4)}, attained {signif(attr(x, 'attained')[[v]], 4)}{if (attr(x, 'multipliers')[[v]] > 0) ' (binding)' else ''}.")
  }
  print(tibble::as_tibble(unclass(x))[, c("stratum", "size", "cost", "n")])
  invisible(x)
}

#' @rdname allocation-methods
#' @method tidy fieldopt_multi_allocation
#' @export
tidy.fieldopt_multi_allocation <- function(x, ...) {
  d <- tibble::as_tibble(unclass(x))
  d$cost_total <- d$cost * d$n
  d[, c("stratum", "size", "cost", "n", "cost_total", setdiff(names(d), c("stratum", "size", "cost", "n", "cost_total")))]
}

#' @rdname allocation-methods
#' @method glance fieldopt_multi_allocation
#' @export
glance.fieldopt_multi_allocation <- function(x, ...) {
  tibble::tibble(variable = names(attr(x, "targets")), target = as.numeric(attr(x, "targets")), attained = as.numeric(attr(x, "attained")),
                 multiplier = as.numeric(attr(x, "multipliers")), n = sum(x$n), cost = attr(x, "cost"), bounded = attr(x, "bounded"))
}
