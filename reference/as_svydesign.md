# Hand a sample to the survey package

Builds a `survey` design object from a
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
sample so that the estimators of that package (calibration,
post-stratification, domains, ratios, regression) can be used on the
field data. Units not sampled are dropped; the weights are the inverse
inclusion probabilities, and the strata of the sample are the strata of
the design.

## Usage

``` r
as_svydesign(sample, variance = c("brewer", "srs"))
```

## Arguments

- sample:

  A
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  sample.

- variance:

  `"brewer"` or `"srs"` (ignored for replicated samples).

## Value

A `survey.design2` or `svyrep.design` object.

## Details

- Samples with interpenetrating replicates (`method = "systematic"`,
  `replicates > 1`) become a replicate-weight design
  ([`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html))
  whose variance is the variance between the replicate estimates, the
  one
  [`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)
  uses.

- Other samples become a
  [`survey::svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html):
  with `variance = "brewer"` (default) the without-replacement
  probability-proportional-to- size approximation of Brewer, which needs
  no joint probabilities; with `variance = "srs"` the finite-population
  correction of simple random sampling within strata. Neither uses the
  spatial balance of the local pivotal method, so for the variance of a
  total of a spatially balanced sample prefer
  [`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md);
  use the `survey` object for what it adds.

## Examples

``` r
if (requireNamespace("survey", quietly = TRUE)) {
  cells <- expand.grid(x = 1:10, y = 1:10); cells$unit <- paste0("c", 1:100)
  cells$crop <- 10 + cells$x + rnorm(100)
  s <- select_units(cells, n = 20, seed = 1)
  d <- as_svydesign(s)
  survey::svytotal(~crop, d)
  design_variance(s, "crop")[, c("total", "se")]
}
#> # A tibble: 1 × 2
#>   total    se
#>   <dbl> <dbl>
#> 1 1506.  34.7
```
