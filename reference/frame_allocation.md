# Cost-aware allocation across strata

Classical optimum allocation with a cost per unit in each stratum
(Cochran 1977, Section 5.5): minimum cost for a target variance of the
estimated total, or minimum variance for a budget. For two frames with
an overlap use
[`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
instead.

## Usage

``` r
frame_allocation(strata, target_variance = NULL, budget = NULL)
```

## Arguments

- strata:

  Data frame with columns `size` (population units), `sd` (standard
  deviation of the study variable) and `cost` (cost per unit, interview
  plus expected access), and optionally `stratum` with names.

- target_variance:

  Target variance of the estimated total (give this or `budget`).

- budget:

  Total cost allowed.

## Value

The strata with a column `n`, plus attributes `cost`, `variance` and
`bounded` (whether `2 <= n_h <= N_h` was active), of class
`fieldopt_allocation`.

## Examples

``` r
strata <- data.frame(stratum = c("list", "area"), size = c(2000, 800),
                     sd = c(12, 30), cost = c(40, 180))
frame_allocation(strata, target_variance = 4e6)
#> 
#> ── Allocation ──────────────────────────────────────────────────────────────────
#> Minimum cost for target variance 4e+06: cost 45000, variance 3980000.
#> # A tibble: 2 × 5
#>   stratum  size    sd  cost     n
#>   <chr>   <dbl> <dbl> <dbl> <int>
#> 1 list     2000    12    40   360
#> 2 area      800    30   180   170
frame_allocation(strata, budget = 20000)
#> 
#> ── Allocation ──────────────────────────────────────────────────────────────────
#> Minimum variance for budget 20000: cost 19980, variance 10230000.
#> # A tibble: 2 × 5
#>   stratum  size    sd  cost     n
#>   <chr>   <dbl> <dbl> <dbl> <int>
#> 1 list     2000    12    40   162
#> 2 area      800    30   180    75
```
