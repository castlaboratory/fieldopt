# Dual-frame estimate of a total

Combines the sample of frame A (the area frame) and the sample of frame
B (the list) into one estimate of the population total of `y`. Each
sampled unit carries its domain: `"a"` or `"ab"` in the A sample, `"b"`
or `"ab"` in the B sample. Two estimators:

## Usage

``` r
dual_frame_estimator(
  sample_a,
  sample_b,
  y,
  domain = "domain",
  theta = NULL,
  estimator = c("hartley", "fuller-burmeister")
)
```

## Arguments

- sample_a, sample_b:

  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  samples of frame A and frame B with columns `y` and `domain`
  (unsampled rows may hold `NA`).

- y:

  Column of the study variable.

- domain:

  Column with the domain of each unit.

- theta:

  Mixing weight of the overlap for Hartley: a number in `[0, 1]`,
  `"screening"`, or `NULL` to estimate it.

- estimator:

  `"hartley"` or `"fuller-burmeister"`.

## Value

A one-row tibble: `total`, `variance`, `se`, `cv`, `estimator`, `theta`
(Hartley) or `beta_1`, `beta_2` (Fuller-Burmeister), the domain totals
`y_a`, `y_ab_a`, `y_ab_b`, `y_b`, and `n_a`, `n_b`.

## Details

- **Hartley (1962)**:
  `Y_a + theta * Y_ab(A) + (1 - theta) * Y_ab(B) + Y_b`, with `theta`
  fixed, `"screening"` (`theta = 0`: overlap units found in the area
  sample are dropped, as when the list is enumerated completely) or
  estimated as the value that minimises the variance;

- **Fuller and Burmeister (1972)**: adds a second term in the difference
  between the two estimates of the overlap size, with coefficients
  chosen to minimise the variance.

Variances and covariances of the domain totals come from the variance
estimator of each sample's design
([`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)),
the two samples being independent. The estimated `theta` and the
Fuller-Burmeister coefficients make the variances slightly optimistic in
small samples.

## References

Hartley, H. O. (1962). Multiple frame surveys. *Proceedings of the
Social Statistics Section, ASA*, 203-206. Fuller, W. A. and Burmeister,
L. F. (1972). Estimators for samples selected from two overlapping
frames. *Proceedings of the Social Statistics Section, ASA*, 245-249.
Lohr, S. L. (2009). Multiple-frame surveys. In *Handbook of Statistics
29A*, 71-88.

## Examples

``` r
set.seed(7)
cells <- expand.grid(x = 1:12, y = 1:12); cells$unit <- paste0("c", 1:144)
cells$domain <- ifelse(runif(144) < 0.2, "ab", "a")
cells$y <- ifelse(cells$domain == "ab", 80, 10) + rnorm(144, sd = 3)
# the list holds the overlap units (same values) plus units of its own
ab <- cells[cells$domain == "ab", ]
list <- data.frame(unit = c(paste0("l", seq_len(nrow(ab))), paste0("b", 1:11)),
                   x = runif(nrow(ab) + 11), y = c(ab$y, 120 + rnorm(11, sd = 5)),
                   domain = rep(c("ab", "b"), c(nrow(ab), 11)))
list$lon <- runif(nrow(list)); list$lat <- runif(nrow(list))
sa <- select_units(cells, n = 30, seed = 1)
sb <- select_units(list, n = 15, coords = c("lat", "lon"), method = "srs", seed = 2)
dual_frame_estimator(sa, sb, y = "y", domain = "domain")
#> # A tibble: 1 × 13
#>   total variance    se     cv estimator theta theta_fixed   y_a y_ab_a y_ab_b
#>   <dbl>    <dbl> <dbl>  <dbl> <chr>     <dbl> <lgl>       <dbl>  <dbl>  <dbl>
#> 1 4510.   18873.  137. 0.0305 hartley       0 FALSE       1169.  2300.  2167.
#> # ℹ 3 more variables: y_b <dbl>, n_a <int>, n_b <int>
dual_frame_estimator(sa, sb, y = "y", domain = "domain", theta = "screening")
#> # A tibble: 1 × 13
#>   total variance    se     cv estimator theta theta_fixed   y_a y_ab_a y_ab_b
#>   <dbl>    <dbl> <dbl>  <dbl> <chr>     <dbl> <lgl>       <dbl>  <dbl>  <dbl>
#> 1 4510.   18873.  137. 0.0305 hartley       0 TRUE        1169.  2300.  2167.
#> # ℹ 3 more variables: y_b <dbl>, n_a <int>, n_b <int>
dual_frame_estimator(sa, sb, y = "y", domain = "domain", estimator = "fuller-burmeister")
#> # A tibble: 1 × 13
#>   total variance    se      cv estimator beta_1 beta_2   y_a y_ab_a y_ab_b   y_b
#>   <dbl>    <dbl> <dbl>   <dbl> <chr>      <dbl>  <dbl> <dbl>  <dbl>  <dbl> <dbl>
#> 1 4445.    1381.  37.2 0.00836 fuller-b…  0.224  -57.0 1169.  2300.  2167. 1174.
#> # ℹ 2 more variables: n_a <int>, n_b <int>
```
