# Service time, schedules, cube, balance, ratio, dual-frame estimation, multivariate allocation, sf

tools_points <- function() {
  set.seed(5)
  data.frame(unit = c("base1", "base2", paste0("s", 1:30)), x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10)))
}

test_that("service time counts towards the route limit and routes are priced per day", {
  m <- travel_matrix(tools_points(), method = "euclidean")
  cm <- field_cost_model(per_travel = 2, per_route = 100, per_unit = 10)
  r0 <- route_fieldwork(m, paste0("s", 1:30), "base1", max_length = 20, iterations = 20, cost_model = cm)
  r1 <- route_fieldwork(m, paste0("s", 1:30), "base1", max_length = 20, service_time = 1.5, iterations = 20, cost_model = cm)
  expect_gt(r1$n_routes, r0$n_routes)
  expect_true(all(r1$durations <= 20 + 1e-9))
  expect_equal(r1$durations, r1$lengths + 1.5 * tabulate(r1$routes$route, r1$n_routes))
  expect_equal(r1$cost[["routes"]], 100 * r1$n_routes)
  expect_equal(r1$cost[["total"]], sum(r1$cost[c("travel", "routes", "units", "interviews")]))
  named <- stats::setNames(rep(1.5, 30), paste0("s", 1:30))
  r2 <- route_fieldwork(m, paste0("s", 1:30), "base1", max_length = 20, service_time = named, iterations = 20)
  expect_equal(r2$routes, r1$routes)
  expect_error(route_fieldwork(m, paste0("s", 1:30), "base1", max_length = 20, service_time = c(s1 = 1, nope = 2)), "Unknown")
  expect_error(route_fieldwork(m, paste0("s", 1:30), "base1", max_length = 3, service_time = 5), "exceeds")
  expect_message(print(r1), "duration")
})

test_that("schedules assign units to bases, teams and days", {
  m <- travel_matrix(tools_points(), method = "euclidean")
  cm <- field_cost_model(per_travel = 2, per_route = 100)
  sch <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 1), days = 4, max_stops = 4,
                            service_time = 1, iterations = 20, cost_model = cm)
  expect_s3_class(sch, "fieldopt_schedule")
  expect_equal(sort(unlist(sch$calendar$units)), sort(paste0("s", 1:30)))
  expect_true(all(sch$calendar$stops <= 4))
  expect_equal(nrow(sch$summary), 2)
  expect_equal(sch$summary$days_needed, unname(vapply(sch$summary$base, function(b) max(sch$calendar$day[sch$calendar$base == b]), numeric(1))))
  expect_equal(sch$fits, all(sch$summary$fits))
  # every unit is served from one base and the per-base route limits hold
  expect_true(all(sch$assignment$base %in% c("base1", "base2")))
  expect_true(all(sch$summary$routes <= sch$summary$teams * 4))
  # a team never has two routes on the same day
  expect_false(anyDuplicated(sch$calendar[, c("team", "day")]) > 0)
  expect_equal(nrow(tidy(sch)), 30)
  g <- glance(sch)
  expect_equal(g$routes, nrow(sch$calendar))
  expect_equal(g$cost, sum(vapply(sch$routes, function(r) r$cost[["total"]], numeric(1))))
  expect_s3_class(autoplot(sch), "ggplot")
  expect_message(print(sch), "Field schedule")
  # a tight fleet at one base pushes units to the other base
  tight <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 3, base2 = 1), days = 2, max_stops = 4, iterations = 50)
  expect_true(tight$fits)
  expect_lte(tight$summary$routes[tight$summary$base == "base2"], 2)
  # a fixed cost per route reduces the number of routes when the limits allow
  cheap <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 2), days = 5, max_stops = 8, iterations = 50)
  dear <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 2), days = 5, max_stops = 8, iterations = 50,
                             cost_model = field_cost_model(per_travel = 1, per_route = 1000))
  expect_lte(nrow(dear$calendar), nrow(cheap$calendar))
  short <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 1, base2 = 1), days = 1, max_stops = 4, iterations = 20)
  expect_false(short$fits)
  expect_true(any(short$summary$days_needed > 1))
  expect_setequal(unlist(short$calendar$units), paste0("s", 1:30))
  expect_error(schedule_fieldwork(m, paste0("s", 1:30), teams = c(2, 1), days = 3), "named")
  expect_error(schedule_fieldwork(m, paste0("s", 1:30), teams = c(base1 = 2), days = 0), "days")
  expect_error(schedule_fieldwork(m, c("base2", "s1"), teams = c(base1 = 1, base2 = 1), days = 3), "base cannot")
  one <- schedule_fieldwork(m, paste0("s", 1:30), teams = 2, bases = "base1", days = 10, max_stops = 5, iterations = 10)
  expect_equal(unique(one$assignment$base), "base1")
  # regions: solved separately and combined
  pts <- tools_points(); reg <- data.frame(unit = pts$unit, region = ifelse(pts$x < 5, "west", "east"))
  reg$region[reg$unit == "base1"] <- "west"; reg$region[reg$unit == "base2"] <- "east"
  by_reg <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 2), days = 6, max_stops = 4, iterations = 20, region = reg)
  expect_setequal(unlist(by_reg$calendar$units), paste0("s", 1:30))
  expect_setequal(by_reg$regions, c("west", "east"))
  expect_true(all(by_reg$assignment$base[by_reg$assignment$region == "west"] == "base1"))
  expect_equal(nrow(by_reg$summary), 2)
  expect_error(schedule_fieldwork(m, paste0("s", 1:30), teams = c(base1 = 2, base2 = 2), days = 6, region = reg[-1, ]), "does not cover")
})

