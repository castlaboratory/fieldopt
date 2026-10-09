# Cost-variance frontier of a design by simulation

For each sample size in `n_grid`, draws `n_rep` spatially balanced
samples from the frame, routes the field work from the depot, prices it
with the cost model and, when a study variable is given, estimates the
variance of the total. The result is the trade-off a survey planner
faces: how much the field work costs and how precise the estimate is at
each sample size.

## Usage

``` r
cost_variance_frontier(
  frame,
  depot,
  cost_model,
  n_grid,
  y = NULL,
  size = NULL,
  matrix = NULL,
  method = c("haversine", "euclidean"),
  max_length = Inf,
  max_stops = Inf,
  n_rep = 20,
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

- n_grid:

  Sample sizes to evaluate.

- y:

  Optional column of the study variable for the whole frame (a planning
  value); when given, the variance of the estimated total is computed
  from the local-mean estimator on each simulated sample.

- size:

  Optional size column for probability-proportional-to-size selection.

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

A tibble of class `fieldopt_frontier` with one row per sample size: `n`,
`cost_mean`, `cost_sd`, `travel_mean`, `routes_mean`, `variance_mean`
and `cv_mean` (when `y` is given), `n_rep`.

## Examples

``` r
set.seed(3)
frame <- data.frame(unit = c("depot", paste0("s", 1:40)),
                    x = c(5, runif(40, 0, 10)), y = c(5, runif(40, 0, 10)))
frame$crop <- c(NA, 20 + 3 * frame$x[-1] + rnorm(40))
model <- field_cost_model(per_travel = 2, per_unit = 30, per_interview = 10,
                          interviews_per_unit = 4)
cost_variance_frontier(frame, depot = "depot", cost_model = model, n_grid = c(8, 16),
                       y = "crop", method = "euclidean", n_rep = 3, iterations = 20)
#> # A tibble: 2 × 8
#>       n cost_mean cost_sd travel_mean routes_mean variance_mean cv_mean n_rep
#> * <dbl>     <dbl>   <dbl>       <dbl>       <dbl>         <dbl>   <dbl> <dbl>
#> 1     8      619.    2.63        29.5           1         8199.  0.0664     3
#> 2    16     1193.    3.47        36.5           1          800.  0.0211     3
```
