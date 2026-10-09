# Selection of units, estimation and allocation --------------------------------

#' Select units with a spatially balanced or systematic probability sample
#'
#' Draws a probability sample of the units of a frame (segments, grid cells,
#' establishments) with equal or size-proportional inclusion probabilities,
#' within strata when given, by one of three methods:
#'
#' * `"lpm"`: the local pivotal method (Grafström, Lundström and Schelin,
#'   2012), which spreads the sample over the coordinate space so that nearby
#'   units are rarely selected together;
#' * `"systematic"`: systematic sampling with probabilities proportional to
#'   size along a Hilbert curve through the coordinates (a spatially ordered
#'   systematic sample), drawn as `replicates` independent interpenetrating
#'   systematic samples so that a design-based variance can be estimated;
#' * `"srs"`: simple random sampling without replacement.
#'
#' Spatial balance reduces the variance of totals of spatially structured
#' variables and, at the same time, spreads the field work; the cost model and
#' the routing make that tension explicit.
#'
#' @param frame Data frame with one row per unit: coordinate columns (`lat`,
#'   `lon` or `x`, `y`, or those named in `coords`), an optional `size`
#'   column, an optional `unit` column with names and an optional stratum
#'   column.
#' @param n Sample size: a single number (allocated to strata in proportion
#'   to the sum of `size`, or to the number of units when `size` is `NULL`),
#'   or a vector named by stratum.
#' @param size Column of the size measure for probability-proportional-to-size
#'   selection, or `NULL` for equal probabilities within stratum.
#' @param coords Names of the coordinate columns used for spatial balance (any
#'   number of columns for `"lpm"`; exactly two for `"systematic"`).
#' @param strata Column with the stratum of each unit, or `NULL`.
#' @param method `"lpm"`, `"systematic"`, `"srs"` or `"cube"` (balanced
#'   sampling by the cube method of Deville and Tillé 2004, with the fast
#'   flight phase and landing by suppression of variables).
#' @param balance For `"cube"`: names of the columns to balance on (the
#'   inclusion probabilities are always included, so the sample size is
#'   fixed). The Horvitz-Thompson estimates of these columns match their
#'   population totals as closely as the landing allows.
#' @param replicates Number of independent interpenetrating replicates for
#'   `"systematic"` (each a systematic sample of about `n / replicates`
#'   units; replicates may share units). Ignored by the other methods.
#' @param seed Seed.
#' @return The frame as a tibble with columns `pi` (inclusion probability in
#'   the union of the replicates) and `sampled`, of class `fieldopt_sample`,
#'   with attributes `n`, `coords`, `strata`, `method`, `seed` and, for
#'   replicated systematic samples, `replicates` (a logical matrix, one column
#'   per replicate) and `pi_replicate` (inclusion probability within one
#'   replicate).
#' @references Grafström, A., Lundström, N. L. P. and Schelin, L. (2012).
#'   Spatially balanced sampling through the pivotal method. *Biometrics*,
#'   68(2), 514--520.
#' @export
#' @examples
#' set.seed(1)
#' cells <- expand.grid(x = 1:20, y = 1:20)
#' cells$unit <- paste0("c", seq_len(nrow(cells)))
#' cells$intensity <- cut(cells$x + rnorm(400, sd = 3), c(-Inf, 7, 14, Inf),
#'                        c("low", "mid", "high"))
#' cells$size <- c(low = 1, mid = 2, high = 4)[cells$intensity]
#' s <- select_units(cells, n = c(low = 10, mid = 15, high = 25), size = "size",
#'                   strata = "intensity")
#' table(s$intensity, s$sampled)
#' r <- select_units(cells, n = 40, method = "systematic", replicates = 4)
#' dim(attr(r, "replicates"))
select_units <- function(frame, n, size = NULL, coords = NULL, strata = NULL,
                         method = c("lpm", "systematic", "srs", "cube"), replicates = 1, seed = 1, balance = NULL) {
  method <- rlang::arg_match(method)
  if (method == "cube") {
    if (is.null(balance)) cli::cli_abort("{.val cube} needs {.arg balance}: the columns to balance on.")
  } else if (!is.null(balance)) cli::cli_abort("{.arg balance} applies to {.val cube} sampling only.")
  frame <- tibble::as_tibble(frame)
  if (is.null(coords)) coords <- if (all(c("lat", "lon") %in% names(frame))) c("lat", "lon") else if (all(c("x", "y") %in% names(frame))) c("x", "y") else cli::cli_abort("{.arg frame} needs coordinate columns ({.field lat}/{.field lon} or {.field x}/{.field y}) or {.arg coords}.")
  if (!all(coords %in% names(frame))) cli::cli_abort("Coordinate column{?s} {.field {setdiff(coords, names(frame))}} not found.")
  if (method == "systematic" && length(coords) != 2L) cli::cli_abort("{.val systematic} needs exactly two coordinate columns.")
  X <- as.matrix(frame[, coords]); storage.mode(X) <- "double"
  if (anyNA(X)) cli::cli_abort("Coordinates must not be missing.")
  N <- nrow(frame)
  if (!"unit" %in% names(frame)) frame$unit <- paste0("u", seq_len(N))
  if (anyDuplicated(frame$unit)) cli::cli_abort("Unit names in {.field unit} must be distinct.")
  if (!is.null(balance)) {
    miss <- setdiff(balance, names(frame)); if (length(miss)) cli::cli_abort("Balancing column{?s} {.field {miss}} not found.")
    B <- as.matrix(frame[, balance]); storage.mode(B) <- "double"
    if (anyNA(B)) cli::cli_abort("Balancing variables must not be missing.")
  }
  check_seed(seed)
  if (method == "srs" && !is.null(size)) cli::cli_abort(c("{.val srs} selects with equal probabilities.", i = "Drop {.arg size}, or use {.val lpm} or {.val systematic} for selection proportional to size."))
  sz <- if (is.null(size)) rep(1, N) else { if (!size %in% names(frame)) cli::cli_abort("Size column {.field {size}} not found."); as.numeric(frame[[size]]) }
  if (anyNA(sz) || any(sz < 0)) cli::cli_abort("Sizes must be non-negative without missing values.")
  if (!is.numeric(replicates) || length(replicates) != 1L || replicates < 1 || replicates != round(replicates)) cli::cli_abort("{.arg replicates} must be a whole number of at least 1.")
  if (method != "systematic" && replicates > 1) cli::cli_abort("{.arg replicates} applies to {.val systematic} sampling only.")
  if (!is.numeric(n) || anyNA(n) || any(n < 1) || any(n != round(n))) cli::cli_abort("{.arg n} must be whole numbers of at least 1.")
  # strata and allocation
  if (is.null(strata)) {
    h <- factor(rep("all", N))
    if (length(n) != 1L) cli::cli_abort("Without {.arg strata}, {.arg n} must be a single number.")
    n_h <- c(all = unname(n))
  } else {
    if (!strata %in% names(frame)) cli::cli_abort("Stratum column {.field {strata}} not found.")
    h <- factor(frame[[strata]])
    if (anyNA(h)) cli::cli_abort("Strata must not be missing.")
    if (length(n) == 1L && is.null(names(n))) {
      share <- tapply(sz, h, sum)
      if (sum(share) <= 0) share <- table(h)
      if (n < nlevels(h)) cli::cli_abort("{.arg n} = {n} is smaller than the number of strata ({nlevels(h)}); give one size per stratum or a larger {.arg n}.")
      n_h <- largest_remainder(n * share / sum(share), floor_min = 1)
    } else {
      if (is.null(names(n)) || !all(levels(h) %in% names(n))) cli::cli_abort("{.arg n} must be named by stratum: {.val {levels(h)}}.")
      n_h <- n[levels(h)]
    }
  }
  N_h <- table(h)[names(n_h)]
  if (replicates > 1 && any(n_h < replicates)) cli::cli_abort("Every stratum needs at least {.arg replicates} = {replicates} sampled units.")
  too_big <- n_h > N_h
  if (any(too_big)) cli::cli_abort("Sample size exceeds the number of units in strat{?um/a} {.val {names(n_h)[too_big]}}.")
  pi <- numeric(N); sampled <- logical(N)
  rep_mat <- if (replicates > 1) matrix(FALSE, N, replicates) else NULL
  pi_rep <- if (replicates > 1) numeric(N) else NULL
  for (k in seq_along(n_h)) {
    idx <- which(h == names(n_h)[k])
    nk <- as.integer(n_h[k])
    sk <- sz[idx]
    if (sum(sk) <= 0) sk <- rep(1, length(idx))
    if (sum(sk > 0) < nk) cli::cli_abort("Stratum {.val {names(n_h)[k]}} has {sum(sk > 0)} unit{?s} with positive size but {nk} {?is/are} to be sampled.")
    p <- inclusion_probabilities_rs(sk, nk)
    seed_k <- seed * 100 + k
    if (method == "lpm") {
      pi[idx] <- p
      sampled[idx] <- local_pivotal_rs(as.numeric(t(X[idx, , drop = FALSE])), ncol(X), p, seed_k)
    } else if (method == "srs") {
      pi[idx] <- p
      sampled[idx[with_seed(seed_k, sample.int(length(idx), nk))]] <- TRUE
    } else if (method == "cube") {
      pi[idx] <- p
      X_b <- cbind(p, B[idx, , drop = FALSE])  # the probabilities first: they fix the sample size
      sampled[idx] <- cube_rs(as.numeric(t(X_b)), ncol(X_b), p, seed_k)
    } else {
      ord <- hilbert_order_rs(as.numeric(t(X[idx, , drop = FALSE])), 16L)
      m <- matrix(systematic_replicates_rs(ord, p, as.integer(replicates), seed_k), length(idx), replicates, byrow = TRUE)
      if (replicates > 1) {
        rep_mat[idx, ] <- m
        pi_rep[idx] <- p / replicates
        pi[idx] <- 1 - (1 - p / replicates)^replicates
      } else {
        pi[idx] <- p
      }
      sampled[idx] <- rowSums(m) > 0
    }
  }
  frame$pi <- pi; frame$sampled <- sampled
  if (!is.null(rep_mat)) frame$n_replicates <- rowSums(rep_mat)
  structure(frame, class = c("fieldopt_sample", class(frame)), n = n_h, coords = coords, strata = strata,
            method = method, seed = seed, size = size, replicates = rep_mat, pi_replicate = pi_rep)
}

