# fieldopt 0.1.0

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
