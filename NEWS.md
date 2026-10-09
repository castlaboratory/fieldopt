# fieldopt 0.1.0

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
  Engine: `fieldopt-core` 0.2.0.

* First version: travel matrices from coordinates or a road network
  (`travel_matrix()`), a field cost model (`field_cost_model()`), GRASP routing
  of the field work for one or several teams (`route_fieldwork()`), spatially
  balanced selection of units with the local pivotal method (`select_units()`),
  Horvitz-Thompson estimation with the local-mean variance estimator
  (`design_variance()`), cost-aware allocation across strata or frames
  (`frame_allocation()`) and the cost-variance frontier of a design by
  simulation (`cost_variance_frontier()`). The engine is the Rust crate
  `fieldopt-core`.