# Largest-remainder rounding of a positive allocation to integers with a floor.
largest_remainder <- function(x, floor_min = 1) {
  total <- round(sum(x))
  base <- pmax(floor(x), floor_min)
  rem <- total - sum(base)
  if (rem > 0) {
    o <- order(x - floor(x), decreasing = TRUE)
    base[o[seq_len(rem)]] <- base[o[seq_len(rem)]] + 1
  } else if (rem < 0) {
    o <- order(x - floor(x))
    k <- 0
    for (i in o) { if (k == -rem) break; if (base[i] > floor_min) { base[i] <- base[i] - 1; k <- k + 1 } }
  }
  stats::setNames(as.integer(base), names(x))
}

#' @export
print.fieldopt_sample <- function(x, ...) {
  n_h <- attr(x, "n")
  cli::cli_text("Sample of {sum(x$sampled)} unit{?s} from {nrow(x)} by {.val {attr(x, 'method')}}{if (!is.null(attr(x, 'replicates'))) paste0(' (', ncol(attr(x, 'replicates')), ' replicates)') else ''}{if (length(n_h) > 1) paste0(', ', length(n_h), ' strata') else ''}.")
  NextMethod()
}

#' Select points inside sampled grid cells
#'
#' For an area frame of square cells (segments) selected with [select_units()],
#' draws `points_per_cell` uniform random points inside each sampled cell. In
#' the field, each point identifies the field (and so the establishment) it
#' falls on; an establishment can be hit several times. The point density of
#' a cell, `pi * points / area`, is what [expected_hits()] and
#' [point_estimator()] need.
#'
#' @param sample A `fieldopt_sample` of cells with coordinate columns giving
#'   the cell centres.
#' @param points_per_cell Points per sampled cell: a single number, a vector
#'   named by stratum (for example more points where agricultural use is more
#'   intense), or the name of a column of the sample.
#' @param cell_size Side of the square cells, in the units of the coordinates
#'   (one number, or `c(dx, dy)`).
#' @param layout `"random"` (independent uniform points) or `"systematic"`
#'   (a regular grid of `k1 x k2 = m` points with one random offset per cell,
#'   which spreads the points inside the cell; each point is still uniform
#'   over the cell, so the density is the same).
#' @param seed Seed.
#' @return A tibble of class `fieldopt_points` with one row per point: `unit`
#'   (the cell), `point`, the two coordinates, `pi_cell`, `points_in_cell` and
#'   `density` (expected points per unit area of the cell).
#' @export
#' @examples
#' cells <- expand.grid(x = 1:10, y = 1:10); cells$unit <- paste0("c", 1:100)
#' s <- select_units(cells, n = 12, seed = 2)
#' p <- select_points(s, points_per_cell = 9, cell_size = 1, layout = "systematic")
#' nrow(p); head(p)
select_points <- function(sample, points_per_cell, cell_size, layout = c("random", "systematic"), seed = 1) {
  layout <- rlang::arg_match(layout)
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  co <- attr(sample, "coords")
  if (length(co) != 2L) cli::cli_abort("Point selection needs two coordinate columns.")
  if (length(cell_size) == 1L) cell_size <- c(cell_size, cell_size)
  if (!is.numeric(cell_size) || length(cell_size) != 2L || any(cell_size <= 0)) cli::cli_abort("{.arg cell_size} must be one or two positive numbers.")
  sel <- sample[sample$sampled, ]
  m <- if (is.character(points_per_cell)) {
    if (!points_per_cell %in% names(sel)) cli::cli_abort("Column {.field {points_per_cell}} not found.")
    as.numeric(sel[[points_per_cell]])
  } else if (!is.null(names(points_per_cell))) {
    st <- attr(sample, "strata")
    if (is.null(st)) cli::cli_abort("A named {.arg points_per_cell} needs a stratified sample.")
    lev <- as.character(sel[[st]])
    if (!all(lev %in% names(points_per_cell))) cli::cli_abort("{.arg points_per_cell} must name every stratum.")
    as.numeric(points_per_cell[lev])
  } else rep(as.numeric(points_per_cell), nrow(sel))
  if (anyNA(m) || any(m < 1) || any(m != round(m))) cli::cli_abort("Points per cell must be whole numbers of at least 1.")
  check_seed(seed)
  rows <- with_seed(seed, lapply(seq_len(nrow(sel)), function(i) {
    k <- m[i]
    if (layout == "random") {
      ua <- stats::runif(k); ub <- stats::runif(k)
    } else {
      k1 <- max(which(k %% seq_len(floor(sqrt(k))) == 0)); k2 <- k %/% k1
      g <- expand.grid(i = seq_len(k2) - 1, j = seq_len(k1) - 1)
      ua <- (g$i + stats::runif(1)) / k2; ub <- (g$j + stats::runif(1)) / k1
    }
    tibble::tibble(unit = sel$unit[i], point = seq_len(k),
                   a = sel[[co[1]]][i] + (ua - 0.5) * cell_size[1],
                   b = sel[[co[2]]][i] + (ub - 0.5) * cell_size[2],
                   pi_cell = sel$pi[i], points_in_cell = k,
                   density = sel$pi[i] * k / prod(cell_size))
  }))
  out <- do.call(rbind, rows)
  names(out)[names(out) == "a"] <- co[1]; names(out)[names(out) == "b"] <- co[2]
  structure(out, class = c("fieldopt_points", class(out)), cell_size = cell_size, coords = co, layout = layout)
}

