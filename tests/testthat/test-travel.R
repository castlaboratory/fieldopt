test_that("haversine and euclidean matrices are symmetric with zero diagonal", {
  pts <- data.frame(unit = c("depot", "a", "b"), lat = c(-8.05, -8.10, -8.00), lon = c(-34.90, -34.95, -34.85))
  m <- travel_matrix(pts)
  expect_s3_class(m, "fieldopt_matrix")
  expect_equal(dim(m), c(3, 3))
  expect_equal(diag(m), c(depot = 0, a = 0, b = 0))
  expect_equal(unclass(m)[1, 2], unclass(m)[2, 1])
  # Recife to a point 0.05 degrees south is about 5.6 km
  expect_equal(unclass(m)["depot", "a"], 7.82, tolerance = 0.01)
  e <- travel_matrix(data.frame(x = c(0, 3), y = c(0, 4)), method = "euclidean")
  expect_equal(unclass(e)[1, 2], 5)
  expect_equal(rownames(e), c("u1", "u2"))
  expect_equal(attr(e, "unit"), "distance")
})

test_that("supplied matrices are wrapped and validated", {
  pts <- data.frame(unit = c("d", "a"), x = c(0, 1), y = c(0, 0))
  net <- matrix(c(0, 12, 12, 0), 2)
  m <- travel_matrix(pts, method = "euclidean", matrix = net, unit = "min")
  expect_equal(unclass(m)[1, 2], 12)
  expect_equal(attr(m, "method"), "supplied")
  expect_equal(attr(m, "unit"), "min")
  expect_error(travel_matrix(pts, method = "euclidean", matrix = matrix(0, 3, 3)), "2 x 2")
  expect_error(travel_matrix(pts, method = "euclidean", matrix = -net), "non-negative")
  expect_error(travel_matrix(data.frame(unit = c("a", "a"), x = 1:2, y = 1:2), method = "euclidean"), "distinct")
  expect_error(travel_matrix(data.frame(x = 1, y = 1)), "lat")
  expect_message(print(m), "Travel matrix")
})

test_that("the cost model prices travel, units and interviews", {
  cm <- field_cost_model(per_travel = 2, per_unit = 30, per_interview = 10, interviews_per_unit = 4, currency = "BRL")
  expect_s3_class(cm, "field_cost_model")
  cost <- fieldopt:::cost_of(cm, travel_total = 100, units_visited = 5, unit_index = 1:5)
  expect_equal(unname(cost[c("travel", "units", "interviews", "total")]), c(200, 150, 200, 550))
  f <- field_cost_model(1, 0, 10, interviews_per_unit = function(i) i)
  expect_equal(unname(fieldopt:::cost_of(f, 0, 3, c(2, 5, 9))[["interviews"]]), 160)
  expect_error(field_cost_model(per_travel = -1), "non-negative")
  expect_message(print(cm), "BRL")
})

test_that("the detour factor scales straight-line distances", {
  pts <- data.frame(unit = c("d", "a"), x = c(0, 3), y = c(0, 4))
  m1 <- travel_matrix(pts, method = "euclidean")
  m13 <- travel_matrix(pts, method = "euclidean", detour = 1.3)
  expect_equal(unclass(m13)[1, 2], 6.5)
  expect_equal(attr(m13, "detour"), 1.3)
  expect_message(print(m13), "x 1.3")
  expect_error(travel_matrix(pts, method = "euclidean", detour = 0.8), "at least 1")
  expect_warning(travel_matrix(pts, method = "euclidean", matrix = matrix(c(0, 1, 1, 0), 2), detour = 1.2), "ignored")
})

test_that("the OSRM connector assembles blocks, sets units and reports snapping", {
  skip_if_not_installed("osrm")
  pts <- data.frame(unit = paste0("u", 1:7), lat = -8 - (1:7) / 100, lon = -35 + (1:7) / 100)
  calls <- 0
  fake <- function(src, dst = src, loc, exclude, measure = "duration", osrm.server = NULL, osrm.profile = NULL) {
    calls <<- calls + 1
    i <- as.integer(sub("u", "", rownames(src)))
    j <- as.integer(sub("u", "", rownames(dst)))
    d <- outer(i, j, function(a, b) abs(a - b) * 10)
    list(
      durations = if (measure == "duration") d else NULL, distances = if (measure == "distance") d / 1000 * 60 else NULL,
      sources = data.frame(lon = src$lon, lat = src$lat, snap = i / 10)
    )
  }
  testthat::local_mocked_bindings(osrmTable = fake, .package = "osrm")
  m <- travel_matrix(pts, method = "osrm", block = 3)
  expect_equal(calls, 9)
  expect_equal(unclass(m)[2, 6], 40)
  expect_equal(unclass(m)["u7", "u1"], 60)
  expect_equal(diag(unclass(m)), rep(0, 7), ignore_attr = TRUE)
  expect_equal(attr(m, "unit"), "min")
  expect_equal(attr(m, "method"), "osrm")
  expect_equal(attr(m, "snap"), (1:7) / 10)
  expect_message(print(m), "0.7 km")
  md <- travel_matrix(pts, method = "osrm", measure = "distance", block = 10)
  expect_equal(attr(md, "unit"), "km")
  expect_equal(unclass(md)[1, 2], 0.6)
  expect_warning(travel_matrix(pts, method = "osrm", detour = 1.2, block = 10), "ignored")
  # unreachable pair
  fake_na <- function(src, dst = src, ...) {
    d <- matrix(1, nrow(src), nrow(dst))
    d[1, ] <- NA
    list(durations = d, sources = data.frame(snap = 0))
  }
  testthat::local_mocked_bindings(osrmTable = fake_na, .package = "osrm")
  expect_error(travel_matrix(pts, method = "osrm", block = 10), "no route")
  expect_error(travel_matrix(pts[, c("unit", "lat")], method = "osrm"), "lon")
})

test_that("the OSRM demo server answers a tiny query", {
  skip_on_cran()
  skip_if_not_installed("osrm")
  skip_if_offline()
  pts <- data.frame(unit = c("a", "b"), lat = c(-8.0476, -8.0631), lon = c(-34.8770, -34.8711))
  m <- tryCatch(travel_matrix(pts, method = "osrm"), error = function(e) NULL)
  skip_if(is.null(m), "OSRM demo server not reachable")
  expect_gt(unclass(m)[1, 2], 0)
  expect_equal(attr(m, "unit"), "min")
})
