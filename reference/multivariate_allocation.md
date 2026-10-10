# Cost-aware allocation for several study variables

Minimum cost `sum c_h n_h` such that the variance of the estimated total
of every study variable is at most its target (Bethel 1989; Chromy
1987). This is
[`frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/frame_allocation.md)
with one constraint per variable: a survey that must estimate several
crops, or a crop and the number of farms, with stated precisions. The
multipliers tell which constraints bind.

## Usage

``` r
multivariate_allocation(
  strata,
  sd,
  target_variance = NULL,
  target_cv = NULL,
  totals = NULL
)
```

## Arguments

- strata:

  Data frame with columns `size`, `cost`, optionally `stratum`, and one
  standard-deviation column per study variable.

- sd:

  Names of the standard-deviation columns, one per variable.

- target_variance:

  Target variance of each variable's total, in the order of `sd` (give
  this or `target_cv`).

- target_cv:

  Target coefficient of variation of each total; needs `totals`.

- totals:

  Population totals of the variables, for `target_cv`.

## Value

The strata with a column `n`, of class `fieldopt_multi_allocation`, with
attributes `cost`, `targets`, `attained` (variance of each variable),
`multipliers`, `bounded`.

## References

Bethel, J. (1989). Sample allocation in multivariate surveys. *Survey
Methodology*, 15, 47-57. Chromy, J. R. (1987). Design optimization with
multiple objectives. *Proceedings of the Survey Research Methods
Section, ASA*, 194-199.

## Examples

``` r
strata <- data.frame(
  stratum = c("high", "mid", "low"), size = c(300, 800, 2000),
  cost = c(250, 180, 150), sd_corn = c(40, 25, 8), sd_cattle = c(15, 30, 12)
)
multivariate_allocation(strata,
  sd = c("sd_corn", "sd_cattle"),
  target_cv = c(0.05, 0.08), totals = c(90000, 60000)
)
#> 
#> ── Multivariate allocation ─────────────────────────────────────────────────────
#> Minimum cost 21150 for 2 targets.
#> sd_corn: target 20250000, attained 19910000 (binding).
#> sd_cattle: target 23040000, attained 22860000 (binding).
#> # A tibble: 3 × 4
#>   stratum  size  cost     n
#>   <chr>   <dbl> <dbl> <int>
#> 1 high      300   250    18
#> 2 mid       800   180    50
#> 3 low      2000   150    51
```
