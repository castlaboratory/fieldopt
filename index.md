# fieldopt

Area-frame and dual-frame survey design under real field cost. Survey
samples are usually designed for precision alone; the cost that actually
decides whether a survey happens is the field work: travelling between
sampling units and interviewing. `fieldopt` puts that cost next to the
variance of the estimator so that both are visible when the design is
chosen, and provides the pieces an agricultural survey with an area
frame (grid cells, points inside them) and a list frame needs.

- [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  builds the travel matrix between units from coordinates (great-circle
  or planar distances, optionally times a detour factor), from a road
  network through OSRM (durations or distances, in blocks), or wraps a
  matrix computed elsewhere.
- [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md)
  turns travel, team-days, visits and interviews into money or time.
- [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
  routes the field work from a depot through the selected units, for one
  team or several, under daily limits of duration (travel plus the
  service time at each unit), stops and capacity, on symmetric or
  road-network matrices: exact up to 13 units, otherwise a hybrid
  genetic search with the optimal split of the tour and a granular local
  search (optimal on the classical TSPLIB instances, within 1.2% on the
  Augerat CVRP set A), with the Held-Karp bound and a proof of
  optimality when it closes.
- [`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md)
  assigns the units to several bases, routes each base and distributes
  the routes over the teams and the days available: a calendar that says
  whether the field work fits.
- [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  draws a probability sample of segments or cells, within strata, by the
  local pivotal method (spatially balanced), by spatially ordered
  systematic sampling along a Hilbert curve with interpenetrating
  replicates, by the cube method balanced on auxiliaries, or by simple
  random sampling;
  [`spatial_balance()`](https://castlaboratory.github.io/fieldopt/reference/spatial_balance.md)
  measures how evenly a sample covers the territory.
- [`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md),
  [`expected_hits()`](https://castlaboratory.github.io/fieldopt/reference/expected_hits.md)
  and
  [`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
  implement point sampling inside the selected cells and the
  multiplicity estimator (each hit of an establishment counts, divided
  by its expected hits).
- [`segment_estimator()`](https://castlaboratory.github.io/fieldopt/reference/segment_estimator.md)
  gives the closed, open and weighted segment estimators;
  [`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)
  the Horvitz-Thompson total with the variance estimator that matches
  the design (local-mean, replicates, SRS);
  [`ratio_estimator()`](https://castlaboratory.github.io/fieldopt/reference/ratio_estimator.md)
  uses a known auxiliary total;
  [`dual_frame_estimator()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_estimator.md)
  combines the area and the list samples (Hartley with a fixed,
  screening or estimated weight; Fuller-Burmeister).
- [`frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/frame_allocation.md)
  allocates across strata for a target variance or a budget;
  [`multivariate_allocation()`](https://castlaboratory.github.io/fieldopt/reference/multivariate_allocation.md)
  does it for several study variables at once (Bethel);
  [`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
  is Hartley’s allocation for an area frame plus a list frame with
  overlap, with the optimal mixing weight or the screening design;
  [`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md)
  is Cochran’s two-stage allocation with the cost function
  `c1 n + c2 n m`.
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) read
  them all.
- [`routed_unit_cost()`](https://castlaboratory.github.io/fieldopt/reference/routed_unit_cost.md),
  [`two_stage_design()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_design.md)
  and
  [`dual_frame_design()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_design.md)
  close the loop: the cost of an area unit is measured by routing a
  sample of the allocated size, and the allocation is repeated until it
  stabilises.
- [`point_design_effect()`](https://castlaboratory.github.io/fieldopt/reference/point_design_effect.md)
  simulates the whole area design (cells, points, hits, estimator) and
  returns the bias, the variance and the design effect of point
  sampling, the `deff_a` the dual-frame allocation asks for.
- [`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
  simulates designs over a grid of sample sizes and returns the
  trade-off between field cost and variance.
- [`as_frame()`](https://castlaboratory.github.io/fieldopt/reference/as_frame.md)
  and
  [`as_sf()`](https://castlaboratory.github.io/fieldopt/reference/as_sf.md)
  move between `sf` layers and the plain frames the package works on.

The numerical engine is the Rust crate
[`fieldopt-core`](https://github.com/castlaboratory/fieldopt-core),
usable on its own from Rust or from other languages.

## Installation

The development version needs a Rust toolchain (`cargo` and `rustc` 1.70
or later, from <https://rustup.rs>):

``` r

# install.packages("pak")
pak::pak("castlaboratory/fieldopt")
```

## Example

``` r

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

## How it works

![Architecture of fieldopt: R package, extendr bindings and the
fieldopt-core Rust crate](reference/figures/architecture.svg)

![Workflow of fieldopt: frame, travel matrix, selection, routing and the
schedule, cost and variance, and the
frontier](reference/figures/workflow.svg)

![Area-frame workflow of fieldopt: cells, points, hits, multiplicity
estimator, design effect, routed cost, the dual-frame allocation and the
dual-frame estimate](reference/figures/area-frame.svg)

## Related work

Spatially balanced sampling and its variance estimator follow Grafström,
Lundström and Schelin (2012) and Grafström and Schelin (2014), as
implemented in `BalancedSampling`; the allocations are Cochran’s (1977)
cost-optimal allocations and Hartley’s (1962, 1974) dual-frame design;
the dual-frame *estimators* (Hartley, Fuller-Burmeister,
Kalton-Anderson, pseudo-maximum likelihood, calibration) are in
`Frames2`. What `fieldopt` adds is the design side with the routing and
the cost model, so that the field cost of a design is computed instead
of approximated by the sample size.

## Authors

André Leite (UFPE), Raydonal Ospina (UFBA) and Cristiano Ferraz (UFPE),
CAST Lab. Licence GPL (\>= 3).
