# Two-stage allocation with the primary-unit cost taken from the routing

[`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md)
needs the cost `c1` of visiting a primary unit, which depends on how
many units are visited. This function iterates: it allocates with a
starting `c1`, routes a sample of the allocated size to measure the cost
per unit, allocates again, and stops when the number of primary units no
longer changes (or after `max_iter` rounds). The cost model's
per-interview cost is `c2`; the travel and per-visit costs make `c1`.

## Usage

``` r
two_stage_design(
  frame,
  depot,
  cost_model,
  m_secondary,
  s2_between,
  s2_within,
  target_variance = NULL,
  target_cv = NULL,
  budget = NULL,
  mean = NULL,
  c1_start = NULL,
  max_iter = 6,
  size = NULL,
  strata = NULL,
  selection = c("lpm", "systematic", "srs"),
  matrix = NULL,
  method = c("haversine", "euclidean", "osrm"),
  max_length = Inf,
  max_stops = Inf,
  n_rep = 5,
  iterations = 100,
  seed = 1
)
```

## Arguments

- frame:

  Data frame of units as in
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md),
  including the depot row named in `depot`.

- depot:

  Name of the depot unit in `frame$unit`.

- cost_model:

  A
  [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md).

- m_secondary:

  Secondary units per primary unit in the population.

- s2_between, s2_within:

  Variance among primary-unit means and within primary units.

- target_variance, target_cv, budget:

  Exactly one: target variance of the estimated **total**, target
  coefficient of variation (needs `mean`), or budget.

- mean:

  Population mean per secondary unit, for `target_cv`.

- c1_start:

  Starting value of the cost per primary unit.

- max_iter:

  Maximum number of rounds.

- size:

  Optional size column for probability-proportional-to-size selection.

- strata:

  Optional stratum column, passed to
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md).

- selection:

  Selection method of
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md):
  `"lpm"`, `"systematic"` or `"srs"`.

- matrix:

  Optional
  [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  of the frame (computed from the coordinates otherwise).

- method:

  Distance method of
  [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  when `matrix` is `NULL` (`"osrm"` queries the road network once for
  the whole frame).

- max_length, max_stops:

  Route limits passed to
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md).

- n_rep:

  Routed samples per round.

- iterations:

  GRASP iterations per routing.

- seed:

  Seed.

## Value

The final `fieldopt_two_stage` allocation with an extra element
`history` (a tibble with one row per round: `round`, `c1`, `n`, `m`,
`cost`, `variance_total`) and `c1`.

## Examples

``` r
set.seed(2)
cells <- expand.grid(x = 1:15, y = 1:15); cells$unit <- paste0("c", seq_len(nrow(cells)))
frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
model <- field_cost_model(per_travel = 3, per_unit = 40, per_interview = 20,
                          interviews_per_unit = 1)
two_stage_design(frame, "depot", model, m_secondary = 12, s2_between = 9, s2_within = 40,
                 target_cv = 0.05, mean = 10, method = "euclidean", n_rep = 2,
                 iterations = 20)
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 55 primary units with m = 4 secondary units each (optimal m 4.01): cost
#> 6904, variance of the total 1785000 (SE 1336, CV 4.95%).
```
