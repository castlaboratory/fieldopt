# fieldopt 0.1.0

* `schedule_fieldwork()` solves the assignment of units to bases and the
  routes jointly, as one multi-depot problem with a route limit per base and
  the `per_route` cost in the objective (engine `fieldopt-core` 0.8.1);
  `route_fieldwork()` charges `per_route` in its objective too. On the 23
  Cordeau multi-depot instances the solver reaches or beats the best known
  solution on 11 and stays within 1.6% on the rest, in 1 to 26 seconds.
* `schedule_calendar()` redistributes the routes of a schedule over teams and
  days as an integer programme solved with the `highs` package (in Suggests):
  team availability by day, routes fixed to a team or a day, precedences, and
  a daily limit that lets short routes share a team-day; it minimises the last
  working day.
* `route_fieldwork(certify = )` runs a branch-and-bound on Held-Karp 1-trees
  that proves single tours optimal (engine `fieldopt-core` 0.9.0): most tours
  of up to a hundred units are certified within a few seconds, and `optimal`
  is no longer limited to instances of 13 units.
* The routing solver was rebuilt (engine `fieldopt-core` 0.5.0): instances of
  up to 13 units are solved exactly; larger ones by a hybrid genetic search
  with the optimal split of giant tours and a granular local search with
  inter-route moves (relocate, swap, 2-opt*); the Held-Karp bound replaces
  the two-edge bound for single tours and `optimal` reports proven optimality;
  `route_fieldwork()` gains `demand`, `capacity`, `time_limit` and
  `engine = "vrpr"` (the PyVRP solver through the `vrpr` package, also in
  `schedule_fieldwork()`, where it optimises the assignment to bases jointly
  with the routes). The built-in solver has feasible and infeasible
  subpopulations with adaptive penalties, SWAP* and intra-route swaps, moves
  priced from route totals in constant time, population restarts and a time
  limit (engine 0.7.0): on TSPLIB it is optimal and on Augerat set A it
  reaches 24 of 27 optima (mean gap 0.01%, largest 0.15%) in about two
  seconds.

* New tools (engine `fieldopt-core` 0.4.0): `route_fieldwork()` takes a
  `service_time` per unit that counts towards `max_length` and reports route
  `durations`; `field_cost_model()` gains `per_route` (the cost of a
  team-day); `schedule_fieldwork()` assigns units to bases, routes each base
  and builds the calendar of teams and days; `dual_frame_estimator()`
  combines the area and list samples (Hartley with fixed, screening or
  estimated `theta`; Fuller-Burmeister) with design-based variances;
  `select_units(method = "cube", balance = )` draws balanced samples by the
  cube method and `spatial_balance()` is the Voronoi measure of Stevens and
  Olsen; `ratio_estimator()` uses a known auxiliary total;
  `multivariate_allocation()` is the Bethel allocation for several study
  variables; `as_frame()` and `as_sf()` move between `sf` layers and frames.

* Review round (engine `fieldopt-core` 0.3.0): the routing local search
  prices every move in the direction travelled, so asymmetric road matrices
  (one-way streets, durations by direction) no longer loop, and the lower
  bound is valid for asymmetric matrices and for several routes;
  `two_stage_allocation()` tries every whole `m`, accepts a fractional
  `m_secondary` and meets its target in small populations;
  `dual_frame_allocation()` reads `sd` as the standard deviation with
  divisor `N - 1` and refuses `theta` outside `[0, 1]` and budgets below two
  units per frame; `select_units()` refuses `size` with `"srs"` (the
  probabilities were mislabelled), duplicate unit names, `n` below the
  number of strata, strata with too few positive sizes and invalid seeds, and
  leaves the user's random-number generator untouched; `point_estimator()`
  refuses missing `y`; `two_stage_design()` and `dual_frame_design()` report
  `converged = FALSE` when the rounds run out; `cost_variance_frontier()`
  takes the coordinate columns from a supplied `matrix`; `core_version()`
  reports the engine crate. New: `autoplot()` for samples, `print()` for
  points, `tidy()`/`glance()` for routes, `glance()` for frontiers.
* The R wrappers are shipped in `R/extendr-wrappers.R` and no longer
  regenerated at install time (`cargo run --bin document`), which failed on
  the CRAN Windows toolchain.

* Area-frame and dual-frame design: `select_units()` gains strata, a
  spatially ordered systematic method with interpenetrating replicates and
  simple random sampling; `select_points()`, `expected_hits()` and
  `point_estimator()` implement point sampling inside segments with the
  multiplicity estimator; `segment_estimator()` gives the closed, open and
  weighted segment estimators; `dual_frame_allocation()` is Hartley's
  allocation with an optimised or fixed mixing weight (screening design);
  `two_stage_allocation()` is Cochran's two-stage allocation with the cost
  function `c1 n + c2 n m`. `design_variance()` chooses the variance
  estimator that matches the design (local-mean, replicates or SRS).
  Engine: `fieldopt-core` 0.2.3.
* `cost_variance_frontier()` accepts `strata`, `selection` and `replicates`,
  a list of per-stratum allocations in `n_grid`, and reports `cost_per_unit`.
* `travel_matrix()` gains a `detour` factor for straight-line distances and
  `method = "osrm"`, road durations or distances from an OSRM server through
  the `osrm` package, requested in blocks; the frontier and the routed designs
  accept the same method.
* `routed_unit_cost()`, `two_stage_design()` and `dual_frame_design()`
  iterate the allocation with the cost per area unit measured by routing;
  `point_design_effect()` simulates the area design and returns the bias,
  variance and design effect of point sampling; `select_points()` gains a
  systematic layout; `tidy()` and `glance()` for the three allocations.
* Variances are computed within strata and summed (`"stratified srs"`,
  `"stratified local-mean"`); route plots of geographic matrices put longitude
  on the x axis.

* First version: travel matrices from coordinates or a road network
  (`travel_matrix()`), a field cost model (`field_cost_model()`), GRASP routing
  of the field work for one or several teams (`route_fieldwork()`), spatially
  balanced selection of units with the local pivotal method (`select_units()`),
  Horvitz-Thompson estimation with the local-mean variance estimator
  (`design_variance()`), cost-aware allocation across strata or frames
  (`frame_allocation()`) and the cost-variance frontier of a design by
  simulation (`cost_variance_frontier()`). The engine is the Rust crate
  `fieldopt-core`.
