# Field cost per sampled unit at a given sample size, from the routing

Selects `n` units from the frame `n_rep` times, routes each sample from
the depot, prices it with the cost model and returns the mean cost per
sampled unit. This is the planning value of the cost of a primary unit
(`c1` in
[`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md))
or of an area-frame unit (`cost_a` in
[`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md));
it depends on `n` because a larger sample is denser and cheaper to reach
per unit.

## Usage

``` r
routed_unit_cost(
  frame,
  depot,
  cost_model,
  n,
  size = NULL,
  strata = NULL,
  selection = c("lpm", "systematic", "srs"),
  replicates = 1,
  matrix = NULL,
  method = c("haversine", "euclidean"),
  max_length = Inf,
  max_stops = Inf,
  n_rep = 10,
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

- n:

  Sample size (a number, or a vector named by stratum).

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

  Distance method when `matrix` is `NULL`.

- max_length, max_stops:

  Route limits passed to
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md).

- n_rep:

  Replications per sample size.

- iterations:

  GRASP iterations per routing.

- seed:

  Seed.

## Value

A one-row tibble: `n`, `cost_per_unit`, `travel_per_unit`, `cost_mean`,
`routes_mean`, `n_rep`.

## Examples

``` r
set.seed(1)
frame <- data.frame(unit = c("depot", paste0("s", 1:40)),
                    x = c(5, runif(40, 0, 10)), y = c(5, runif(40, 0, 10)))
model <- field_cost_model(per_travel = 2, per_unit = 30, per_interview = 10,
                          interviews_per_unit = 4)
routed_unit_cost(frame, "depot", model, n = 12, method = "euclidean", n_rep = 3,
                 iterations = 20)
#> # A tibble: 1 × 6
#>       n cost_per_unit travel_per_unit cost_mean routes_mean n_rep
#>   <dbl>         <dbl>           <dbl>     <dbl>       <dbl> <dbl>
#> 1    12          75.8            2.91      910.           1     3
```