#' @export
print.fieldopt_points <- function(x, ...) {
  cli::cli_text("{nrow(x)} {attr(x, 'layout')} {cli::qty(nrow(x))}point{?s} in {length(unique(x$unit))} sampled cell{?s} of size {paste(attr(x, 'cell_size'), collapse = ' x ')}.")
  NextMethod()
}

#' Plot a sample of units
#'
#' @param object A `fieldopt_sample`.
#' @param ... Unused.
#' @return A ggplot of the frame with the sampled units highlighted, coloured
#'   by stratum when the sample is stratified, with longitude on the x axis
#'   for geographic coordinates.
#' @exportS3Method ggplot2::autoplot fieldopt_sample
#' @examples
#' cells <- expand.grid(x = 1:12, y = 1:12)
#' cells$h <- ifelse(cells$x <= 6, "west", "east")
#' autoplot(select_units(cells, n = 20, strata = "h", seed = 3))
autoplot.fieldopt_sample <- function(object, ...) {
  co <- attr(object, "coords"); st <- attr(object, "strata")
  geo <- identical(co, c("lat", "lon"))
  d <- tibble::tibble(a = if (geo) object[[co[2]]] else object[[co[1]]], b = if (geo) object[[co[1]]] else object[[co[2]]],
                      sampled = factor(ifelse(object$sampled, "sampled", "not sampled"), c("sampled", "not sampled")),
                      stratum = if (is.null(st)) factor("all") else factor(object[[st]]))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$a, y = .data$b)) +
    ggplot2::geom_point(data = d[!object$sampled, ], ggplot2::aes(colour = .data$stratum), size = 1, alpha = 0.35) +
    ggplot2::geom_point(data = d[object$sampled, ], ggplot2::aes(colour = .data$stratum), size = 2.4) +
    ggplot2::labs(x = if (geo) "longitude" else co[1], y = if (geo) "latitude" else co[2], colour = "stratum",
                  subtitle = paste0(sum(object$sampled), " of ", nrow(object), " units by ", attr(object, "method"))) +
    (if (geo) ggplot2::coord_quickmap() else ggplot2::coord_equal()) +
    ggplot2::theme_minimal() + ggplot2::theme(legend.position = if (is.null(st)) "none" else "bottom")
  p
}

