# Changelog

## fieldopt 0.1.0

- [`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md)
  solves the assignment of units to bases and the routes jointly, as one
  multi-depot problem with a route limit per base and the `per_route`
  cost in the objective (engine `fieldopt-core` 0.8.1);
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
  charges `per_route` in its objective too. On the 23 Cordeau
  multi-depot instances the solver reaches or beats the best known
  solution on 11 and stays within 1.6% on the rest, in 1 to 26 seconds.

- Pipe-friendly inputs:
  [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  takes a sample (its sampled units only) with `bases` and a `speed`
  that turns distances into minutes;
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
  and
  [`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md)
  take the sample as `units`;
  [`sampled()`](https://castlaboratory.github.io/fieldopt/reference/sampled.md)
  returns the selected rows, so a plan reads
  `frame |> select_units(n) |> travel_matrix(bases = towns, speed = 60) |> schedule_fieldwork(units = s, ...)`.

- Connectors:
  [`as_svydesign()`](https://castlaboratory.github.io/fieldopt/reference/as_svydesign.md)
  hands a sample to the `survey` package (a replicate-weight design for
  replicated systematic samples, Brewer’s or the simple-random-sampling
  approximation otherwise) for calibration, domains and nonresponse
  adjustment;
  [`frame_overlap()`](https://castlaboratory.github.io/fieldopt/reference/frame_overlap.md)
  matches the establishments of a list frame to the cells of the area
  frame (coordinates, polygons or a table of linked pairs) and marks the
  overlap domain;
  [`read_areaframe()`](https://castlaboratory.github.io/fieldopt/reference/read_areaframe.md)
  reads the cells exported by the area-frame service (Parquet with WKB
  geometries) or any spatial file.

- `select_units(method = "lpm")` and
  [`spatial_balance()`](https://castlaboratory.github.io/fieldopt/reference/spatial_balance.md)
  use a grid spatial index (engine `fieldopt-core` 0.9.1): a frame of a
  million cells is sampled in under a second instead of hours.
  `schedule_fieldwork(region = )` solves one region at a time and
  combines the calendars, the way a national survey is scheduled state
  by state.

- [`schedule_calendar()`](https://castlaboratory.github.io/fieldopt/reference/schedule_calendar.md)
  redistributes the routes of a schedule over teams and days as an
  integer programme solved with the `highs` package (in Suggests): team
  availability by day, routes fixed to a team or a day, precedences, and
  a daily limit that lets short routes share a team-day; it minimises
  the last working day.

- `route_fieldwork(certify = )` runs a branch-and-bound on Held-Karp
  1-trees that proves single tours optimal (engine `fieldopt-core`
  0.9.0): most tours of up to a hundred units are certified within a few
  seconds, and `optimal` is no longer limited to instances of 13 units.

- The routing solver was rebuilt (engine `fieldopt-core` 0.5.0):
  instances of up to 13 units are solved exactly; larger ones by a
  hybrid genetic search with the optimal split of giant tours and a
  granular local search with inter-route moves (relocate, swap, 2-opt*);
  the Held-Karp bound replaces the two-edge bound for single tours and
  `optimal` reports proven optimality;
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
  gains `demand`, `capacity`, `time_limit` and `engine = "vrpr"` (the
  PyVRP solver through the `vrpr` package, also in
  [`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md),
  where it optimises the assignment to bases jointly with the routes).
  The built-in solver has feasible and infeasible subpopulations with
  adaptive penalties, SWAP* and intra-route swaps, moves priced from
  route totals in constant time, population restarts and a time limit
  (engine 0.7.0): on TSPLIB it is optimal and on Augerat set A it
  reaches 24 of 27 optima (mean gap 0.01%, largest 0.15%) in about two
  seconds.

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