test_that("cube samples are balanced and spatial balance ranks designs", {
  cells <- expand.grid(x = 1:12, y = 1:12); cells$unit <- paste0("c", 1:144); cells$z <- 1 + (seq_len(144) %% 7)
  err_cube <- err_srs <- numeric(30)
  for (k in 1:30) {
    sc <- select_units(cells, n = 24, method = "cube", balance = "z", seed = k)
    expect_equal(sum(sc$sampled), 24)
    err_cube[k] <- abs(sum(cells$z[sc$sampled] / sc$pi[sc$sampled]) - sum(cells$z))
    sr <- select_units(cells, n = 24, method = "srs", seed = k)
    err_srs[k] <- abs(sum(cells$z[sr$sampled] / sr$pi[sr$sampled]) - sum(cells$z))
  }
  expect_lt(mean(err_cube), 0.5 * mean(err_srs))
  expect_equal(attr(sc, "method"), "cube")
  expect_error(select_units(cells, 24, method = "cube"), "balance")
  expect_error(select_units(cells, 24, method = "lpm", balance = "z"), "cube")
  expect_error(select_units(cells, 24, method = "cube", balance = "nope"), "not found")
  cells$h <- rep(c("w", "e"), each = 72)
  st <- select_units(cells, n = 24, strata = "h", method = "cube", balance = "z", seed = 2)
  expect_equal(unname(attr(st, "n")), c(12, 12))
  b_lpm <- spatial_balance(select_units(cells, 24, seed = 1))
  b_srs <- mean(vapply(1:10, function(k) spatial_balance(select_units(cells, 24, method = "srs", seed = k)), numeric(1)))
  expect_lt(b_lpm, b_srs)
  expect_named(spatial_balance(st, by_stratum = TRUE), c("e", "w"))
})

test_that("the ratio estimator uses the auxiliary", {
  set.seed(3)
  cells <- expand.grid(x = 1:12, y = 1:12); cells$unit <- paste0("c", 1:144)
  cells$farmland <- runif(144, 20, 100); cells$crop <- 0.4 * cells$farmland + rnorm(144, sd = 2)
  ests <- vapply(1:40, function(k) ratio_estimator(select_units(cells, n = 24, seed = k), "crop", "farmland")$total, numeric(1))
  expect_lt(abs(mean(ests) - sum(cells$crop)) / sum(cells$crop), 0.02)
  r <- ratio_estimator(select_units(cells, n = 24, seed = 1), "crop", "farmland")
  expect_lt(r$variance, r$variance_ht)
  expect_equal(r$x_total, sum(cells$farmland))
  expect_equal(r$total, r$ratio * r$x_total)
  r2 <- ratio_estimator(select_units(cells, n = 24, seed = 1), "crop", "farmland", x_total = 7000)
  expect_equal(r2$total, r2$ratio * 7000)
  expect_error(ratio_estimator(select_units(cells, n = 24, seed = 1), "crop", "nope"), "not found")
})