#' Expected number of point hits of each establishment
#'
#' An establishment with agricultural area `area` inside cell `unit` is hit by
#' a point of that cell with expected count `density * area`; summed over the
#' cells it spans, this is the multiplicity factor that [point_estimator()]
#' divides by. Cells outside the sample contribute `pi * points / area` as
#' well, so the expectation is over the whole design; supply `points_per_cell`
#' for them.
#'
#' @param areas Data frame with columns `establishment`, `unit` (cell) and
#'   `area` (agricultural area of the establishment inside that cell, in the
#'   square units of `cell_size`).
#' @param sample The `fieldopt_sample` of cells.
#' @param points_per_cell As in [select_points()], applied to every cell of
#'   the frame.
#' @param cell_size As in [select_points()].
#' @return A tibble with `establishment` and `expected_hits`.
#' @export
expected_hits <- function(areas, sample, points_per_cell, cell_size) {
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  for (col in c("establishment", "unit", "area")) if (!col %in% names(areas)) cli::cli_abort("{.arg areas} needs a column {.field {col}}.")
  if (length(cell_size) == 1L) cell_size <- c(cell_size, cell_size)
  m <- if (is.character(points_per_cell)) {
    if (!points_per_cell %in% names(sample)) cli::cli_abort("Column {.field {points_per_cell}} not found.")
    as.numeric(sample[[points_per_cell]])
  } else if (!is.null(names(points_per_cell))) {
    st <- attr(sample, "strata")
    if (is.null(st)) cli::cli_abort("A named {.arg points_per_cell} needs a stratified sample.")
    lev <- as.character(sample[[st]])
    if (!all(lev %in% names(points_per_cell))) cli::cli_abort("{.arg points_per_cell} must name every stratum.")
    as.numeric(points_per_cell[lev])
  } else rep(as.numeric(points_per_cell), nrow(sample))
  if (anyNA(m) || any(m < 1)) cli::cli_abort("Points per cell must be positive.")
  dens <- stats::setNames(sample$pi * m / prod(cell_size), sample$unit)
  miss <- setdiff(unique(areas$unit), names(dens))
  if (length(miss)) cli::cli_abort("Cell{?s} {.val {miss}} not in the frame.")
  e <- dens[as.character(areas$unit)] * as.numeric(areas$area)
  out <- tapply(e, areas$establishment, sum)
  tibble::tibble(establishment = names(out), expected_hits = as.numeric(out))
}

