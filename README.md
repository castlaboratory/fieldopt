# fieldopt <img src="man/figures/logo.png" align="right" height="139" alt="fieldopt hex logo" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/castlaboratory/fieldopt/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/castlaboratory/fieldopt/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://codecov.io/gh/castlaboratory/fieldopt/graph/badge.svg)](https://app.codecov.io/gh/castlaboratory/fieldopt)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Field-survey design under real field cost. Survey samples are usually designed
for precision alone; the cost that actually decides whether a survey happens is
the field work: travelling between sampling units and interviewing. `fieldopt`
puts that cost next to the variance of the estimator so that both are visible
when the design is chosen.

- `travel_matrix()` builds the travel matrix between units from coordinates
  (great-circle or planar distances) or wraps a road-network matrix.
- `field_cost_model()` turns travel, visits and interviews into money or time.
- `route_fieldwork()` routes the field work from a depot through the selected
  units, for one team or several, under route-length and stop limits (GRASP
  with 2-opt, Or-opt and an optimal split of the tour), and reports the gap to
  a lower bound.
- `select_units()` draws a spatially balanced probability sample with the local
  pivotal method, with equal or size-proportional inclusion probabilities.
- `design_variance()` gives the Horvitz-Thompson total and its local-mean
  variance estimate, with the simple-random-sampling variance as a reference.
- `frame_allocation()` allocates the sample across strata or frames for a
  target variance at minimum cost, or for a budget at minimum variance.
- `cost_variance_frontier()` simulates designs over a grid of sample sizes and
  returns the trade-off between field cost and variance.

The numerical engine is the Rust crate
[`fieldopt-core`](https://github.com/castlaboratory/fieldopt-core), usable on
its own from Rust or from other languages.

## Installation

The development version needs a Rust toolchain (`cargo` and `rustc` 1.70 or
later, from <https://rustup.rs>):

```r
# install.packages("pak")
pak::pak("castlaboratory/fieldopt")
```

## Example

```r
library(fieldopt)

set.seed(1)
frame <- data.frame(unit = c("depot", paste0("s", 1:40)),
                    x = c(5, runif(40, 0, 10)), y = c(5, runif(40, 0, 10)))
frame$crop <- c(NA, 20 + 3 * frame$x[-1] + rnorm(40))

model <- field_cost_model(per_travel = 2, per_unit = 30, per_interview = 10,
                          interviews_per_unit = 4, currency = "BRL")

# one design: select, route, price, estimate
units <- frame[frame$unit != "depot", ]
s <- select_units(units, n = 12)
m <- travel_matrix(frame, method = "euclidean")
r <- route_fieldwork(m, units = s$unit[s$sampled], depot = "depot",
                     max_stops = 5, cost_model = model)
r
design_variance(s, y = "crop")

# the frontier across sample sizes
f <- cost_variance_frontier(frame, depot = "depot", cost_model = model,
                            n_grid = c(8, 12, 16, 24), y = "crop",
                            method = "euclidean", max_stops = 5, n_rep = 10)
autoplot(f)
```

## Related work

Spatially balanced sampling and its variance estimator follow Grafström,
Lundström and Schelin (2012) and Grafström and Schelin (2014), as implemented
in `BalancedSampling`; the allocation is Cochran's (1977) cost-optimal
allocation. What `fieldopt` adds is the routing and the cost model, so that
the field cost of a design is computed instead of approximated by the sample
size.

## Authors

André Leite (UFPE), Raydonal Ospina (UFBA) and Cristiano Ferraz (UFPE), CAST
Lab. Licence GPL (>= 3).
