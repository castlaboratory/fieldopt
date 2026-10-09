grid_cells <- function(side = 20, seed = 1) {
  set.seed(seed)
  cells <- expand.grid(x = seq_len(side), y = seq_len(side))
  cells$unit <- paste0("c", seq_len(nrow(cells)))
  cells$intensity <- cut(cells$x + rnorm(nrow(cells), sd = 3), c(-Inf, side * 0.35, side * 0.7, Inf), c("low", "mid", "high"))
  cells$size <- c(low = 1, mid = 2, high = 4)[as.character(cells$intensity)]
  cells$crop <- 5 + 2 * cells$x + rnorm(nrow(cells))
  cells
}

test_that("stratified selection honours the allocation and the probabilities", {
  cells <- grid_cells()
  s <- select_units(cells, n = c(low = 10, mid = 15, high = 25), size = "size", strata = "intensity")
  expect_equal(as.vector(table(s$intensity[s$sampled])[c("low", "mid", "high")]), c(10, 15, 25))
  expect_equal(as.vector(tapply(s$pi, s$intensity, sum)[c("low", "mid", "high")]), c(10, 15, 25), tolerance = 1e-9)
  s2 <- select_units(cells, n = 50, strata = "intensity")
  expect_equal(sum(attr(s2, "n")), 50)
  expect_equal(sum(s2$sampled), 50)
  expect_error(select_units(cells, n = c(low = 1000, mid = 1, high = 1), strata = "intensity"), "exceeds")
  expect_error(select_units(cells, n = c(low = 1, mid = 1), strata = "intensity"), "named by stratum")
  expect_error(select_units(cells, n = 10, strata = "nope"), "not found")
  expect_message(print(s), "3 strata")
})

test_that("systematic sampling along the Hilbert curve has exact size and replicates", {
  cells <- grid_cells()
  r1 <- select_units(cells, n = 40, size = "size", method = "systematic")
  expect_equal(sum(r1$sampled), 40)
  expect_equal(sum(r1$pi), 40, tolerance = 1e-9)
  expect_null(attr(r1, "replicates"))
  r4 <- select_units(cells, n = 40, method = "systematic", replicates = 4, seed = 3)
  m <- attr(r4, "replicates")
  expect_equal(dim(m), c(400, 4))
  expect_true(all(colSums(m) == 10))
  expect_equal(r4$sampled, rowSums(m) > 0)
  expect_equal(attr(r4, "pi_replicate"), rep(0.025, 400))
  expect_equal(r4$pi, rep(1 - 0.975^4, 400))
  # inclusion probabilities over repeated draws
  hits <- Reduce(`+`, lapply(1:300, function(s) select_units(cells, n = 40, size = "size", method = "systematic", seed = s)$sampled))
  expect_equal(cor(hits / 300, r1$pi), 1, tolerance = 0.05)
  expect_lt(max(abs(hits / 300 - r1$pi)), 0.08)
  expect_error(select_units(cells, n = 40, method = "lpm", replicates = 2), "systematic")
  expect_error(select_units(cells, n = 40, method = "systematic", coords = c("x", "y", "size")), "two coordinate")
})

test_that("srs and replicate variances match the design", {
  cells <- grid_cells()
  sr <- select_units(cells, n = 40, method = "srs", seed = 2)
  expect_equal(unique(sr$pi), 0.1)
  d <- design_variance(sr, "crop")
  expect_equal(d$variance, d$variance_srs)
  expect_equal(d$variance_method, "srs")
  yk <- cells$crop[sr$sampled]
  expect_equal(d$variance, 400^2 * (1 - 40 / 400) * stats::var(yk) / 40)
  r4 <- select_units(cells, n = 40, method = "systematic", replicates = 4, seed = 3)
  d4 <- design_variance(r4, "crop")
  expect_equal(d4$variance_method, "replicates")
  truth <- sum(cells$crop)
  est <- sapply(1:200, function(s) {
    d <- design_variance(select_units(cells, n = 40, method = "systematic", replicates = 4, seed = s), "crop")
    c(d$total, d$variance)
  })
  expect_equal(mean(est[1, ]), truth, tolerance = 0.02)
  expect_equal(mean(est[2, ]), var(est[1, ]), tolerance = 0.5)
  # systematic along the curve beats srs on a trending variable
  expect_lt(var(est[1, ]), mean(sapply(1:200, function(s) design_variance(select_units(cells, n = 40, method = "srs", seed = s), "crop")$variance_srs)))
})

test_that("stratified variances are computed within strata", {
  cells <- grid_cells()
  sr <- select_units(cells, n = c(low = 10, mid = 15, high = 25), strata = "intensity", method = "srs", seed = 5)
  d <- design_variance(sr, "crop")
  expect_equal(d$variance_method, "stratified srs")
  # hand computation of the stratified SRS variance of the total
  v <- 0
  for (lev in c("low", "mid", "high")) {
    idx <- sr$intensity == lev; N_h <- sum(idx); n_h <- sum(sr$sampled[idx])
    v <- v + N_h^2 * (1 - n_h / N_h) * var(sr$crop[idx & sr$sampled]) / n_h
  }
  expect_equal(d$variance, v)
  lp <- select_units(cells, n = c(low = 10, mid = 15, high = 25), strata = "intensity", seed = 5)
  expect_equal(design_variance(lp, "crop")$variance_method, "stratified local-mean")
  tiny <- select_units(cells, n = c(low = 1, mid = 5, high = 5), strata = "intensity", seed = 5)
  expect_error(design_variance(tiny, "crop"), "two sampled units")
  expect_error(select_units(cells, n = c(low = 2, mid = 5, high = 5), strata = "intensity", method = "systematic", replicates = 3), "at least")
})
