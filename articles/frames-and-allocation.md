# Frames, strata and cost-aware allocation

Agricultural and establishment surveys often combine a list frame (known
farms, cheap to reach by phone or on a planned visit) and an area frame
(segments of territory, expensive to reach, complete in coverage). Even
within one frame, strata differ in the cost of a unit.
[`frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/frame_allocation.md)
is Cochran’s (1977, Section 5.5) allocation with a cost per unit in each
stratum, in its two forms.

``` r

library(fieldopt)
strata <- data.frame(stratum = c("list: large", "list: small", "area"),
                     size = c(300, 2500, 900),
                     sd = c(80, 12, 35),
                     cost = c(60, 35, 190))
strata
#>       stratum size sd cost
#> 1 list: large  300 80   60
#> 2 list: small 2500 12   35
#> 3        area  900 35  190
```

## Minimum cost for a target variance

Fix the precision wanted for the estimated total and find the cheapest
allocation that reaches it. The optimum has `n_h` proportional to
`N_h S_h / sqrt(c_h)`, rounded up and kept between 2 and `N_h`.

``` r

a <- frame_allocation(strata, target_variance = 2.5e7)
a
#> 
#> ── Allocation ──────────────────────────────────────────────────────────────────
#> Minimum cost for target variance 2.5e+07: cost 22640, variance 24720000.
#> # A tibble: 3 × 5
#>   stratum      size    sd  cost     n
#>   <chr>       <dbl> <dbl> <dbl> <int>
#> 1 list: large   300    80    60    88
#> 2 list: small  2500    12    35   143
#> 3 area          900    35   190    65
```

## Minimum variance for a budget

Fix the budget instead and find the allocation with the smallest
variance within it. Rounding is repaired so that the cost never exceeds
the budget.

``` r

b <- frame_allocation(strata, budget = 30000)
b
#> 
#> ── Allocation ──────────────────────────────────────────────────────────────────
#> Minimum variance for budget 30000: cost 29980, variance 17830000.
#> # A tibble: 3 × 5
#>   stratum      size    sd  cost     n
#>   <chr>       <dbl> <dbl> <dbl> <int>
#> 1 list: large   300    80    60   116
#> 2 list: small  2500    12    35   191
#> 3 area          900    35   190    86
```

## Where the field cost comes in

The `cost` column above is a planning value per unit. For the area frame
it should include the travel, and that is what the routing part of the
package estimates: run
[`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
on the area frame with a cost model, read the mean cost per unit at the
sample size under consideration, and use it as the stratum cost. The
allocation then reflects how expensive the segments really are to visit,
and the loop can be iterated once or twice until the stratum costs and
sample sizes agree.

``` r

f <- cost_variance_frontier(area_frame, depot = "depot", cost_model = model,
                            n_grid = c(40, 60, 80, 100), y = "crop")
per_unit <- f$cost_mean / f$n
strata$cost[strata$stratum == "area"] <- per_unit[which.min(abs(f$n - a$n[3]))]
frame_allocation(strata, target_variance = 2.5e7)
```

Overlap between the frames (farms present in both) is not modelled here;
the allocation treats the frames as strata of a single design.

## References

Cochran, W. G. (1977). *Sampling Techniques*, 3rd ed. Wiley.
