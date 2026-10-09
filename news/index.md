# Changelog

## fieldopt 0.1.0

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
  replicates or SRS). Engine: `fieldopt-core` 0.2.0.

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
