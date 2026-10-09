# Monte Carlo evaluation of point sampling -----------------------------------

#' Design effect and bias of point sampling by simulation
#'
#' Repeats the whole area-frame design, selecting cells with
#' [select_units()], placing points with [select_points()], letting each
#' point hit the establishment whose land it falls on (with probability
#' equal to the establishment's share of the cell), and estimating the total
#' with [point_estimator()]. Returns the empirical variance of the estimator,
#' its bias, the mean number of interviews, and the design effect relative to
#' a simple random sample of establishments with the same number of
#' interviews: the `deff_a` that [dual_frame_allocation()] asks for.
#'
#' @param cells Data frame of cells as in [select_units()] (with `unit`,
#'   coordinates and, when used, strata and size columns).
#' @param areas Data frame with one row per (establishment, cell) pair:
#'   `establishment`, `unit`, `area` (land of the establishment inside the
#'   cell, in the square units of `cell_size`) and `y` (the study variable of
#'   the whole establishment, repeated across its cells).
#' @inheritParams select_units
#' @inheritParams select_points
#' @param n_sim Number of simulated surveys.
#' @details Hits are attributed by the establishments' shares of the cell
#'   area, not by the geometry of their fields, so the simulator does not
#'   distinguish the random and systematic point layouts; it captures the
#'   cell design, the point intensity and the multiplicity, which is what
#'   drives the design effect at the cell level.
#' @param seed Seed.
#' @return A one-row tibble of class `fieldopt_point_deff`: `n_sim`,
#'   `total`, `mean_estimate`, `bias`, `variance`, `cv`,
#'   `mean_variance_estimate` (the mean of the [point_estimator()] variance
#'   estimates, to be compared with `variance`), `interviews`,
#'   `variance_srs`, `deff`; attribute `estimates` holds the simulated values.
#' @export
#' @examples
#' set.seed(4)
#' cells <- expand.grid(x = 1:10, y = 1:10); cells$unit <- paste0("c", 1:100)
#' areas <- rbind(
#'   data.frame(establishment = paste0(cells$unit, "-1"), unit = cells$unit, area = 0.5),
#'   data.frame(establishment = paste0(cells$unit, "-2"), unit = cells$unit, area = 0.2))
#' areas$y <- round(rgamma(nrow(areas), 3, 3 / (10 * areas$area)), 1)
#' point_design_effect(cells, areas, n = 15, points_per_cell = 6, cell_size = 1, n_sim = 20)
point_design_effect <- function(cells, areas, n, points_per_cell, cell_size, size = NULL, strata = NULL,
                                method = c("lpm", "systematic", "srs"), replicates = 1, n_sim = 200, seed = 1) {
  method <- rlang::arg_match(method)
  for (col in c("establishment", "unit", "area", "y")) if (!col %in% names(areas)) cli::cli_abort("{.arg areas} needs a column {.field {col}}.")
  cells <- tibble::as_tibble(cells)
  if (!"unit" %in% names(cells)) cells$unit <- paste0("u", seq_len(nrow(cells)))
  if (length(cell_size) == 1L) cell_size <- c(cell_size, cell_size)
  cell_area <- prod(cell_size)
  share <- tapply(areas$area, areas$unit, sum)
  if (any(share > cell_area + 1e-9)) cli::cli_abort("The establishments' land exceeds the cell area in cell{?s} {.val {names(share)[share > cell_area + 1e-9]}}.")
  y_e <- tapply(areas$y, areas$establishment, function(v) v[1])
  truth <- sum(y_e)
  N_e <- length(y_e)
  by_cell <- split(areas, areas$unit)
  est <- var_est <- interviews <- numeric(n_sim)
  for (b in seq_len(n_sim)) {
    s <- select_units(cells, n = n, size = size, coords = NULL, strata = strata, method = method, replicates = replicates, seed = seed * 10000 + b)
    p <- select_points(s, points_per_cell = points_per_cell, cell_size = cell_size, seed = seed * 10000 + b)
    eh <- expected_hits(areas, s, points_per_cell = points_per_cell, cell_size = cell_size)
    set.seed(seed * 10000 + b)
    hit_e <- vapply(seq_len(nrow(p)), function(i) {
      a <- by_cell[[p$unit[i]]]
      if (is.null(a)) return(NA_character_)
      pr <- a$area / cell_area
      k <- sample.int(nrow(a) + 1L, 1L, prob = c(pr, 1 - sum(pr)))
      if (k > nrow(a)) NA_character_ else a$establishment[k]
    }, character(1))
    ok <- !is.na(hit_e)
    if (sum(ok) == 0) { est[b] <- 0; var_est[b] <- NA; interviews[b] <- 0; next }
    hits <- data.frame(unit = p$unit[ok], establishment = hit_e[ok])
    hits$y <- y_e[hits$establishment]
    hits$expected_hits <- eh$expected_hits[match(hits$establishment, eh$establishment)]
    pe <- point_estimator(hits, s)
    est[b] <- pe$total; var_est[b] <- pe$variance; interviews[b] <- pe$n_establishments
  }
  v <- stats::var(est); n_int <- mean(interviews)
  v_srs <- N_e^2 * (1 - n_int / N_e) * stats::var(as.numeric(y_e)) / n_int
  structure(tibble::tibble(n_sim = n_sim, total = truth, mean_estimate = mean(est), bias = mean(est) - truth,
                           variance = v, cv = sqrt(v) / truth, mean_variance_estimate = mean(var_est, na.rm = TRUE),
                           interviews = n_int, variance_srs = v_srs, deff = v / v_srs),
            class = c("fieldopt_point_deff", "tbl_df", "tbl", "data.frame"), estimates = est)
}
