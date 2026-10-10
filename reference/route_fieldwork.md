# Route the field work

Finds low-cost routes from a depot through the selected units: one route
when the limits allow it, several otherwise (one per team or per day).
Instances of up to 13 units are solved exactly (dynamic programming over
subsets). Larger ones go to a hybrid genetic search (Vidal 2022): a
population of giant tours, order crossover, the optimal split of Prins
(2004) under the limits, and a local search with granular neighbourhoods
(2-opt, Or-opt, relocate, swap, 2-opt\*). The `gap` to a lower bound is
reported: the Held-Karp bound for a single tour on a symmetric matrix
(usually within a few percent of the optimum), a loose bound otherwise;
`optimal` says when the solution is proven optimal.

## Usage

``` r
route_fieldwork(
  matrix,
  units,
  depot,
  max_length = Inf,
  max_stops = Inf,
  service_time = 0,
  demand = 0,
  capacity = Inf,
  iterations = 200,
  time_limit = NULL,
  alpha = 0.3,
  seed = 1,
  cost_model = NULL,
  engine = c("fieldopt", "vrpr")
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

  Maximum length of a route, depot to depot: travel plus the service
  time of its units when `service_time` is given; `Inf` for none.

- max_stops:

  Maximum units per route; `Inf` for none.

- service_time:

  Time spent at each unit (interviews, measurements), in the unit of the
  travel matrix: a single number, or a vector named by unit. It counts
  towards `max_length` and is reported in `durations`.

- demand:

  Load each unit adds to its route (interviews to make, samples to
  carry): a single number or a vector named by unit.

- capacity:

  Maximum load of a route; `Inf` for none.

- iterations:

  Offspring of the genetic search (ignored when the instance is solved
  exactly or when `time_limit` is given).

- time_limit:

  Seconds of search instead of `iterations` (`NULL` for none); the only
  stopping rule of the `"vrpr"` engine (default 5 s).

- alpha:

  Greediness of the constructions that seed the population, in `[0, 1]`
  (0 greedy, 1 random).

- seed:

  Seed of the solver.

- cost_model:

  Optional
  [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md)
  to price the solution.

- engine:

  `"fieldopt"` (the built-in solver) or `"vrpr"`, the PyVRP solver
  through the `vrpr` package (in Suggests), with the same inputs and
  outputs, except that it takes one of `max_stops` and `capacity` and
  gives no lower bound. Both engines charge a cost model's `per_route`
  inside the objective (as `per_route / per_travel` travel units per
  route), so the number of routes is itself optimised when a cost model
  is given.

## Value

An object of class `fieldopt_routes`: `routes` (a tibble with columns
`route`, `stop`, `unit`), `lengths` (travel per route), `durations`
(travel plus service), `loads`, `total`, `lower_bound`, `gap`,
`optimal`, `best_iteration`, `cost` (when a model is given), the inputs
and the travel matrix.

## References

Vidal, T. (2022). Hybrid genetic search for the CVRP: open-source
implementation and SWAP\* neighborhood. *Computers & Operations
Research*, 140, 105643. Prins, C. (2004). A simple and effective
evolutionary algorithm for the vehicle routing problem. *Computers &
Operations Research*, 31, 1985-2002. Held, M. and Karp, R. M. (1971).
The traveling-salesman problem and minimum spanning trees: part II.
*Mathematical Programming*, 1, 6-25.

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
#> 3 routes from "depot" through 12 units: total travel 57.81 distance (proven
#> optimal).
#> Route 1 (21.08): s11 > s5 > s1 > s3 > s2
#> Route 2 (30.92): s8 > s9 > s6 > s4 > s7
#> Route 3 (5.814): s10 > s12
```
