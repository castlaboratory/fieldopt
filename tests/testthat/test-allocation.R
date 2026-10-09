strata <- data.frame(stratum = c("list", "area"), size = c(2000, 800), sd = c(12, 30), cost = c(40, 180))

test_that("allocation for a target variance reaches it at minimum cost", {
  a <- frame_allocation(strata, target_variance = 4e6)
  expect_s3_class(a, "fieldopt_allocation")
  expect_lte(attr(a, "variance"), 4e6)
  expect_equal(attr(a, "cost"), sum(a$n * strata$cost))
  # n_h proportional to N_h S_h / sqrt(c_h)
  ratio <- (2000 * 12 / sqrt(40)) / (800 * 30 / sqrt(180))
  expect_equal(a$n[1] / a$n[2], ratio, tolerance = 0.02)
  expect_message(print(a), "Minimum cost")
})

test_that("allocation for a budget stays within it", {
  b <- frame_allocation(strata, budget = 20000)
  expect_lte(attr(b, "cost"), 20000)
  expect_gt(attr(b, "cost"), 19600)
  expect_message(print(b), "Minimum variance")
  # the two problems are dual: the budget of the variance solution gives back its variance
  a <- frame_allocation(strata, target_variance = 4e6)
  b2 <- frame_allocation(strata, budget = attr(a, "cost"))
  expect_equal(attr(b2, "variance"), attr(a, "variance"), tolerance = 0.02)
})

test_that("bounds and inputs are validated", {
  expect_error(frame_allocation(strata), "exactly one")
  expect_error(frame_allocation(strata, target_variance = 1, budget = 1), "exactly one")
  expect_error(frame_allocation(strata[, c("size", "sd")], budget = 1), "cost")
  huge <- frame_allocation(strata, target_variance = 1e12)
  expect_true(all(huge$n == 2))
  expect_true(attr(huge, "bounded"))
  noname <- frame_allocation(strata[, -1], budget = 5000)
  expect_equal(noname$stratum, c("h1", "h2"))
})
