# Validation and benchmarks

This vignette records how the package was checked: the routing solver
against public benchmark instances and other solvers, and the estimators
by simulation. The large runs were done once, outside the package build,
with the scripts of the `fieldopt-core` repository; the small ones run
here.

## The routing solver

![Inside route_fieldwork: exact dynamic programme, hybrid genetic
search, split, local search, penalties, bounds and
certificate](figures/solver.svg)

Figure of the chunk unnamed-chunk-2

Instances with rounded Euclidean distances, as the libraries define
them, one core of a laptop, one seed:

| Set | Instances | Setting | Result |
|----|----|----|----|
| TSPLIB (eil51 to eil101, 51 to 101 nodes) | 7 | 2000 offspring | 7 of 7 optimal; 6 of 7 proven optimal within 10 s by the certificate |
| Augerat set A (CVRP, 31 to 79 customers) | 27 | 200 offspring (default) | 14 of 27 optimal, mean gap 0.20%, largest 1.14%, under 0.4 s |
| Augerat set A | 27 | 2000 offspring | 24 of 27 optimal, mean gap 0.01%, largest 0.15%, 0.7 to 4 s |
| Cordeau MDVRP (50 to 360 customers, 2 to 6 depots) | 23 | 2000 offspring | 11 of 23 at or below the best known, mean gap 0.29%, largest 1.5%, 1 to 26 s |
| Cordeau MDVRP | 23 | 20 s each | 13 of 23 at or below the best known, mean gap 0.26% |

Other solvers on the same instances: PyVRP through the `vrpr` package
reaches 18 of 27 Augerat optima in one second and 24 in five (mean gap
0.05%); HiGHS on the compact MTZ formulation solves the TSP up to 51
nodes (21 s) but stays 40 to 60 percent away from the optimum after
three minutes on the smallest Augerat instances, which is why the
package does not route with a general MIP solver.

Stability: across eight seeds on four instances the gap moved by less
than one percentage point (standard deviation below 0.3 points).

Internal checks in the engine’s test suite: every local-search move is
priced in constant time and was checked against a full recomputation on
tens of thousands of accepted moves; the exact dynamic programme and the
split of giant tours were checked against brute force on hundreds of
random instances with one to three depots and asymmetric costs; the
lower bounds never exceed the exact optimum; an independent review found
and fixed four defects before release.

## The estimators

Small Monte Carlo checks, run here, of the unbiasedness of the main
estimators.

``` r

set.seed(4)
cells <- expand.grid(x = 1:15, y = 1:15); cells$unit <- paste0("c", 1:225)
areas <- do.call(rbind, lapply(cells$unit, function(u) data.frame(unit = u, establishment = paste0(u, "-", 1:3),
                                                                 area = 0.3, y = rlnorm(3, 2, 0.5))))
deff <- point_design_effect(cells, areas, n = 25, points_per_cell = 6, cell_size = 1, n_sim = 60, seed = 2)
deff[, c("bias", "variance", "mean_variance_estimate", "deff")]
#> # A tibble: 1 × 4
#>    bias variance mean_variance_estimate  deff
#>   <dbl>    <dbl>                  <dbl> <dbl>
#> 1  56.1  158401.                170292.  1.47
```

``` r

set.seed(7)
cells$domain <- ifelse(runif(225) < 0.2, "ab", "a"); cells$yv <- ifelse(cells$domain == "ab", 80, 10) + rnorm(225, sd = 3)
ab <- cells[cells$domain == "ab", ]
lst <- data.frame(unit = c(paste0("l", seq_len(nrow(ab))), paste0("b", 1:12)), x = runif(nrow(ab) + 12), y = runif(nrow(ab) + 12),
                  domain = rep(c("ab", "b"), c(nrow(ab), 12)), yv = c(ab$yv, 120 + rnorm(12, sd = 5)))
truth <- sum(cells$yv) + sum(lst$yv[lst$domain == "b"])
est <- t(sapply(1:40, function(k) {
  sa <- select_units(cells, n = 30, seed = k); sb <- select_units(lst, n = 15, method = "srs", seed = k)
  c(hartley = dual_frame_estimator(sa, sb, "yv", "domain")$total,
    fb = dual_frame_estimator(sa, sb, "yv", "domain", estimator = "fuller-burmeister")$total)
}))
round(c(truth = truth, colMeans(est)))
#>   truth hartley      fb 
#>    6187    6224    6249
round(100 * (colMeans(est) - truth) / truth, 2)   # relative bias in percent
#> hartley      fb 
#>    0.59    1.00
```

Further checks live in the test suite: the Hartley allocation against a
grid search over the mixing weight, Cochran’s two-stage optimum against
enumeration, the multivariate allocation against an integer grid, the
cube method’s balance against simple random sampling, and the `survey`
designs produced by
[`as_svydesign()`](https://castlaboratory.github.io/fieldopt/reference/as_svydesign.md)
against the package’s own totals and replicate variances.
