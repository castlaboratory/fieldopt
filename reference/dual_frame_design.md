# Dual-frame allocation with the area-frame cost taken from the routing

[`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
needs the cost per unit of the area frame, which depends on how many
area units are visited. This function iterates between the allocation
and the routing of a sample of `n_a` area units until `n_a` stabilises.
The cost model prices the area units; `cost_b` is the list cost per
unit.

## Usage

``` r
dual_frame_design(
  frame,
  depot,
  cost_model,
  domains,
  cost_b,
  deff_a = 1,
  deff_b = 1,
  theta = NULL,
  target_variance = NULL,
  target_cv = NULL,
  budget = NULL,
  interviews_per_unit = NULL,
  cost_a_start = NULL,
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

- domains:

  Data frame with one row per domain `a`, `ab`, `b` (column `domain`)
  and columns `size` (units), `mean` and `sd` of the study variable.

- cost_b:

  Cost per sampled unit of the list frame.

- deff_a, deff_b:

  Design effects of the two samples relative to simple random sampling
  (an area sample of segments or points usually has `deff_a > 1`).

- theta:

  `NULL` to optimise, a number in `[0, 1]`, or `"screening"` (zero).

- target_variance, target_cv, budget:

  Exactly one: target variance of the estimated total, target
  coefficient of variation (relative to the population total implied by
  `domains`), or budget.

- interviews_per_unit:

  Expected interviews per visited area unit (for the cost model; the
  model's own value is used when `NULL`).

- cost_a_start:

  Starting value of the cost per area unit.

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

The final `fieldopt_dual_frame` allocation with `history` (one row per
round: `round`, `cost_a`, `n_a`, `n_b`, `theta`, `cost`, `variance`).

## Examples

``` r
set.seed(3)
cells <- expand.grid(x = 1:15, y = 1:15); cells$unit <- paste0("c", seq_len(nrow(cells)))
frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
model <- field_cost_model(per_travel = 3, per_unit = 40, per_interview = 20,
                          interviews_per_unit = 3)
domains <- data.frame(domain = c("a", "ab", "b"), size = c(600, 80, 20),
                      mean = c(6, 30, 45), sd = c(5, 20, 35))
dual_frame_design(frame, "depot", model, domains, cost_b = 45, deff_a = 1.5,
                  target_cv = 0.05, method = "euclidean", n_rep = 2, iterations = 20)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 119000: n_A = 114 (frame A, cost 103.7/unit),
#> n_B = 100 (frame B, cost 45/unit), theta = 0.096 (optimised).
#> Cost 16320; variance 119000 (frame A 119000, frame B 0); CV 5% of the total
#> 6900.
#> Expected overlap units: 13.4 in the A sample, 80 in the B sample; a bound on a
#> sample size was active.
```
