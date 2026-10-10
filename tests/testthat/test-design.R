small_frame <- function(side = 10, seed = 11) {
  set.seed(seed)
  cells <- expand.grid(x = seq_len(side), y = seq_len(side))
  cells$unit <- paste0("c", seq_len(nrow(cells)))
  list(cells = cells, frame = rbind(data.frame(unit = "depot", x = side / 2 + 0.5, y = side / 2 + 0.5), cells))
}

test_that("systematic point layouts form a grid with one offset and stay uniform", {
  f <- small_frame()
  s <- select_units(f$cells, n = 8, seed = 2)
  p9 <- select_points(s, 9, cell_size = 1, layout = "systematic", seed = 3)
  one <- p9[p9$unit == p9$unit[1], ]
  expect_equal(length(unique(round(one$x, 9))), 3)
  expect_equal(length(unique(round(one$y, 9))), 3)
  expect_equal(diff(sort(unique(one$x))), rep(1 / 3, 2))
  p6 <- select_points(s, 6, cell_size = 1, layout = "systematic", seed = 3)
  one6 <- p6[p6$unit == p6$unit[1], ]
  expect_equal(length(unique(round(one6$x, 9))) * length(unique(round(one6$y, 9))), 6)
  p7 <- select_points(s, 7, cell_size = 1, layout = "systematic", seed = 3)
  expect_equal(sum(p7$unit == p7$unit[1]), 7)
  # marginal uniformity: pooled offsets over many seeds are uniform on the cell
  off <- unlist(lapply(1:200, function(sd) {
    q <- select_points(s, 4, cell_size = 1, layout = "systematic", seed = sd)
    q$x - s$x[match(q$unit, s$unit)]
  }))
  expect_lt(abs(mean(off)), 0.02)
  expect_gt(suppressWarnings(stats::ks.test(off + 0.5, "punif")$p.value), 0.01)
  expect_equal(attr(p9, "layout"), "systematic")
})

test_that("point_design_effect is unbiased and its variance estimate tracks the empirical one", {
  f <- small_frame()
  areas <- rbind(
    data.frame(establishment = paste0(f$cells$unit, "-1"), unit = f$cells$unit, area = 0.5),
    data.frame(establishment = paste0(f$cells$unit, "-2"), unit = f$cells$unit, area = 0.2)
  )
  areas$y <- round(rgamma(nrow(areas), 3, 3 / (10 * areas$area)), 1)
  d <- point_design_effect(f$cells, areas, n = 20, points_per_cell = 6, cell_size = 1, n_sim = 150, seed = 5)
  expect_s3_class(d, "fieldopt_point_deff")
  expect_equal(d$total, sum(tapply(areas$y, areas$establishment, function(v) v[1])))
  expect_lt(abs(d$bias) / d$total, 0.03)
  expect_equal(d$mean_variance_estimate, d$variance, tolerance = 0.4)
  expect_gt(d$deff, 0)
  expect_length(attr(d, "estimates"), 150)
  expect_error(point_design_effect(f$cells, areas[, -4], n = 5, points_per_cell = 2, cell_size = 1, n_sim = 2), "needs a column")
  big <- areas
  big$area <- 0.9
  expect_error(point_design_effect(f$cells, big, n = 5, points_per_cell = 2, cell_size = 1, n_sim = 2), "exceeds the cell area")
})

test_that("routed designs iterate the cost and converge", {
  f <- small_frame()
  model <- field_cost_model(per_travel = 3, per_unit = 40, per_interview = 20, interviews_per_unit = 3)
  ru <- routed_unit_cost(f$frame, "depot", model, n = 12, method = "euclidean", n_rep = 2, iterations = 10)
  expect_named(ru, c("n", "cost_per_unit", "travel_per_unit", "cost_mean", "routes_mean", "n_rep"))
  expect_equal(ru$cost_per_unit, ru$cost_mean / 12)
  ts <- two_stage_design(f$frame, "depot", model,
    m_secondary = 12, s2_between = 9, s2_within = 40,
    target_cv = 0.05, mean = 10, method = "euclidean", n_rep = 2, iterations = 10
  )
  expect_s3_class(ts, "fieldopt_two_stage")
  expect_true(ts$converged)
  expect_equal(ts$history$n[nrow(ts$history)], ts$n)
  expect_equal(ts$c1, ts$history$c1[nrow(ts$history)])
  expect_lte(nrow(ts$history), 6)
  expect_equal(tidy(ts)$units, c(ts$n, ts$n * ts$m))
  expect_equal(glance(ts)$cost, ts$cost)
  domains <- data.frame(domain = c("a", "ab", "b"), size = c(600, 80, 20), mean = c(6, 30, 45), sd = c(5, 20, 35))
  df <- dual_frame_design(f$frame, "depot", model, domains,
    cost_b = 45, deff_a = 1.5, target_cv = 0.05,
    method = "euclidean", n_rep = 2, iterations = 10
  )
  expect_s3_class(df, "fieldopt_dual_frame")
  expect_true(df$converged)
  expect_equal(df$history$n_a[nrow(df$history)], df$n_a)
  expect_equal(nrow(tidy(df)), 2)
  expect_equal(glance(df)$n_a, df$n_a)
  expect_lte(df$cv, 0.05 + 1e-6)
  a <- frame_allocation(data.frame(stratum = c("l", "a"), size = c(2000, 800), sd = c(12, 30), cost = c(40, 180)), budget = 20000)
  expect_equal(sum(tidy(a)$cost_total), attr(a, "cost"))
  expect_equal(sum(tidy(a)$variance), attr(a, "variance"))
  expect_equal(glance(a)$n, sum(a$n))
})
