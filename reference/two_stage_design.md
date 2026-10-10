# Two-stage allocation with the primary-unit cost taken from the routing

[`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md)
needs the cost `c1` of visiting a primary unit, which is not a constant:
a tour shares its travel among the units it visits, so the routed cost
`G(n)` of visiting `n` units grows like `c0 + a n + b sqrt(n)`
(Beardwood, Halton and Hammersley). This function measures `G(n)` by
routing samples at a few sizes around the current allocation, fits that
curve, and re-allocates with the **marginal** cost `G'(n)` in place of
`c1`; with a nonlinear cost the optimal number of secondary units is
Cochran's formula with the marginal, not the average, cost per primary
unit. Under a budget the number of primary units then comes from the
fitted curve, so the design spends the budget at its real routed cost.
It stops when `n` no longer changes (or after `max_iter` rounds; a
two-cycle stops with the better of the two designs).

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
  max_iter = 8,
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

  Starting value of the cost per primary unit (default: the per-visit
  cost plus the travel cost of the median trip from the depot).

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

  Routed samples per sample size of the cost curve.

- iterations:

  GRASP iterations per routing.

- seed:

  Seed.

## Value

The final `fieldopt_two_stage` allocation, with `cost` the routed cost
`G(n) + c2 n m`, and the extra elements `c1` (the marginal cost used),
`c1_average` (`G(n)/n`), `cost_curve` (the routed points: `n`,
`cost_mean`, `cost_sd`), `cost_coef` (`c0`, `a`, `b`), `history` (one
row per round: `round`, `c1`, `c1_average`, `n`, `m`, `cost`,
`variance_total`) and `converged`.

## Details

Using the average cost `G(n)/n` instead takes too few primary units: in
the package's experiments the marginal rule was within 0.2 percent of
the cost of the best design found by exhaustive search, the average rule
up to 3 percent above it, and a constant `c1` guessed from depot
distances 7 to 19 percent above.

## References

Cochran, W. G. (1977). *Sampling Techniques*, 3rd ed., Section 10.6.
Beardwood, J., Halton, J. H. and Hammersley, J. M. (1959). The shortest
path through many points. *Proc. Cambridge Phil. Soc.*, 55, 299-327.

## Examples

``` r
set.seed(2)
cells <- expand.grid(x = 1:15, y = 1:15)
cells$unit <- paste0("c", seq_len(nrow(cells)))
frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
model <- field_cost_model(
  per_travel = 3, per_unit = 40, per_interview = 20,
  interviews_per_unit = 1
)
two_stage_design(frame, "depot", model,
  m_secondary = 12, s2_between = 9, s2_within = 40,
  target_cv = 0.05, mean = 10, method = "euclidean", n_rep = 2,
  iterations = 20
)
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 55 primary units with m = 4 secondary units each (optimal m 3.87): cost
#> 6899, variance of the total 1785000 (SE 1336, CV 4.95%).
```
