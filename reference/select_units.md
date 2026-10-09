# Select units with a spatially balanced probability sample

Draws `n` units with inclusion probabilities proportional to `size`
(equal when `size` is `NULL`) by the local pivotal method (Grafström,
Lundström and Schelin, 2012), which spreads the sample over the
coordinate space so that nearby units are rarely selected together. The
design is probabilistic with known inclusion probabilities, which is
what the estimator needs; spatial balance reduces the variance and, at
the same time, tends to spread the field work, which is the tension the
cost model and routing make explicit.

## Usage

``` r
select_units(frame, n, size = NULL, coords = NULL, seed = 1)
```

## Arguments

- frame:

  Data frame with one row per unit: coordinate columns (`lat`, `lon` or
  `x`, `y`, or those named in `coords`), an optional `size` column and
  an optional `unit` column with names.

- n:

  Sample size.

- size:

  Column of the size measure for probability-proportional-to-size
  selection, or `NULL` for equal probabilities.

- coords:

  Names of the coordinate columns used for spatial balance (any number
  of columns; a travel-cost embedding is admissible).

- seed:

  Seed.

## Value

The frame as a tibble with columns `pi` (inclusion probability) and
`sampled`, of class `fieldopt_sample`, with attributes `n`, `coords` and
`seed`.

## References

Grafström, A., Lundström, N. L. P. and Schelin, L. (2012). Spatially
balanced sampling through the pivotal method. *Biometrics*, 68(2),
514–520.

## Examples

``` r
set.seed(1)
frame <- data.frame(unit = paste0("s", 1:50), x = runif(50), y = runif(50), size = rexp(50))
s <- select_units(frame, n = 10, size = "size")
sum(s$sampled); sum(s$pi)
#> [1] 10
#> [1] 10
```
