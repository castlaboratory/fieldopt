square <- function() {
  pts <- data.frame(unit = c("depot", "a", "b", "c", "d"), x = c(0, 1, 1, 0, 0.5), y = c(0, 0, 1, 1, 0.5))
  travel_matrix(pts, method = "euclidean")
}

test_that("a single route visits every unit once and is near the lower bound", {
  m <- square()
  r <- route_fieldwork(m, units = c("a", "b", "c", "d"), depot = "depot", iterations = 30)
  expect_s3_class(r, "fieldopt_routes")
  expect_equal(r$n_routes, 1)
  expect_setequal(r$routes$unit, c("a", "b", "c", "d"))
  expect_equal(nrow(r$routes), 4)
  expect_equal(r$total, sum(r$lengths))
  expect_gte(r$total, r$lower_bound - 1e-9)
  # optimum of this instance is 3 + sqrt(2) (the square plus a detour through the centre)
  expect_lte(r$total, 3 + sqrt(2) + 1e-6)
  expect_message(print(r), "1 route")
})

test_that("limits split the tour into feasible routes", {
  m <- square()
  r <- route_fieldwork(m, units = c("a", "b", "c", "d"), depot = "depot", max_stops = 2, iterations = 30)
  expect_equal(r$n_routes, 2)
  expect_true(all(table(r$routes$route) <= 2))
  r2 <- route_fieldwork(m, units = c("a", "b", "c", "d"), depot = "depot", max_length = 3, iterations = 30)
  expect_true(all(r2$lengths <= 3 + 1e-9))
  expect_gte(r2$n_routes, 2)
  expect_setequal(r2$routes$unit, c("a", "b", "c", "d"))
  expect_error(route_fieldwork(m, c("a", "b"), "depot", max_length = 1), "and back exceeds")
})

test_that("indices, names and the cost model are handled", {
  m <- square()
  r1 <- route_fieldwork(m, units = 2:5, depot = 1, iterations = 10)
  r2 <- route_fieldwork(m, units = c("a", "b", "c", "d"), depot = "depot", iterations = 10)
  expect_equal(r1$total, r2$total)
  expect_error(route_fieldwork(m, c("a", "zz"), "depot"), "Unknown units")
  expect_error(route_fieldwork(m, c("a", "a"), "depot"), "distinct")
  expect_error(route_fieldwork(m, c("a", "depot"), "depot"), "depot cannot")
  expect_error(route_fieldwork(unclass(m), "a", "depot"), "travel_matrix")
  cm <- field_cost_model(per_travel = 10, per_unit = 1)
  r3 <- route_fieldwork(m, c("a", "b"), "depot", iterations = 10, cost_model = cm)
  expect_equal(unname(r3$cost[["total"]]), 10 * r3$total + 2)
  expect_message(print(r3), "Cost")
})

test_that("routes are deterministic in the seed and plot", {
  set.seed(1)
  pts <- data.frame(unit = c("depot", paste0("s", 1:15)), x = c(5, runif(15, 0, 10)), y = c(5, runif(15, 0, 10)))
  m <- travel_matrix(pts, method = "euclidean")
  a <- route_fieldwork(m, paste0("s", 1:15), "depot", max_stops = 6, iterations = 40, seed = 7)
  b <- route_fieldwork(m, paste0("s", 1:15), "depot", max_stops = 6, iterations = 40, seed = 7)
  expect_identical(a$routes, b$routes)
  expect_s3_class(autoplot(a), "ggplot")
})

test_that("geographic routes plot longitude on x and a degenerate bound gives no gap", {
  pts <- data.frame(unit = c("depot", "a", "b", "c"), lat = c(-8.05, -8.10, -8.00, -8.12), lon = c(-34.90, -34.95, -34.85, -34.80))
  r <- route_fieldwork(travel_matrix(pts), c("a", "b", "c"), "depot", iterations = 10)
  p <- autoplot(r)
  expect_equal(p$labels$x %||% ggplot2::get_labs(p)$x, "longitude")
  same <- data.frame(unit = c("depot", "a"), x = c(0, 0), y = c(0, 0))
  r0 <- route_fieldwork(travel_matrix(same, method = "euclidean"), "a", "depot", iterations = 5)
  expect_true(is.na(r0$gap))
  expect_true(r0$optimal)
  expect_message(print(r0), "proven optimal")
})