#' Multiplicity (point) estimator of a total from an area sample of points
#'
#' Each point that hits an establishment contributes `y / expected_hits` of
#' that establishment; the sum over hits is unbiased for the population total
#' whatever the number of times an establishment is hit (the more points fall
#' on an establishment, the larger its contribution, matching its larger
#' chance of selection). The variance is estimated at the cell level
#' (ultimate-cluster approximation): the cell contributions are treated as
#' cell totals and the variance estimator of the cell design is applied
#' (local-mean for `"lpm"`, replicates for replicated systematic samples,
#' simple random sampling otherwise). With replicated systematic samples the
#' expected hits refer to the union of the replicates, so the replicate
#' variance is an approximation.
#'
#' @param hits Data frame with one row per point that hit an establishment:
#'   columns `unit` (cell), `establishment`, `y` (value of the whole
#'   establishment) and `expected_hits` (from [expected_hits()]).
#' @param sample The `fieldopt_sample` of cells.
#' @return A one-row tibble as in [design_variance()], with `n_hits` and
#'   `n_establishments`.
#' @export
point_estimator <- function(hits, sample) {
  for (col in c("unit", "establishment", "y", "expected_hits")) if (!col %in% names(hits)) cli::cli_abort("{.arg hits} needs a column {.field {col}}.")
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  if (any(hits$expected_hits <= 0) || anyNA(hits$expected_hits)) cli::cli_abort("{.field expected_hits} must be positive.")
  if (anyNA(hits$y)) cli::cli_abort("{.field y} of the hits must not be missing.")
  bad <- unique(hits$unit[!hits$unit %in% sample$unit[sample$sampled]])
  if (length(bad)) cli::cli_abort("Hits refer to unsampled cell{?s} {.val {bad}}.")
  contrib <- as.numeric(hits$y) / as.numeric(hits$expected_hits)
  u <- tapply(contrib, factor(hits$unit, levels = sample$unit), sum)
  u[is.na(u)] <- 0  # sampled cells without hits
  # cell totals z such that sum(z / pi) over sampled cells equals the estimate
  z <- as.numeric(u) * sample$pi
  out <- ht_variance(sample, z, total = sum(as.numeric(u)))
  out$n_hits <- nrow(hits); out$n_establishments <- length(unique(hits$establishment))
  out
}

