# Design-based estimate of a total with its variance

Horvitz-Thompson estimate of the population total of `y` from a
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
sample, with the local-mean variance estimator of Grafström and Schelin
(2014), which suits spatially balanced samples and needs no joint
inclusion probabilities. The simple-random-sampling variance of the same
sample is reported as a reference.

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
`N`.

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
#> # A tibble: 1 × 7
#>   total variance    se     cv variance_srs     n     N
#>   <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int>
#> 1 1611.     944.  30.7 0.0191        7860.    20    80
```