test_that("small instances are solved exactly and capacity is respected", {
  set.seed(4)
  pts <- data.frame(unit = c("depot", paste0("s", 1:7)), x = c(5, runif(7, 0, 10)), y = c(5, runif(7, 0, 10)))
  m <- travel_matrix(pts, method = "euclidean")
  r <- route_fieldwork(m, paste0("s", 1:7), "depot", max_stops = 3, iterations = 5)
  expect_true(r$optimal)
  expect_equal(r$lower_bound, r$total)
  expect_true(glance(r)$optimal)
  # brute force: every permutation split greedily into routes of at most 3 stops is a feasible solution
  perms <- function(v) if (length(v) <= 1) list(v) else do.call(c, lapply(seq_along(v), function(i) lapply(perms(v[-i]), function(p) c(v[i], p))))
  mm <- unclass(m)
  best <- Inf
  for (p in perms(paste0("s", 1:7))) {
    for (cut in list(c(3, 3, 1), c(3, 2, 2), c(2, 3, 2), c(2, 2, 3), c(3, 1, 3), c(1, 3, 3))) {
      idx <- 0
      tot <- 0
      for (k in cut) {
        r_ <- p[idx + seq_len(k)]
        idx <- idx + k
        tot <- tot + mm["depot", r_[1]] + sum(mm[cbind(r_[-k], r_[-1])]) + mm[r_[k], "depot"]
      }
      best <- min(best, tot)
    }
  }
  expect_equal(r$total, best)
  # capacity: demand 2 per unit, capacity 5 -> at most two units per route
  rc <- route_fieldwork(m, paste0("s", 1:7), "depot", demand = 2, capacity = 5, iterations = 5)
  expect_true(all(rc$loads <= 5))
  expect_true(all(table(rc$routes$route) <= 2))
  expect_error(route_fieldwork(m, paste0("s", 1:7), "depot", demand = 6, capacity = 5), "exceeds")
  # larger instance: the genetic search stays within the bound and finds the TSPLIB-like optimum of a grid
  g <- expand.grid(x = 1:5, y = 1:4)
  g$unit <- c("depot", paste0("g", 2:20))
  rg <- route_fieldwork(travel_matrix(g, method = "euclidean"), paste0("g", 2:20), "depot", iterations = 200)
  expect_equal(rg$total, 20) # a Hamiltonian cycle on a 5 x 4 lattice with unit steps
  expect_true(rg$optimal)
  # the certificate proves a random 30-unit tour optimal and is off when asked
  set.seed(8)
  p30 <- data.frame(unit = c("depot", paste0("s", 1:30)), x = c(5, runif(30, 0, 10)), y = c(5, runif(30, 0, 10)))
  m30 <- travel_matrix(p30, method = "euclidean")
  r30 <- route_fieldwork(m30, paste0("s", 1:30), "depot", iterations = 300, certify = 5)
  expect_true(r30$optimal)
  expect_equal(r30$lower_bound, r30$total)
  r30b <- route_fieldwork(m30, paste0("s", 1:30), "depot", iterations = 300, certify = 0)
  expect_lte(r30b$lower_bound, r30b$total)
  expect_gte(r30b$total, r30$total - 1e-9)
  expect_error(route_fieldwork(m30, paste0("s", 1:30), "depot", certify = -1), "certify")
})


test_that("a time limit stops the search and the vrpr engine gives the same kind of result", {
  set.seed(9)
  pts <- data.frame(unit = c("depot", paste0("s", 1:25)), x = c(5, runif(25, 0, 10)), y = c(5, runif(25, 0, 10)))
  m <- travel_matrix(pts, method = "euclidean")
  t0 <- Sys.time()
  r <- route_fieldwork(m, paste0("s", 1:25), "depot", max_stops = 6, time_limit = 0.5)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
  expect_setequal(r$routes$unit, paste0("s", 1:25))
  expect_error(route_fieldwork(m, paste0("s", 1:25), "depot", time_limit = -1), "positive")
  skip_if_not_installed("vrpr")
  cm <- field_cost_model(per_travel = 2, per_route = 10)
  v <- route_fieldwork(m, paste0("s", 1:25), "depot", max_stops = 6, service_time = 0.5, engine = "vrpr", time_limit = 1, cost_model = cm)
  expect_s3_class(v, "fieldopt_routes")
  expect_equal(v$engine, "vrpr")
  expect_setequal(v$routes$unit, paste0("s", 1:25))
  expect_true(all(table(v$routes$route) <= 6))
  expect_equal(v$durations, v$lengths + 0.5 * tabulate(v$routes$route, v$n_routes))
  expect_true(is.na(v$lower_bound))
  expect_true(is.na(v$gap))
  expect_false(v$optimal)
  expect_equal(v$cost[["total"]], 2 * v$total + 10 * v$n_routes)
  # both engines reach the same travel within a few percent on this instance
  f <- route_fieldwork(m, paste0("s", 1:25), "depot", max_stops = 6, service_time = 0.5, iterations = 500)
  expect_lt(abs(v$total - f$total) / f$total, 0.05)
  expect_message(print(v), "vrpr\\s+engine")
  expect_error(route_fieldwork(m, paste0("s", 1:25), "depot", max_stops = 6, capacity = 10, demand = 2, engine = "vrpr"), "one of")
  # multi-depot schedule solved jointly
  pts2 <- rbind(pts, data.frame(unit = "base2", x = 9, y = 9))
  m2 <- travel_matrix(pts2, method = "euclidean")
  sch <- schedule_fieldwork(m2, paste0("s", 1:25), teams = c(depot = 1, base2 = 1), days = 3, max_stops = 5, engine = "vrpr", time_limit = 1)
  expect_equal(sch$engine, "vrpr")
  expect_setequal(unlist(sch$calendar$units), paste0("s", 1:25))
  expect_true(all(sch$calendar$stops <= 5))
  expect_true(all(sch$summary$routes <= 3))
})
