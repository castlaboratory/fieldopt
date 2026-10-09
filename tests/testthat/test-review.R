# Regression tests from the review of 2026-10-09 ---------------------------------

review_grid <- function() {
  g <- expand.grid(x = 1:8, y = 1:8)
  g$unit <- paste0("c", seq_len(nrow(g)))
  g$size <- 1 + g$y
  g$h <- rep(c("a", "b", "c", "d"), each = 16)
  g
}

test_that("srs refuses a size measure instead of mislabelling the probabilities", {
  g <- review_grid()
  expect_error(select_units(g, 16, size = "size", method = "srs"), "equal probabilities")
  s <- select_units(g, 16, method = "srs", seed = 5)
  expect_equal(unique(s$pi), 0.25)
})

test_that("degenerate frames are refused", {
  g <- review_grid()
  expect_error(select_units(g, n = 2, strata = "h"), "smaller than the number of strata")
  dup <- g; dup$unit[2] <- dup$unit[1]
  expect_error(select_units(dup, 4), "distinct")
  z <- g; z$size <- c(5, 3, rep(0, nrow(g) - 2))
  expect_error(select_units(z, 3, size = "size"), "positive size")
  expect_error(select_units(g, 4, seed = -1), "non-negative")
  expect_error(select_units(g, 4, seed = 1.5), "whole number")
  s <- select_units(g, 4)
  expect_error(select_points(s, 2, 1, seed = -3), "seed")
  expect_error(route_fieldwork(travel_matrix(g[1:5, ], method = "euclidean"), g$unit[2:5], g$unit[1], seed = -1), "seed")
})

test_that("the user's RNG is left untouched", {
  g <- review_grid()
  set.seed(11); before <- stats::runif(1)
  set.seed(11); s <- select_units(g, 10, method = "srs", seed = 3)
  p <- select_points(s, points_per_cell = 3, cell_size = 1, seed = 4)
  after <- stats::runif(1)
  expect_equal(before, after)
  rm(".Random.seed", envir = globalenv())
  s2 <- select_units(g, 10, method = "srs", seed = 3)
  expect_equal(s$sampled, s2$sampled)
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("point_estimator refuses missing values instead of zeroing the cell", {
  g <- review_grid()
  s <- select_units(g, 8, seed = 2)
  sel <- s$unit[s$sampled]
  hits <- data.frame(unit = sel[c(1, 1, 2)], establishment = c("e1", "e2", "e3"), y = c(1, NA, 3), expected_hits = 1)
  expect_error(point_estimator(hits, s), "missing")
  hits$y[2] <- 2
  expect_equal(point_estimator(hits, s)$total, 6)
})

test_that("the designs report convergence honestly", {
  set.seed(3)
  frame <- data.frame(unit = c("depot", paste0("s", 1:30)), x = c(5, runif(30, 0, 10)), y = c(5, runif(30, 0, 10)))
  model <- field_cost_model(per_travel = 3, per_unit = 40, per_interview = 20, interviews_per_unit = 3)
  ts <- two_stage_design(frame, "depot", model, m_secondary = 12, s2_between = 9, s2_within = 40,
                         target_cv = 0.05, mean = 10, method = "euclidean", n_rep = 2, iterations = 10, max_iter = 1)
  expect_false(ts$converged)
  expect_equal(nrow(ts$history), 1)
  domains <- data.frame(domain = c("a", "ab", "b"), size = c(600, 80, 20), mean = c(6, 30, 45), sd = c(5, 20, 35))
  df <- dual_frame_design(frame, "depot", model, domains, cost_b = 45, target_cv = 0.05,
                          method = "euclidean", n_rep = 2, iterations = 10, max_iter = 1)
  expect_false(df$converged)
})

test_that("theta outside [0, 1] is refused", {
  domains <- data.frame(domain = c("a", "ab", "b"), size = c(600, 80, 20), mean = c(6, 30, 45), sd = c(5, 20, 35))
  expect_error(dual_frame_allocation(domains, 200, 40, theta = -0.5, budget = 1e5), "\\[0, 1\\]")
  expect_error(dual_frame_allocation(domains, 200, 40, theta = 1.5, budget = 1e5), "\\[0, 1\\]")
  expect_error(dual_frame_allocation(domains, 200, 40, budget = 10), "budget")
})

test_that("the frontier takes its coordinates from a supplied matrix", {
  set.seed(4)
  frame <- data.frame(unit = c("depot", paste0("s", 1:20)), x = c(5, runif(20, 0, 10)), y = c(5, runif(20, 0, 10)))
  m <- travel_matrix(frame, method = "euclidean")
  cm <- field_cost_model(per_travel = 2)
  f <- cost_variance_frontier(frame, "depot", cm, n_grid = 6, matrix = m, n_rep = 2, iterations = 10)
  expect_equal(f$n, 6)
  m2 <- travel_matrix(frame[-2, ], method = "euclidean")
  expect_error(cost_variance_frontier(frame, "depot", cm, n_grid = 6, matrix = m2, n_rep = 2), "same names")
  expect_error(cost_variance_frontier(frame, "depot", cm, n_grid = 6, matrix = unclass(m), n_rep = 2), "travel_matrix")
})

test_that("two-stage allocation uses a fractional M and meets its target in small populations", {
  a <- two_stage_allocation(5, 20, 4, 25, c1 = 300, c2 = 20, target_variance = 0.05 * (5 * 20)^2)
  expect_lte(a$variance_mean, 0.05 + 1e-12)
  expect_true(a$bounded)
  f <- two_stage_allocation(5000, 12.7, 4, 25, 300, 20, budget = 1e5)
  i <- two_stage_allocation(5000, 12, 4, 25, 300, 20, budget = 1e5)
  expect_false(isTRUE(all.equal(f$m_optimal, i$m_optimal)))
  expect_error(two_stage_allocation(5, 20, 4, 25, 300, 20, budget = 500), "budget")
})

test_that("asymmetric travel matrices are routed and bounded", {
  set.seed(2)
  m <- matrix(runif(81, 1, 10), 9); diag(m) <- 0
  pts <- data.frame(unit = c("depot", paste0("s", 1:8)), x = runif(9), y = runif(9))
  tm <- travel_matrix(pts, method = "euclidean", matrix = m)
  r <- route_fieldwork(tm, paste0("s", 1:8), "depot", iterations = 30)
  expect_gte(r$total, r$lower_bound)
  legs <- tidy(r)
  back <- sum(vapply(split(legs, legs$route), function(d) m[match(d$unit[nrow(d)], pts$unit), 1], numeric(1)))
  expect_equal(sum(legs$leg) + back, r$total)
})

test_that("the new methods exist", {
  g <- review_grid()
  s <- select_units(g, 12, strata = "h", seed = 1)
  expect_s3_class(autoplot(s), "ggplot")
  p <- select_points(s, 2, 1)
  expect_message(print(p), "random points")
  pts <- data.frame(unit = c("depot", paste0("s", 1:8)), x = c(0, runif(8)), y = c(0, runif(8)))
  r <- route_fieldwork(travel_matrix(pts, method = "euclidean"), paste0("s", 1:8), "depot", max_stops = 4, iterations = 20,
                       cost_model = field_cost_model(per_travel = 2))
  expect_equal(glance(r)$cost, r$cost[["total"]])
  expect_equal(nrow(tidy(r)), 8)
  f <- cost_variance_frontier(pts, "depot", field_cost_model(per_travel = 2), n_grid = c(3, 5), method = "euclidean",
                              n_rep = 2, iterations = 10)
  expect_equal(glance(f)$n_grid, 2)
})
