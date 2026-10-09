# Extracted from test-review.R:115

# prequel ----------------------------------------------------------------------
review_grid <- function() {
  g <- expand.grid(x = 1:8, y = 1:8)
  g$unit <- paste0("c", seq_len(nrow(g)))
  g$size <- 1 + g$y
  g$h <- rep(c("a", "b", "c", "d"), each = 16)
  g
}

# test -------------------------------------------------------------------------
g <- review_grid()
s <- select_units(g, 12, strata = "h", seed = 1)
expect_s3_class(autoplot(s), "ggplot")
p <- select_points(s, 2, 1)
expect_message(print(p), "random points")
