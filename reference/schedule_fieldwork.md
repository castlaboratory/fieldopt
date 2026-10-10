# Schedule the field work of several teams from several bases

Solves the assignment of the units to bases (depots) and their routing
jointly, as one multi-depot problem: every route (one team-day) leaves
from and returns to one base, each base may send at most `teams * days`
routes, and the objective is the total travel plus the `per_route` cost
of the cost model for every route opened. The routes of each base are
then distributed over its teams and the days available, longest routes
first, so that the teams finish as evenly as possible. The result is a
calendar: which team visits which units on which day, and whether the
work fits.

## Usage

``` r
schedule_fieldwork(
  matrix,
  units,
  teams,
  days,
  bases = NULL,
  max_length = Inf,
  max_stops = Inf,
  service_time = 0,
  cost_model = NULL,
  iterations = 200,
  time_limit = NULL,
  alpha = 0.3,
  seed = 1,
  engine = c("fieldopt", "vrpr")
)
```

## Arguments

- matrix:

  A
  [`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
  holding the units and the bases.

- units:

  Names of the units to visit.

- teams:

  Named vector: number of teams per base (names are units of the matrix
  that act as bases). A single unnamed number with one base is accepted
  when `bases` is given.

- days:

  Number of working days available.

- bases:

  Optional names of the bases when `teams` is unnamed.

- max_length, max_stops, service_time:

  Daily limits of a route, as in
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md).

- cost_model:

  Optional
  [`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md);
  its `per_route` cost is charged once per team-day and enters the
  objective.

- iterations, time_limit, alpha, seed, engine:

  Solver settings of
  [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md);
  both engines solve the multi-depot problem jointly.

## Value

An object of class `fieldopt_schedule`: `calendar` (a tibble with one
row per route: `base`, `team`, `day`, `route`, `stops`, `travel`,
`duration`, and `units` as a list column), `assignment` (unit, base),
`routes` (the
[`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md)
solution of each base), `summary` (per base: units, teams, routes, days
needed, days available, whether it fits), `fits` and `cost`.

## Details

When the team-days of the bases are not enough, the routes are solved
without the limit per base and the calendar reports how many days each
base would need (`fits` is `FALSE`).

## Examples

``` r
set.seed(5)
pts <- data.frame(unit = c("base1", "base2", paste0("s", 1:30)),
                  x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10)))
m <- travel_matrix(pts, method = "euclidean")
sch <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 1),
                          days = 4, max_stops = 4, iterations = 30)
sch
#> 
#> ── Field schedule ──────────────────────────────────────────────────────────────
#> 30 units, 2 bases, 3 teams, 4 days available: the work fits.
#> "base1": 14 units, 2 teams, 4 routes, 2 of 4 days.
#> "base2": 16 units, 1 team, 4 routes, 4 of 4 days.
sch$calendar
#> # A tibble: 8 × 8
#>   base  team      day route stops travel duration units    
#>   <chr> <chr>   <int> <int> <int>  <dbl>    <dbl> <list>   
#> 1 base1 base1-1     1     1     4  16.9     16.9  <chr [4]>
#> 2 base1 base1-1     2     2     3   6.14     6.14 <chr [3]>
#> 3 base1 base1-2     1     4     4  12.8     12.8  <chr [4]>
#> 4 base1 base1-2     2     3     3   7.44     7.44 <chr [3]>
#> 5 base2 base2-1     1     3     4  13.7     13.7  <chr [4]>
#> 6 base2 base2-1     2     4     4  10.7     10.7  <chr [4]>
#> 7 base2 base2-1     3     1     4   9.32     9.32 <chr [4]>
#> 8 base2 base2-1     4     2     4   8.87     8.87 <chr [4]>
```
