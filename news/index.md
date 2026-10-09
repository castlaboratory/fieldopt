# Changelog

## fieldopt 0.1.0

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
