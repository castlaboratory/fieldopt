# fieldopt 0.1.0

* First version: travel matrices from coordinates or a road network
  (`travel_matrix()`), a field cost model (`field_cost_model()`), GRASP routing
  of the field work for one or several teams (`route_fieldwork()`), spatially
  balanced selection of units with the local pivotal method (`select_units()`),
  Horvitz-Thompson estimation with the local-mean variance estimator
  (`design_variance()`), cost-aware allocation across strata or frames
  (`frame_allocation()`) and the cost-variance frontier of a design by
  simulation (`cost_variance_frontier()`). The engine is the Rust crate
  `fieldopt-core`.
