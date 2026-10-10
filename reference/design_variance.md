# Design-based estimate of a total with its variance

Horvitz-Thompson estimate of the population total of `y` from a
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
sample, with the variance estimator that matches the design: the
local-mean estimator of Grafström and Schelin (2014) for spatially
balanced samples (it needs no joint inclusion probabilities), the
variance among replicate estimates for replicated systematic samples,
and the simple-random-sampling formula for equal-probability simple
random samples. A systematic sample drawn as a single replicate has no
unbiased design-based variance estimator; the local-mean estimator is
used as the customary approximation. The simple-random-sampling variance
of the same sample is always reported as a reference.

## Usage

``` r
design_variance(sample, y, neighbours = 3L)
```

## Arguments

- sample:

  A `fieldopt_sample`.

- y:

  Column of the study variable (observed on the sampled units; other
  rows may be `NA`).

- neighbours:

  Number of nearest sampled units in the neighbourhood of the local-mean
  estimator.

## Value

A one-row tibble: `total`, `variance`, `se`, `cv`, `variance_srs`, `n`,
`N`, `variance_method` and `df` (degrees of freedom of the variance
estimate: -1 with `r` replicates, the number of sampled units minus the
number of strata otherwise).

## Details

The local-mean estimator averages over each sampled unit and its
`neighbours` nearest sampled units (ties included), as
[`BalancedSampling::vsb()`](https://rdrr.io/pkg/BalancedSampling/man/vsb.html)
does with its default `k = 3`. In the package's experiments (three
frames, Gaussian fields at four spatial ranges) it is close to unbiased
when the variable has no spatial structure and conservative when it is
smooth; the replicate estimator is unbiased but has only -1 degrees of
freedom, so intervals should use the t quantile with `df` (reported)
rather than the normal one.

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
#> # A tibble: 1 × 9
#>   total variance    se     cv variance_srs     n     N variance_method    df
#>   <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int> <chr>           <int>
#> 1 1620.    1442.  38.0 0.0234        9260.    20    80 local-mean         19
r <- select_units(frame, n = 20, method = "systematic", replicates = 4)
design_variance(r, y = "crop")
#> # A tibble: 1 × 9
#>   total variance    se     cv variance_srs     n     N variance_method    df
#>   <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int> <chr>           <int>
#> 1 1596.    1952.  44.2 0.0277       10160.    20    80 replicates          3
```
