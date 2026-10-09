# Changelog

## fieldopt 0.1.0

- New tools (engine `fieldopt-core` 0.4.0):
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
  takes a `service_time` per unit that counts towards `max_length` and
  reports route `durations`;
  [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md)
  gains `per_route` (the cost of a team-day);
  [`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md)
  assigns units to bases, routes each base and builds the calendar of
  teams and days;
  [`dual_frame_estimator()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_estimator.md)
  combines the area and list samples (Hartley with fixed, screening or
  estimated `theta`; Fuller-Burmeister) with design-based variances;
  `select_units(method = "cube", balance = )` draws balanced samples by
  the cube method and
  [`spatial_balance()`](https://castlaboratory.github.io/fieldopt/reference/spatial_balance.md)
  is the Voronoi measure of Stevens and Olsen;
  [`ratio_estimator()`](https://castlaboratory.github.io/fieldopt/reference/ratio_estimator.md)
  uses a known auxiliary total;
  [`multivariate_allocation()`](https://castlaboratory.github.io/fieldopt/reference/multivariate_allocation.md)
  is the Bethel allocation for several study variables;
  [`as_frame()`](https://castlaboratory.github.io/fieldopt/reference/as_frame.md)
  and
  [`as_sf()`](https://castlaboratory.github.io/fieldopt/reference/as_sf.md)
  move between `sf` layers and frames.

- Review round (engine `fieldopt-core` 0.3.0): the routing local search
  prices every move in the direction travelled, so asymmetric road
  matrices (one-way streets, durations by direction) no longer loop, and
  the lower bound is valid for asymmetric matrices and for several
  routes;
  [`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md)
  tries every whole `m`, accepts a fractional `m_secondary` and meets
  its target in small populations;
  [`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
  reads `sd` as the standard deviation with divisor `N - 1` and refuses
  `theta` outside `[0, 1]` and budgets below two units per frame;
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  refuses `size` with `"srs"` (the probabilities were mislabelled),
  duplicate unit names, `n` below the number of strata, strata with too
  few positive sizes and invalid seeds, and leaves the user’s
  random-number generator untouched;
  [`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
  refuses missing `y`;
  [`two_stage_design()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_design.md)
  and
  [`dual_frame_design()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_design.md)
  report `converged = FALSE` when the rounds run out;
  [`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
  takes the coordinate columns from a supplied `matrix`;
  [`core_version()`](https://castlaboratory.github.io/fieldopt/reference/core_version.md)
  reports the engine crate. New:
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  for samples, [`print()`](https://rdrr.io/r/base/print.html) for
  points,
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html)/[`glance()`](https://generics.r-lib.org/reference/glance.html)
  for routes,
  [`glance()`](https://generics.r-lib.org/reference/glance.html) for
  frontiers.

- The R wrappers are shipped in `R/extendr-wrappers.R` and no longer
  regenerated at install time (`cargo run --bin document`), which failed
  on the CRAN Windows toolchain.

- Area-frame and dual-frame design:
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  gains strata, a spatially ordered systematic method with
  interpenetrating replicates and simple random sampling;
  [`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md),
  [`expected_hits()`](https://castlaboratory.github.io/fieldopt/reference/expected_hits.md)
  and
  [`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
  implement point sampling inside segments with the multiplicity
  estimator;
  [`segment_estimator()`](https://castlaboratory.github.io/fieldopt/reference/segment_estimator.md)
  gives the closed, open and weighted segment estimators;
  [`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
  is Hartley’s allocation with an optimised or fixed mixing weight
  (screening design);
  [`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md)
  is Cochran’s two-stage allocation with the cost function
  `c1 n + c2 n m`.
  [`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)
  chooses the variance estimator that matches the design (local-mean,
  replicates or SRS). Engine: `fieldopt-core` 0.2.3.

- [`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
  accepts `strata`, `selection` and `replicates`, a list of per-stratum
  allocations in `n_grid`, and reports `cost_per_unit`.

- [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  gains a `detour` factor for straight-line distances and
  `method = "osrm"`, road durations or distances from an OSRM server
  through the `osrm` package, requested in blocks; the frontier and the
  routed designs accept the same method.

- [`routed_unit_cost()`](https://castlaboratory.github.io/fieldopt/reference/routed_unit_cost.md),
  [`two_stage_design()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_design.md)
  and
  [`dual_frame_design()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_design.md)
  iterate the allocation with the cost per area unit measured by
  routing;
  [`point_design_effect()`](https://castlaboratory.github.io/fieldopt/reference/point_design_effect.md)
  simulates the area design and returns the bias, variance and design
  effect of point sampling;
  [`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md)
  gains a systematic layout;
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) and
  [`glance()`](https://generics.r-lib.org/reference/glance.html) for the
  three allocations.

- Variances are computed within strata and summed (`"stratified srs"`,
  `"stratified local-mean"`); route plots of geographic matrices put
  longitude on the x axis.

- First version: travel matrices from coordinates or a road network
  ([`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)),
  a field cost model
  ([`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md)),
  GRASP routing of the field work for one or several teams
  ([`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)),
  spatially balanced selection of units with the local pivotal method
  ([`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)),
  Horvitz-Thompson estimation with the local-mean variance estimator
  ([`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)),
  cost-aware allocation across strata or frames
  ([`frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/frame_allocation.md))
  and the cost-variance frontier of a design by simulation
  ([`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)).
  The engine is the Rust crate `fieldopt-core`.