#' Segment estimators of a total from an area sample of segments
#'
#' The three classical ways to attribute establishments to the segments of
#' an area frame (Houseman 1975; Nealon 1984):
#'
#' * `"closed"`: each segment reports what lies inside it (the tracts);
#' * `"open"`: each establishment is attributed entirely to the segment that
#'   holds its headquarters;
#' * `"weighted"`: each establishment is attributed to every segment it
#'   touches in proportion to the share of its land inside the segment.
#'
#' The segment totals are then expanded with the segment design.
#'
#' @param tracts Data frame with one row per (segment, establishment) pair:
#'   `unit` (segment), `establishment`, and, as needed, `y_tract` (value
#'   inside the segment, for `"closed"`), `y_total` (value of the whole
#'   establishment, for `"open"` and `"weighted"`), `headquarters` (logical,
#'   headquarters inside the segment, for `"open"`) and `share` (fraction of
#'   the establishment's land inside the segment, for `"weighted"`).
#' @param sample The `fieldopt_sample` of segments.
#' @param type `"closed"`, `"open"` or `"weighted"`.
#' @return A one-row tibble as in [design_variance()] with a column `type`.
#' @references Nealon, J. P. (1984). Review of the multiple and area frame
#'   estimators. USDA Statistical Reporting Service, Staff Report 80.
#' @export
segment_estimator <- function(tracts, sample, type = c("closed", "open", "weighted")) {
  type <- rlang::arg_match(type)
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  need <- switch(type, closed = c("unit", "y_tract"), open = c("unit", "y_total", "headquarters"), weighted = c("unit", "y_total", "share"))
  for (col in need) if (!col %in% names(tracts)) cli::cli_abort("{.arg tracts} needs a column {.field {col}} for type {.val {type}}.")
  bad <- unique(tracts$unit[!tracts$unit %in% sample$unit[sample$sampled]])
  if (length(bad)) cli::cli_abort("Tracts refer to unsampled segment{?s} {.val {bad}}.")
  v <- switch(type,
    closed = as.numeric(tracts$y_tract),
    open = as.numeric(tracts$y_total) * as.numeric(as.logical(tracts$headquarters)),
    weighted = { sh <- as.numeric(tracts$share); if (any(sh < 0 | sh > 1, na.rm = TRUE)) cli::cli_abort("{.field share} must lie in [0, 1]."); as.numeric(tracts$y_total) * sh })
  if (anyNA(v)) cli::cli_abort("Missing values in the tract data.")
  z <- tapply(v, factor(tracts$unit, levels = sample$unit), sum)
  z[is.na(z)] <- 0
  out <- ht_variance(sample, as.numeric(z))
  out$type <- type
  out
}