test_that("dual-frame estimators are unbiased and screening drops the overlap of frame A", {
  set.seed(7)
  cells <- expand.grid(x = 1:12, y = 1:12); cells$unit <- paste0("c", 1:144)
  cells$domain <- ifelse(runif(144) < 0.2, "ab", "a"); cells$yv <- ifelse(cells$domain == "ab", 80, 10) + rnorm(144, sd = 3)
  # the list holds the same overlap units (same values) plus units of its own
  ab <- cells[cells$domain == "ab", ]
  lst <- data.frame(unit = c(paste0("l", seq_len(nrow(ab))), paste0("b", 1:11)), x = runif(nrow(ab) + 11), y = runif(nrow(ab) + 11),
                    domain = rep(c("ab", "b"), c(nrow(ab), 11)), yv = c(ab$yv, 120 + rnorm(11, sd = 5)))
  truth <- sum(cells$yv) + sum(lst$yv[lst$domain == "b"])
  est <- t(vapply(1:60, function(k) {
    sa <- select_units(cells, n = 30, seed = k); sb <- select_units(lst, n = 15, method = "srs", seed = k)
    h <- dual_frame_estimator(sa, sb, "yv", "domain"); f <- dual_frame_estimator(sa, sb, "yv", "domain", estimator = "fuller-burmeister")
    s <- dual_frame_estimator(sa, sb, "yv", "domain", theta = "screening")
    c(h$total, f$total, s$total, h$variance, h$theta)
  }, numeric(5)))
  for (j in 1:3) expect_lt(abs(mean(est[, j]) - truth) / truth, 0.03)
  # the variance estimate is of the order of the empirical variance
  expect_lt(abs(log(mean(est[, 4]) / stats::var(est[, 1]))), log(2.5))
  expect_true(all(est[, 5] >= 0 & est[, 5] <= 1))
  sa <- select_units(cells, n = 30, seed = 1); sb <- select_units(lst, n = 15, method = "srs", seed = 1)
  s <- dual_frame_estimator(sa, sb, "yv", "domain", theta = "screening")
  expect_equal(s$total, s$y_a + s$y_ab_b + s$y_b)
  expect_equal(s$theta, 0); expect_true(s$theta_fixed)
  h5 <- dual_frame_estimator(sa, sb, "yv", "domain", theta = 0.5)
  expect_equal(h5$total, h5$y_a + 0.5 * h5$y_ab_a + 0.5 * h5$y_ab_b + h5$y_b)
  expect_error(dual_frame_estimator(sa, sb, "yv", "domain", theta = 2), "\\[0, 1\\]")
  bad <- sb; bad$domain[bad$sampled][1] <- "a"
  expect_error(dual_frame_estimator(sa, bad, "yv", "domain"), "frame B")
  expect_error(dual_frame_estimator(sa, sb, "nope", "domain"), "not found")
})

test_that("multivariate allocation meets every target at minimum cost", {
  strata <- data.frame(stratum = c("high", "mid", "low"), size = c(300, 800, 2000), cost = c(250, 180, 150),
                       sd_corn = c(40, 25, 8), sd_cattle = c(15, 30, 12))
  ma <- multivariate_allocation(strata, sd = c("sd_corn", "sd_cattle"), target_cv = c(0.05, 0.08), totals = c(90000, 60000))
  expect_s3_class(ma, "fieldopt_multi_allocation")
  tv <- (c(0.05, 0.08) * c(90000, 60000))^2
  expect_true(all(attr(ma, "attained") <= tv * (1 + 1e-6)))
  expect_equal(attr(ma, "cost"), sum(ma$cost * ma$n))
  # a single variable reproduces frame_allocation
  one <- multivariate_allocation(strata, sd = "sd_corn", target_variance = tv[1])
  uni <- frame_allocation(data.frame(size = strata$size, sd = strata$sd_corn, cost = strata$cost), target_variance = tv[1])
  expect_equal(one$n, uni$n)
  # meeting both costs at least as much as either alone
  two <- multivariate_allocation(strata, sd = "sd_cattle", target_variance = tv[2])
  expect_gte(attr(ma, "cost"), max(attr(one, "cost"), attr(two, "cost")) - 1e-9)
  expect_equal(nrow(glance(ma)), 2)
  expect_equal(tidy(ma)$cost_total, ma$cost * ma$n)
  expect_message(print(ma), "binding")
  expect_error(multivariate_allocation(strata, sd = "sd_corn", target_cv = 0.05), "totals")
  expect_error(multivariate_allocation(strata, sd = c("sd_corn", "sd_cattle"), target_variance = 1), "One target")
})

test_that("spatial frames go in and out", {
  skip_if_not_installed("sf")
  sq <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)))), crs = 4326)
  g <- sf::st_sf(crop = 1:9, geometry = sf::st_make_grid(sq, n = 3))
  f <- as_frame(g)
  expect_named(f, c("unit", "lat", "lon", "area", "crop"))
  expect_equal(nrow(f), 9)
  expect_true(all(f$lat > 0 & f$lat < 1))
  expect_gt(f$area[1], 1000)
  s <- select_units(f, 3, seed = 1)
  back <- as_sf(s, g)
  expect_s3_class(back, "sf")
  expect_equal(nrow(back), 9)
  expect_equal(back$sampled, s$sampled)
  expect_identical(as_frame(data.frame(a = 1)), tibble::tibble(a = 1))
  p <- sf::st_sf(id = c("p", "q"), geometry = sf::st_sfc(sf::st_point(c(-35, -8)), sf::st_point(c(-34, -7)), crs = 4326))
  fp <- as_frame(p, unit = "id")
  expect_equal(fp$unit, c("p", "q")); expect_false("area" %in% names(fp))
  expect_error(as_sf(data.frame(x = 1), g), "unit")
  expect_error(as_frame(sf::st_set_crs(g, NA)), "reference system")
})
