# The calendar as an integer programme (needs highs)

calendar_fixture <- function() {
  set.seed(5)
  pts <- data.frame(unit = c("base1", "base2", paste0("s", 1:30)), x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10)))
  m <- travel_matrix(pts, method = "euclidean")
  schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 1), days = 5, max_stops = 4, iterations = 30)
}

test_that("the integer programme reproduces the calendar and honours the constraints", {
  skip_if_not_installed("highs")
  sch <- calendar_fixture()
  c1 <- schedule_calendar(sch)
  expect_s3_class(c1, "fieldopt_schedule")
  expect_equal(c1$solver, "highs")
  expect_setequal(unlist(c1$calendar$units), paste0("s", 1:30))
  expect_equal(c1$summary$days_needed, sch$summary$days_needed) # one route per team-day: the greedy rule was already optimal
  expect_false(anyDuplicated(c1$calendar[, c("team", "day")]) > 0)
  # availability
  off <- data.frame(team = "base1-1", day = 1, available = FALSE)
  c2 <- schedule_calendar(sch, availability = off)
  expect_false(any(c2$calendar$team == "base1-1" & c2$calendar$day == 1))
  # fixed team and day
  fx <- data.frame(base = "base2", route = 1, team = "base2-1", day = 3)
  c3 <- schedule_calendar(sch, fixed = fx)
  row <- c3$calendar[c3$calendar$base == "base2" & c3$calendar$route == 1, ]
  expect_equal(row$team, "base2-1")
  expect_equal(row$day, 3L)
  # precedence
  bf <- data.frame(base = "base1", route = 2, base_after = "base1", route_after = 1)
  c4 <- schedule_calendar(sch, before = bf)
  d <- c4$calendar[c4$calendar$base == "base1", ]
  expect_lt(d$day[d$route == 2], d$day[d$route == 1])
  # a daily limit lets short routes share a team-day
  c5 <- schedule_calendar(sch, daily_limit = 2 * max(sch$calendar$duration))
  expect_lt(max(c5$calendar$day), max(c1$calendar$day))
  loads <- tapply(c5$calendar$duration, paste(c5$calendar$team, c5$calendar$day), sum)
  expect_true(all(loads <= 2 * max(sch$calendar$duration) + 1e-9))
  # infeasible constraints are reported
  none <- data.frame(team = "base2-1", day = 1:5, available = FALSE)
  expect_error(schedule_calendar(sch, availability = none), "No available team-day|No calendar|admissible")
  expect_error(schedule_calendar(sch, availability = data.frame(team = "nope", day = 1, available = FALSE)), "Unknown team")
  expect_error(schedule_calendar(sch, fixed = data.frame(base = "base1", route = 99)), "not found")
  expect_error(schedule_calendar(sch, daily_limit = -1), "positive")
})
