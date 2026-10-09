# Design-based estimate of a total with its variance

Horvitz-Thompson estimate of the population total of `y` from a
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
sample, with the variance estimator that matches the design: the
local-mean estimator of Grafström and Schelin (2014) for spatially
balanced samples (it needs no joint inclusion probabilities), the
variance among replicate estimates for replicated systematic samples,
and the simple-random-sampling formula for equal-probability simple
random samples. The simple-random-sampling variance of the same sample
is always reported as a reference.

## Usage

``` r
design_variance(sample, y)
```

## Arguments

- sample:

  A `fieldopt_sample`.

- y:

  Column of the study variable (observed on the sampled units; other
  rows may be `NA`).

## Value

A one-row tibble: `total`, `variance`, `se`, `cv`, `variance_srs`, `n`,
`N`, `variance_method`.

## References

Grafström, A. and Schelin, L. (2014). How to select representative
samples. *Scandinavian Journal of Statistics*, 41(2), 277–290.

## Examples

``` r
set.seed(2)
frame <- data.frame(x = runif(80), y = runif(80))
frame$crop <- 10 + 20 * frame$x + rnorm(80)
s <- select_units(frame, n = 20)
design_variance(s, y = "crop")
#> # A tibble: 1 × 8
#>   total variance    se     cv variance_srs     n     N variance_method
#>   <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int> <chr>          
#> 1 1589.    1690.  41.1 0.0259        9141.    20    80 local-mean     
r <- select_units(frame, n = 20, method = "systematic", replicates = 4)
design_variance(r, y = "crop")
#> # A tibble: 1 × 8
#>   total variance    se     cv variance_srs     n     N variance_method
#>   <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int> <chr>          
#> 1 1596.    1952.  44.2 0.0277       10160.    20    80 replicates     
```
