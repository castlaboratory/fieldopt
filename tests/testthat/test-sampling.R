grid_frame <- function(n_side = 8) {
  g <- expand.grid(x = seq_len(n_side), y = seq_len(n_side))
  g$unit <- paste0("c", seq_len(nrow(g)))
  g$crop <- 10 + 2 * g$x + rnorm(nrow(g))
  g$size <- 1 + g$y
  g
}

test_that("select_units returns a fixed-size sample with probabilities summing to n", {
  set.seed(1)
  fr <- grid_frame()
  s <- select_units(fr, n = 16, seed = 3)
  expect_s3_class(s, "fieldopt_sample")
  expect_equal(sum(s$sampled), 16)
  expect_equal(sum(s$pi), 16)
  expect_true(all(s$pi == 0.25))
  s2 <- select_units(fr, n = 16, size = "size", seed = 3)
  expect_equal(sum(s2$sampled), 16)
  expect_equal(sum(s2$pi), 16, tolerance = 1e-9)
  expect_true(all(s2$pi <= 1))
  expect_true(cor(s2$pi, fr$size) > 0.99)
  expect_identical(s$sampled, select_units(fr, n = 16, seed = 3)$sampled)
  expect_false(identical(s$sampled, select_units(fr, n = 16, seed = 4)$sampled))
})

test_that("select_units validates its inputs", {
  fr <- grid_frame()
  expect_error(select_units(fr, n = 0), "at least 1")
  expect_error(select_units(fr, n = 100), "exceeds")
  expect_error(select_units(fr, n = 4, size = "nope"), "Size column")
  expect_error(select_units(fr, n = 4, coords = c("x", "zz")), "not found")
  expect_error(select_units(data.frame(a = 1:5), n = 2), "coordinate")
  noname <- select_units(fr[, c("x", "y")], n = 4)
  expect_equal(noname$unit[1], "u1")
})

test_that("the sample is spatially balanced", {
  set.seed(2)
  fr <- grid_frame(10)
  # share of sampled units whose nearest neighbour on the grid is also sampled
  adjacent <- function(sampled) {
    idx <- which(sampled)
    pairs <- 0
    for (i in idx) {
      for (j in idx) {
        if (j > i) {
          if (abs(fr$x[i] - fr$x[j]) + abs(fr$y[i] - fr$y[j]) == 1) pairs <- pairs + 1
        }
      }
    }
    pairs
  }
  lpm <- mean(sapply(1:30, function(s) adjacent(select_units(fr, n = 25, seed = s)$sampled)))
  srs <- mean(sapply(1:30, function(s) {
    set.seed(s)
    x <- logical(100)
    x[sample(100, 25)] <- TRUE
    adjacent(x)
  }))
  expect_lt(lpm, 0.5 * srs)
})

test_that("design_variance estimates the total and its variance", {
  set.seed(3)
  fr <- grid_frame(10)
  truth <- sum(fr$crop)
  est <- sapply(1:200, function(s) {
    d <- design_variance(select_units(fr, n = 20, seed = s), y = "crop")
    c(d$total, d$variance, d$variance_srs)
  })
  expect_equal(mean(est[1, ]), truth, tolerance = 0.02)
  emp <- var(est[1, ])
  # local-mean estimator is close to the empirical variance of the HT total
  expect_equal(mean(est[2, ]), emp, tolerance = 0.5)
  # and spatial balance beats simple random sampling on a trending variable
  expect_lt(mean(est[2, ]), mean(est[3, ]))
  d <- design_variance(select_units(fr, n = 20), y = "crop")
  expect_named(d, c("total", "variance", "se", "cv", "variance_srs", "n", "N", "variance_method", "df"))
  expect_equal(d$se, sqrt(d$variance))
  fr$crop[1] <- NA
  s <- select_units(fr, n = 20, seed = 1)
  if (s$sampled[1]) expect_error(design_variance(s, "crop"), "missing") else expect_s3_class(design_variance(s, "crop"), "tbl_df")
  expect_error(design_variance(fr, "crop"), "select_units")
  expect_error(design_variance(s, "zz"), "not found")
})

test_that("the local-mean variance matches BalancedSampling::vsb() and df is reported", {
  skip_if_not_installed("BalancedSampling")
  set.seed(8)
  frame <- data.frame(unit = paste0("u", 1:200), x = runif(200), y = runif(200))
  frame$v <- 5 + 3 * frame$x + rnorm(200)
  s <- select_units(frame, n = 30, seed = 2)
  i <- which(s$sampled)
  X <- as.matrix(as.data.frame(s)[i, c("x", "y")])
  for (k in c(1L, 3L, 5L)) {
    expect_equal(design_variance(s, "v", neighbours = k)$variance,
      BalancedSampling::vsb(s$pi[i], frame$v[i], X, k = k),
      tolerance = 1e-10
    )
  }
  expect_equal(design_variance(s, "v")$df, 29L)
  r <- select_units(frame, n = 32, method = "systematic", replicates = 4, seed = 2)
  expect_equal(design_variance(r, "v")$df, 3L)
  expect_error(design_variance(s, "v", neighbours = 0), "at least 1")
})
