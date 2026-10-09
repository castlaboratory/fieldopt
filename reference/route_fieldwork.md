# Route the field work

Finds low-cost routes from a depot through the selected units with GRASP
(randomised greedy construction, 2-opt and Or-opt local search, optimal
split of the tour into routes under the limits). One route when the
limits allow it, several otherwise (one per team or per day). The
solution is a heuristic; the gap to a lower bound is reported.

## Usage

``` r
route_fieldwork(
  matrix,
  units,
  depot,
  max_length = Inf,
  max_stops = Inf,
  iterations = 200,
  alpha = 0.3,
  seed = 1,
  cost_model = NULL
)
```

## Arguments

- matrix:

  A
  [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md).

- units:

  Names (or indices in the matrix) of the units to visit.

- depot:

  Name (or index) of the depot.

- max_length:

  Maximum travel per route, depot to depot; `Inf` for none.

- max_stops:

  Maximum units per route; `Inf` for none.

- iterations:

  GRASP iterations.

- alpha:

  Greediness of the construction in `[0, 1]` (0 greedy, 1 random).

- seed:

  Seed of the solver.

- cost_model:

  Optional
  [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md)
  to price the solution.

## Value

An object of class `fieldopt_routes`: `routes` (a tibble with columns
`route`, `stop`, `unit`), `lengths`, `total`, `lower_bound`, `gap`,
`best_iteration`, `cost` (when a model is given), the inputs and the
travel matrix.

## Examples

``` r
set.seed(1)
pts <- data.frame(unit = c("depot", paste0("s", 1:12)),
                  x = c(0, runif(12, 0, 10)), y = c(0, runif(12, 0, 10)))
m <- travel_matrix(pts, method = "euclidean")
r <- route_fieldwork(m, units = paste0("s", 1:12), depot = "depot", max_stops = 5,
                     iterations = 50)
r
#> 
#> ── Field routes ────────────────────────────────────────────────────────────────
#> 4 routes from "depot" through 12 units: total travel 61.76 distance (lower
#> bound 18.79, gap 229%).
#> Route 1 (4.333): s12
#> Route 2 (30.53): s2 > s9 > s6 > s4 > s7
#> Route 3 (22.47): s8 > s3 > s1 > s5 > s11
#> Route 4 (4.419): s10
```
