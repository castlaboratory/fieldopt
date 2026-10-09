# Package index

## Travel and cost

- [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  : Travel matrix between the units of a frame
- [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md)
  : Field cost model

## Routing the field work

- [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
  : Route the field work
- [`autoplot(`*`<fieldopt_routes>`*`)`](https://castlaboratory.github.io/fieldopt/reference/autoplot.fieldopt_routes.md)
  : Plot the routes
- [`tidy(`*`<fieldopt_routes>`*`)`](https://castlaboratory.github.io/fieldopt/reference/routes-methods.md)
  [`glance(`*`<fieldopt_routes>`*`)`](https://castlaboratory.github.io/fieldopt/reference/routes-methods.md)
  [`glance(`*`<fieldopt_frontier>`*`)`](https://castlaboratory.github.io/fieldopt/reference/routes-methods.md)
  : Tidy and glance methods for routes and frontiers

## Selecting units and points

- [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  : Select units with a spatially balanced or systematic probability
  sample
- [`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md)
  : Select points inside sampled grid cells
- [`autoplot(`*`<fieldopt_sample>`*`)`](https://castlaboratory.github.io/fieldopt/reference/autoplot.fieldopt_sample.md)
  : Plot a sample of units

## Estimating

- [`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)
  : Design-based estimate of a total with its variance
- [`segment_estimator()`](https://castlaboratory.github.io/fieldopt/reference/segment_estimator.md)
  : Segment estimators of a total from an area sample of segments
- [`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
  : Multiplicity (point) estimator of a total from an area sample of
  points
- [`expected_hits()`](https://castlaboratory.github.io/fieldopt/reference/expected_hits.md)
  : Expected number of point hits of each establishment
- [`point_design_effect()`](https://castlaboratory.github.io/fieldopt/reference/point_design_effect.md)
  : Design effect and bias of point sampling by simulation

## Allocation

- [`frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/frame_allocation.md)
  : Cost-aware allocation across strata
- [`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
  : Dual-frame allocation (area frame plus list frame with overlap)
- [`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md)
  : Two-stage allocation with a field cost function
- [`tidy(`*`<fieldopt_allocation>`*`)`](https://castlaboratory.github.io/fieldopt/reference/allocation-methods.md)
  [`glance(`*`<fieldopt_allocation>`*`)`](https://castlaboratory.github.io/fieldopt/reference/allocation-methods.md)
  [`tidy(`*`<fieldopt_dual_frame>`*`)`](https://castlaboratory.github.io/fieldopt/reference/allocation-methods.md)
  [`glance(`*`<fieldopt_dual_frame>`*`)`](https://castlaboratory.github.io/fieldopt/reference/allocation-methods.md)
  [`tidy(`*`<fieldopt_two_stage>`*`)`](https://castlaboratory.github.io/fieldopt/reference/allocation-methods.md)
  [`glance(`*`<fieldopt_two_stage>`*`)`](https://castlaboratory.github.io/fieldopt/reference/allocation-methods.md)
  : Tidy and glance methods for allocations

## Allocation with the routed field cost

- [`routed_unit_cost()`](https://castlaboratory.github.io/fieldopt/reference/routed_unit_cost.md)
  : Field cost per sampled unit at a given sample size, from the routing
- [`two_stage_design()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_design.md)
  : Two-stage allocation with the primary-unit cost taken from the
  routing
- [`dual_frame_design()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_design.md)
  : Dual-frame allocation with the area-frame cost taken from the
  routing

## The cost-variance frontier

- [`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
  : Cost-variance frontier of a design by simulation
- [`autoplot(`*`<fieldopt_frontier>`*`)`](https://castlaboratory.github.io/fieldopt/reference/autoplot.fieldopt_frontier.md)
  : Plot the cost-variance frontier

## Engine

- [`core_version()`](https://castlaboratory.github.io/fieldopt/reference/core_version.md)
  : Version of the Rust engine

## Re-exports

- [`reexports`](https://castlaboratory.github.io/fieldopt/reference/reexports.md)
  [`autoplot`](https://castlaboratory.github.io/fieldopt/reference/reexports.md)
  [`tidy`](https://castlaboratory.github.io/fieldopt/reference/reexports.md)
  [`glance`](https://castlaboratory.github.io/fieldopt/reference/reexports.md)
  : Objects exported from other packages
