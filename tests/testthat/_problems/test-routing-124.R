# Extracted from test-routing.R:124

# prequel ----------------------------------------------------------------------
square <- function() {
  pts <- data.frame(unit = c("depot", "a", "b", "c", "d"), x = c(0, 1, 1, 0, 0.5), y = c(0, 0, 1, 1, 0.5))
  travel_matrix(pts, method = "euclidean")
}

# test -------------------------------------------------------------------------
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
f <- route_fieldwork(m, paste0("s", 1:25), "depot", max_stops = 6, service_time = 0.5, iterations = 500)
expect_lt(abs(v$total - f$total) / f$total, 0.05)
expect_message(print(v), "vrpr engine")