# Horvitz-Thompson total of unit values z (zero on unsampled units) with the
# variance estimator that matches the sample's design. Strata are handled
# stratum by stratum (neighbourhoods of the local-mean estimator and the SRS
# formula stay within the stratum) and the variances are summed. With
# replicates, the total is the mean of the replicate estimates and the
# variance their spread, unless `total` is supplied (then only the variance
# comes from the replicates).
ht_variance <- function(sample, z, total = NULL) {
  s <- sample$sampled
  z[!s] <- 0
  X <- as.matrix(sample[, attr(sample, "coords")]); storage.mode(X) <- "double"
  rep_mat <- attr(sample, "replicates")
  strata <- attr(sample, "strata")
  h <- if (is.null(strata)) factor(rep("all", nrow(sample))) else factor(sample[[strata]])
  if (!is.null(rep_mat)) {
    r <- ncol(rep_mat); pr <- attr(sample, "pi_replicate")
    est_k <- vapply(seq_len(r), function(k) sum(z[rep_mat[, k]] / pr[rep_mat[, k]]), numeric(1))
    if (is.null(total)) total <- mean(est_k)
    v <- stats::var(est_k) / r
    method <- "replicates"
  } else {
    if (is.null(total)) total <- ht_total_rs(z, sample$pi, s)
    design <- attr(sample, "method")
    v <- 0; method <- NULL
    for (lev in levels(h)) {
      idx <- which(h == lev)
      if (sum(s[idx]) < 2L) cli::cli_abort("At least two sampled units are needed in every stratum to estimate the variance (stratum {.val {lev}}).")
      equal <- length(unique(sample$pi[idx][s[idx]])) == 1L
      if (identical(design, "srs") && equal) {
        v <- v + srs_variance_rs(z[idx], s[idx], length(idx)); method <- c(method, "srs")
      } else {
        v <- v + local_mean_variance_rs(as.numeric(t(X[idx, , drop = FALSE])), ncol(X), z[idx], sample$pi[idx], s[idx]); method <- c(method, "local-mean")
      }
    }
    method <- paste(unique(method), collapse = "+")
    if (nlevels(h) > 1) method <- paste0("stratified ", method)
  }
  v_srs <- srs_variance_rs(z, s, nrow(sample))
  tibble::tibble(total = total, variance = v, se = sqrt(v), cv = if (total != 0) sqrt(v) / abs(total) else NA_real_,
                 variance_srs = v_srs, n = sum(s), N = nrow(sample), variance_method = method)
}

#' Design-based estimate of a total with its variance
#'
#' Horvitz-Thompson estimate of the population total of `y` from a
#' [select_units()] sample, with the variance estimator that matches the
#' design: the local-mean estimator of Grafström and Schelin (2014) for
#' spatially balanced samples (it needs no joint inclusion probabilities),
#' the variance among replicate estimates for replicated systematic samples,
#' and the simple-random-sampling formula for equal-probability simple random
#' samples. A systematic sample drawn as a single replicate has no unbiased
#' design-based variance estimator; the local-mean estimator is used as the
#' customary approximation. The simple-random-sampling variance of the same
#' sample is always reported as a reference.
#'
#' @param sample A `fieldopt_sample`.
#' @param y Column of the study variable (observed on the sampled units; other
#'   rows may be `NA`).
#' @return A one-row tibble: `total`, `variance`, `se`, `cv`, `variance_srs`,
#'   `n`, `N`, `variance_method`.
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
#' r <- select_units(frame, n = 20, method = "systematic", replicates = 4)
#' design_variance(r, y = "crop")
design_variance <- function(sample, y) {
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  if (!y %in% names(sample)) cli::cli_abort("Column {.field {y}} not found.")
  yy <- as.numeric(sample[[y]]); s <- sample$sampled
  if (anyNA(yy[s])) cli::cli_abort("{.field {y}} is missing for some sampled units.")
  ht_variance(sample, yy)
}

#' Cost-aware allocation across strata
#'
#' Classical optimum allocation with a cost per unit in each stratum (Cochran
#' 1977, Section 5.5): minimum cost for a target variance of the estimated
#' total, or minimum variance for a budget. For two frames with an overlap
#' use [dual_frame_allocation()] instead.
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

