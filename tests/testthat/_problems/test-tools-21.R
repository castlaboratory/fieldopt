# Extracted from test-tools.R:21

# prequel ----------------------------------------------------------------------
tools_points <- function() {
  set.seed(5)
  data.frame(unit = c("base1", "base2", paste0("s", 1:30)), x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10)))
}

# test -------------------------------------------------------------------------
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
