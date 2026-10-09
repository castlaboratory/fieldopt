# Selection of units, estimation and allocation --------------------------------

#' Select units with a spatially balanced probability sample
#'
#' Draws `n` units with inclusion probabilities proportional to `size` (equal
#' when `size` is `NULL`) by the local pivotal method (Grafström, Lundström
#' and Schelin, 2012), which spreads the sample over the coordinate space so
#' that nearby units are rarely selected together. The design is
#' probabilistic with known inclusion probabilities, which is what the
#' estimator needs; spatial balance reduces the variance and, at the same
#' time, tends to spread the field work, which is the tension the cost model
#' and routing make explicit.
#'
#' @param frame Data frame with one row per unit: coordinate columns (`lat`,
#'   `lon` or `x`, `y`, or those named in `coords`), an optional `size` column
#'   and an optional `unit` column with names.
#' @param n Sample size.
#' @param size Column of the size measure for probability-proportional-to-size
#'   selection, or `NULL` for equal probabilities.
#' @param coords Names of the coordinate columns used for spatial balance (any
#'   number of columns; a travel-cost embedding is admissible).
#' @param seed Seed.
#' @return The frame as a tibble with columns `pi` (inclusion probability) and
#'   `sampled`, of class `fieldopt_sample`, with attributes `n`, `coords` and
#'   `seed`.
#' @references Grafström, A., Lundström, N. L. P. and Schelin, L. (2012).
#'   Spatially balanced sampling through the pivotal method. *Biometrics*,
#'   68(2), 514--520.
#' @export
#' @examples
#' set.seed(1)
#' frame <- data.frame(unit = paste0("s", 1:50), x = runif(50), y = runif(50), size = rexp(50))
#' s <- select_units(frame, n = 10, size = "size")
#' sum(s$sampled); sum(s$pi)
select_units <- function(frame, n, size = NULL, coords = NULL, seed = 1) {
  frame <- tibble::as_tibble(frame)
  if (is.null(coords)) coords <- if (all(c("lat", "lon") %in% names(frame))) c("lat", "lon") else if (all(c("x", "y") %in% names(frame))) c("x", "y") else cli::cli_abort("{.arg frame} needs coordinate columns ({.field lat}/{.field lon} or {.field x}/{.field y}) or {.arg coords}.")
  if (!all(coords %in% names(frame))) cli::cli_abort("Coordinate column{?s} {.field {setdiff(coords, names(frame))}} not found.")
  X <- as.matrix(frame[, coords]); storage.mode(X) <- "double"
  if (anyNA(X)) cli::cli_abort("Coordinates must not be missing.")
  N <- nrow(frame)
  if (!is.numeric(n) || length(n) != 1L || n < 1 || n > N || n != round(n)) cli::cli_abort("{.arg n} must be a whole number between 1 and {N}.")
  sz <- if (is.null(size)) rep(1, N) else { if (!size %in% names(frame)) cli::cli_abort("Size column {.field {size}} not found."); as.numeric(frame[[size]]) }
  pi <- inclusion_probabilities_rs(sz, as.integer(n))
  sampled <- local_pivotal_rs(as.numeric(t(X)), ncol(X), pi, seed)
  frame$pi <- pi; frame$sampled <- sampled
  if (!"unit" %in% names(frame)) frame$unit <- paste0("u", seq_len(N))
  structure(frame, class = c("fieldopt_sample", class(frame)), n = n, coords = coords, seed = seed, size = size)
}