#' Spatial balance of a sample
#'
#' The Voronoi measure of Stevens and Olsen (2004): every unit of the frame
#' is assigned to its nearest sampled unit, the inclusion probabilities
#' assigned to each sampled unit are summed, and the balance is the mean
#' squared deviation of those sums from one. Zero is perfect balance; simple
#' random samples give values near one. With strata the measure is computed
#' within each stratum and pooled.
#'
#' @param sample A [select_units()] sample.
#' @param by_stratum Return one value per stratum instead of the pooled one.
#' @return A number, or a named vector with `by_stratum = TRUE`.
#' @references Stevens, D. L. and Olsen, A. R. (2004). Spatially balanced
#'   sampling of natural resources. *Journal of the American Statistical
#'   Association*, 99, 262-278.
#' @export
#' @examples
#' cells <- expand.grid(x = 1:10, y = 1:10)
#' spatial_balance(select_units(cells, n = 10, method = "lpm", seed = 1))
#' spatial_balance(select_units(cells, n = 10, method = "srs", seed = 1))
spatial_balance <- function(sample, by_stratum = FALSE) {
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  X <- as.matrix(sample[, attr(sample, "coords")]); storage.mode(X) <- "double"
  st <- attr(sample, "strata")
  h <- if (is.null(st)) factor(rep("all", nrow(sample))) else factor(sample[[st]])
  parts <- vapply(levels(h), function(lev) {
    idx <- which(h == lev)
    spatial_balance_rs(as.numeric(t(X[idx, , drop = FALSE])), ncol(X), sample$pi[idx], sample$sampled[idx])
  }, numeric(1))
  if (by_stratum) return(parts)
  n_h <- vapply(levels(h), function(lev) sum(sample$sampled[h == lev]), numeric(1))
  sum(parts * n_h) / sum(n_h)
}

#' Ratio estimate of a total with an auxiliary variable
#'
#' The ratio estimator `X * Y_hat / X_hat`, where `X` is the known population
#' total of the auxiliary (the area of the segments, the number of farms from
#' a census), with the variance of the residuals `y - R x` under the design,
#' estimated as in [design_variance()]. The gain over the Horvitz-Thompson
#' estimate is reported.
#'
#' @inheritParams design_variance
#' @param x Column of the auxiliary variable.
#' @param x_total Known population total of `x`; the frame total of the column
#'   when `NULL`.
#' @return A one-row tibble as in [design_variance()] plus `ratio`, `x_total`
#'   and `variance_ht` (the variance of the plain Horvitz-Thompson estimate).
#' @export
#' @examples
#' cells <- expand.grid(x = 1:12, y = 1:12); cells$unit <- paste0("c", 1:144)
#' cells$farmland <- runif(144, 20, 100)
#' cells$crop <- 0.4 * cells$farmland + rnorm(144, sd = 3)
#' s <- select_units(cells, n = 24, seed = 2)
#' ratio_estimator(s, y = "crop", x = "farmland")
ratio_estimator <- function(sample, y, x, x_total = NULL) {
  if (!inherits(sample, "fieldopt_sample")) cli::cli_abort("{.arg sample} must come from {.fn select_units}.")
  for (col in c(y, x)) if (!col %in% names(sample)) cli::cli_abort("Column {.field {col}} not found.")
  yy <- as.numeric(sample[[y]]); xx <- as.numeric(sample[[x]]); s <- sample$sampled
  if (anyNA(yy[s]) || anyNA(xx[s])) cli::cli_abort("{.field {y}} and {.field {x}} must not be missing for sampled units.")
  if (is.null(x_total)) {
    if (anyNA(xx)) cli::cli_abort("{.field {x}} is needed for the whole frame when {.arg x_total} is not given.")
    x_total <- sum(xx)
  }
  y_ht <- ht_total_rs(yy, sample$pi, s); x_ht <- ht_total_rs(xx, sample$pi, s)
  if (x_ht <= 0) cli::cli_abort("The estimated total of {.field {x}} must be positive.")
  R <- y_ht / x_ht
  res <- ht_variance(sample, yy - R * xx, total = 0)
  v <- (x_total / x_ht)^2 * res$variance
  total <- x_total * R
  ht <- ht_variance(sample, yy)
  tibble::tibble(total = total, variance = v, se = sqrt(v), cv = if (total != 0) sqrt(v) / abs(total) else NA_real_,
                 ratio = R, x_total = x_total, variance_ht = ht$variance, variance_srs = res$variance_srs * (x_total / x_ht)^2,
                 n = res$n, N = res$N, variance_method = res$variance_method)
}
