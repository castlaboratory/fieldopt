# Ratio estimate of a total with an auxiliary variable

The ratio estimator `X * Y_hat / X_hat`, where `X` is the known
population total of the auxiliary (the area of the segments, the number
of farms from a census), with the variance of the residuals `y - R x`
under the design, estimated as in
[`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md).
The gain over the Horvitz-Thompson estimate is reported.

## Usage

``` r
ratio_estimator(sample, y, x, x_total = NULL)
```

## Arguments

- sample:

  A `fieldopt_sample`.

- y:

  Column of the study variable (observed on the sampled units; other
  rows may be `NA`).

- x:

  Column of the auxiliary variable.

- x_total:

  Known population total of `x`; the frame total of the column when
  `NULL`.

## Value

A one-row tibble as in
[`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)
plus `ratio`, `x_total` and `variance_ht` (the variance of the plain
Horvitz-Thompson estimate).

## Examples

``` r
cells <- expand.grid(x = 1:12, y = 1:12)
cells$unit <- paste0("c", 1:144)
cells$farmland <- runif(144, 20, 100)
cells$crop <- 0.4 * cells$farmland + rnorm(144, sd = 3)
s <- select_units(cells, n = 24, seed = 2)
ratio_estimator(s, y = "crop", x = "farmland")
#> # A tibble: 1 × 11
#>   total variance    se     cv ratio x_total variance_ht variance_srs     n     N
#>   <dbl>    <dbl> <dbl>  <dbl> <dbl>   <dbl>       <dbl>        <dbl> <int> <int>
#> 1 3323.    5554.  74.5 0.0224 0.397   8377.      72593.        4211.    24   144
#> # ℹ 1 more variable: variance_method <chr>
```