#' Design-based estimate of a total with its variance
#'
#' Horvitz-Thompson estimate of the population total of `y` from a
#' [select_units()] sample, with the local-mean variance estimator of
#' Grafström and Schelin (2014), which suits spatially balanced samples and
#' needs no joint inclusion probabilities. The simple-random-sampling variance
#' of the same sample is reported as a reference.
#'
#' @param sample A `fieldopt_sample`.
#' @param y Column of the study variable (observed on the sampled units; other
#'   rows may be `NA`).
#' @return A one-row tibble: `total`, `variance`, `se`, `cv`, `variance_srs`,
#'   `n`, `N`.
#' @references Grafström, A. and Schelin, L. (2014). How to select
#'   representative samples. *Scandinavian Journal of Statistics*, 41(2),
#'   277--290.
#' @export
#' @examples
#' set.seed(2)
#' frame <- data.frame(x = runif(80), y = runif(80))
#' frame$crop <- 10 + 20 * frame$x + rnorm(80)
#' s <- select_units(frame, n = 20)
#' design_variance(s, y = "crop")
design_variance <- function(sample, y) {
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  if (!y %in% names(sample)) cli::cli_abort("Column {.field {y}} not found.")
  yy <- as.numeric(sample[[y]]); s <- sample$sampled
  if (anyNA(yy[s])) cli::cli_abort("{.field {y}} is missing for some sampled units.")
  yy[!s] <- 0
  X <- as.matrix(sample[, attr(sample, "coords")]); storage.mode(X) <- "double"
  total <- ht_total_rs(yy, sample$pi, s)
  v <- local_mean_variance_rs(as.numeric(t(X)), ncol(X), yy, sample$pi, s)
  v_srs <- srs_variance_rs(yy, s, nrow(sample))
  tibble::tibble(total = total, variance = v, se = sqrt(v), cv = sqrt(v) / abs(total),
                 variance_srs = v_srs, n = sum(s), N = nrow(sample))
}

#' Cost-aware allocation across strata or frames
#'
#' Classical optimum allocation with a cost per unit in each stratum (Cochran
#' 1977, Section 5.5): minimum cost for a target variance of the estimated
#' total, or minimum variance for a budget. Frames (a list frame and an area
#' frame) are treated as strata with their own variance and cost; the overlap
#' of dual frames is not modelled here.
#'
#' @param strata Data frame with columns `size` (population units), `sd`
#'   (standard deviation of the study variable) and `cost` (cost per unit,
#'   interview plus expected access), and optionally `stratum` with names.
#' @param target_variance Target variance of the estimated total (give this or
#'   `budget`).
#' @param budget Total cost allowed.
#' @return The strata with a column `n`, plus attributes `cost`, `variance`
#'   and `bounded` (whether `2 <= n_h <= N_h` was active), of class
#'   `fieldopt_allocation`.
#' @export
#' @examples
#' strata <- data.frame(stratum = c("list", "area"), size = c(2000, 800),
#'                      sd = c(12, 30), cost = c(40, 180))
#' frame_allocation(strata, target_variance = 4e6)
#' frame_allocation(strata, budget = 20000)
frame_allocation <- function(strata, target_variance = NULL, budget = NULL) {
  strata <- tibble::as_tibble(strata)
  for (col in c("size", "sd", "cost")) if (!col %in% names(strata)) cli::cli_abort("{.arg strata} needs a column {.field {col}}.")
  if (is.null(target_variance) == is.null(budget)) cli::cli_abort("Give exactly one of {.arg target_variance} and {.arg budget}.")
  mode <- if (is.null(budget)) "variance" else "budget"
  target <- if (mode == "variance") target_variance else budget
  res <- allocate_rs(as.integer(strata$size), as.numeric(strata$sd), as.numeric(strata$cost), as.numeric(target), mode)
  strata$n <- res$n
  if (!"stratum" %in% names(strata)) strata$stratum <- paste0("h", seq_len(nrow(strata)))
  structure(strata, class = c("fieldopt_allocation", class(strata)), cost = res$cost, variance = res$variance,
            bounded = res$bounded, mode = mode, target = target)
}

#' @export
print.fieldopt_allocation <- function(x, ...) {
  cli::cli_h1("Allocation")
  cli::cli_text("{if (attr(x, 'mode') == 'variance') 'Minimum cost for target variance' else 'Minimum variance for budget'} {signif(attr(x, 'target'), 4)}: cost {signif(attr(x, 'cost'), 4)}, variance {signif(attr(x, 'variance'), 4)}{if (attr(x, 'bounded')) ' (a bound on n_h was active)' else ''}.")
  print(tibble::as_tibble(unclass(x))[, c("stratum", "size", "sd", "cost", "n")])
  invisible(x)
}
