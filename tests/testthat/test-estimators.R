grid_cells <- function(side = 20, seed = 1) {
  set.seed(seed)
  cells <- expand.grid(x = seq_len(side), y = seq_len(side))
  cells$unit <- paste0("c", seq_len(nrow(cells)))
  cells$intensity <- cut(cells$x + rnorm(nrow(cells), sd = 3), c(-Inf, side * 0.35, side * 0.7, Inf), c("low", "mid", "high"))
  cells$crop <- 5 + 2 * cells$x + rnorm(nrow(cells))
  cells
}
ppc <- c(low = 3, mid = 6, high = 9)

test_that("select_points draws points inside the sampled cells with the right density", {
  cells <- grid_cells()
  s <- select_units(cells, n = c(low = 10, mid = 15, high = 25), strata = "intensity")
  p <- select_points(s, points_per_cell = ppc, cell_size = 1)
  expect_s3_class(p, "fieldopt_points")
  expect_equal(nrow(p), sum(ppc[as.character(s$intensity[s$sampled])]))
  ctr <- s[match(p$unit, s$unit), c("x", "y")]
  expect_true(all(abs(p$x - ctr$x) <= 0.5 & abs(p$y - ctr$y) <= 0.5))
  expect_equal(p$density, p$pi_cell * p$points_in_cell)
  p2 <- select_points(s, points_per_cell = 4, cell_size = c(1, 2))
  expect_equal(nrow(p2), 4 * sum(s$sampled))
  expect_error(select_points(s, points_per_cell = 0, cell_size = 1), "at least 1")
  expect_error(select_points(cells, 1, 1), "select_units")
})

test_that("the multiplicity estimator is unbiased for the total", {
  cells <- grid_cells()
  # one establishment per cell, occupying 60% of it; hits land on it with probability 0.6
  areas <- data.frame(establishment = paste0("e", cells$unit), unit = cells$unit, area = 0.6)
  truth <- sum(cells$crop)
  one <- function(seed) {
    s <- select_units(cells, n = c(low = 10, mid = 15, high = 25), strata = "intensity", seed = seed)
    p <- select_points(s, points_per_cell = ppc, cell_size = 1, seed = seed)
    eh <- expected_hits(areas, s, points_per_cell = ppc, cell_size = 1)
    set.seed(seed + 1000)
    hit <- runif(nrow(p)) < 0.6
    hits <- data.frame(unit = p$unit[hit], establishment = paste0("e", p$unit[hit]))
    hits$y <- cells$crop[match(hits$unit, cells$unit)]
    hits$expected_hits <- eh$expected_hits[match(hits$establishment, eh$establishment)]
    e <- point_estimator(hits, s)
    c(e$total, e$variance)
  }
  est <- sapply(1:150, one)
  expect_equal(mean(est[1, ]), truth, tolerance = 0.02)
  expect_equal(mean(est[2, ]), var(est[1, ]), tolerance = 0.6)
  s <- select_units(cells, n = 50, seed = 1)
  eh <- expected_hits(areas, s, points_per_cell = 9, cell_size = 1)
  expect_equal(eh$expected_hits, rep(0.125 * 9 * 0.6, 400))
  expect_error(point_estimator(data.frame(unit = "zz", establishment = "e", y = 1, expected_hits = 1), s), "unsampled|needs")
})

test_that("segment estimators reduce to the HT total of the segment values", {
  cells <- grid_cells()
  s <- select_units(cells, n = 50, seed = 4)
  sel <- s$unit[s$sampled]
  # two establishments per segment: one with headquarters inside holding 70% of its land there
  tracts <- rbind(
    data.frame(unit = sel, establishment = paste0(sel, "-a"), y_tract = 0.7 * 10, y_total = 10, headquarters = TRUE, share = 0.7),
    data.frame(unit = sel, establishment = paste0(sel, "-b"), y_tract = 0.3 * 20, y_total = 20, headquarters = FALSE, share = 0.3))
  closed <- segment_estimator(tracts, s, "closed")
  open <- segment_estimator(tracts, s, "open")
  weighted <- segment_estimator(tracts, s, "weighted")
  expect_equal(closed$total, 400 * 13)
  expect_equal(open$total, 400 * 10)
  expect_equal(weighted$total, 400 * 13)
  expect_equal(closed$type, "closed")
  expect_error(segment_estimator(tracts[, c("unit", "y_tract")], s, "open"), "y_total")
  tracts$share[1] <- 2
  expect_error(segment_estimator(tracts, s, "weighted"), "share")
})
