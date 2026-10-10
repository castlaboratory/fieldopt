# Routed cost curve of a design: the travel constant of Hansen, Hurwitz and Madow

Selects samples of each size in `n_grid`, routes each one from the depot
(or bases), prices it with the cost model, and fits the expected cost as
`G(n) = c0 + a n + b sqrt(n)`. This is the cost function of Hansen,
Hurwitz and Madow (1953, Vol. I, Chapter 6, Section 12),
`C0 sqrt(m) + C1 m`, with `b` in the role of their travel constant `C0`
and `a` of the cost per primary unit `C1`. They derived `C0` from points
on a regular grid and called it a rough approximation; here it is
measured on the frame, with its roads (when the matrix comes from OSRM),
its depots and its route limits. The travel of a tour through `n`
scattered points grows like `sqrt(n)` (Beardwood, Halton and Hammersley
1959), and fixed costs per visit and per route add the linear term.

## Usage

``` r
routed_cost_curve(
  frame,
  depot,
  cost_model,
  n_grid,
  size = NULL,
  strata = NULL,
  selection = c("lpm", "systematic", "srs"),
  replicates = 1,
  matrix = NULL,
  method = c("haversine", "euclidean", "osrm"),
  max_length = Inf,
  max_stops = Inf,
  n_rep = 10,
  iterations = 100,
  seed = 1
)

# S3 method for class 'fieldopt_cost_curve'
predict(object, newdata, type = c("total", "average", "marginal"), ...)

# S3 method for class 'fieldopt_cost_curve'
tidy(x, ...)

# S3 method for class 'fieldopt_cost_curve'
glance(x, ...)

# S3 method for class 'fieldopt_cost_curve'
autoplot(object, ...)
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

- n_grid:

  Sample sizes to route (at least three distinct values for the three
  coefficients).

- size:

  Optional size column for probability-proportional-to-size selection.

- strata:

  Optional stratum column, passed to
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md).

- selection:

  Selection method of
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md):
  `"lpm"`, `"systematic"` or `"srs"`.

- replicates:

  Replicates of a `"systematic"` selection.

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

  Routed samples per sample size.

- iterations:

  GRASP iterations per routing.

- seed:

  Seed.

- newdata:

  Sample sizes (a numeric vector) for
  [`predict()`](https://rdrr.io/r/stats/predict.html).

- type:

  `"total"` for `G(n)`, `"average"` for `G(n)/n`, `"marginal"` for
  `G'(n)`.

- ...:

  Unused.

- x, object:

  A `fieldopt_cost_curve`.

## Value

An object of class `fieldopt_cost_curve`: a list with `points` (a tibble
with `n`, `cost_mean`, `cost_sd`, `travel_mean`, `routes_mean` per
routed size), `coef` (`c0`, `a`, `b`), `r_squared`, `currency` and the
settings. [`predict()`](https://rdrr.io/r/stats/predict.html) gives the
total, average or marginal cost at any `n`;
[`tidy()`](https://generics.r-lib.org/reference/tidy.html),
[`glance()`](https://generics.r-lib.org/reference/glance.html) and
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
are available.

## Details

The fit is constrained to be increasing and concave (`a >= 0`,
`b >= 0`), so the marginal cost `G'(n) = a + b / (2 sqrt(n))` is
positive and falls with `n`. The marginal cost is the one the classical
allocation formulas need (see
[`two_stage_design()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_design.md)).

## References

Hansen, M. H., Hurwitz, W. N. and Madow, W. G. (1953). *Sample Survey
Methods and Theory*, Vol. I, Chapter 6, Sections 11-15, and Vol. II,
Chapter 6, Section 11. Wiley. Beardwood, J., Halton, J. H. and
Hammersley, J. M. (1959). The shortest path through many points. *Proc.
Cambridge Phil. Soc.*, 55, 299-327.

## Examples

``` r
set.seed(2)
cells <- expand.grid(x = 1:15, y = 1:15)
cells$unit <- paste0("c", seq_len(nrow(cells)))
frame <- rbind(data.frame(unit = "depot", x = 8, y = 8), cells)
model <- field_cost_model(per_travel = 3, per_unit = 40)
curve <- routed_cost_curve(frame, "depot", model,
  n_grid = c(10, 20, 40, 80), method = "euclidean", n_rep = 2,
  iterations = 20
)
curve
#> 
#> ── Routed cost curve ───────────────────────────────────────────────────────────
#> G(n) = 1.339 + 39.05 n + 47.64 sqrt(n) (cost; 4 sample sizes from 10 to 80, 2
#> routed samples each, lpm selection; R-squared 1).
#> In Hansen, Hurwitz and Madow's notation: C0 = 47.64 (travel), C1 = 39.05 (per
#> primary unit).
#> At n = 30: average cost 47.79, marginal cost 43.4 per unit.
predict(curve, c(30, 60), type = "marginal")
#> [1] 43.39533 42.12147
```
