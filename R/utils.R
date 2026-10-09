# Internal helpers --------------------------------------------------------------

# A seed must be a single non-negative whole number: the Rust engine takes a u64.
check_seed <- function(seed, arg = "seed") {
  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed < 0 || seed != round(seed)) {
    cli::cli_abort("{.arg {arg}} must be a single non-negative whole number.")
  }
  invisible(seed)
}

# Evaluate `expr` with R's RNG seeded by `seed`, restoring the user's RNG state afterwards.
with_seed <- function(seed, expr) {
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit(if (had) assign(".Random.seed", old, envir = globalenv()) else rm(".Random.seed", envir = globalenv()), add = TRUE)
  set.seed(seed)
  expr
}
