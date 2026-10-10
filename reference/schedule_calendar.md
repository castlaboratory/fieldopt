# Redistribute the routes of a schedule over teams and days with constraints

[`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md)
hands the routes of each base to its teams with a simple rule (longest
route first, one route per team-day). This function solves that
distribution exactly as a small integer programme, through the `highs`
package (in Suggests), which allows the constraints of real field work:
teams unavailable on some days, routes fixed to a team or a day, routes
that must precede others, a daily limit per team that lets two short
routes share one team-day. The objective finishes as early as possible:
it minimises the last working day of the schedule and, among schedules
with the same end, the sum of the days on which routes are done.

## Usage

``` r
schedule_calendar(
  schedule,
  availability = NULL,
  fixed = NULL,
  before = NULL,
  daily_limit = NULL,
  time_limit = 10
)
```

## Arguments

- schedule:

  A `fieldopt_schedule` from
  [`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md).

- availability:

  Optional data frame with columns `team`, `day` and `available`
  (logical): the team-days that are not listed are available. Team names
  are those of the calendar (`"base-1"`, `"base-2"`, ...).

- fixed:

  Optional data frame with columns `base`, `route` and `team` and/or
  `day`: routes that must go to that team and/or that day.

- before:

  Optional data frame with columns `base`, `route`, `base_after` and
  `route_after`: the first route must be done on an earlier day than the
  second.

- daily_limit:

  Maximum duration of a team-day (in the unit of the travel matrix); the
  routes already respect the `max_length` of the schedule, so this is
  only useful to let several short routes share a day. `NULL` keeps one
  route per team-day.

- time_limit:

  Seconds allowed to the solver.

## Value

The schedule with its `calendar`, `summary` and `fits` recomputed, plus
`solver` (`"highs"`), `objective` and `status`. An error when no
calendar satisfies the constraints within `days`.

## Examples

``` r
set.seed(5)
pts <- data.frame(
  unit = c("base1", "base2", paste0("s", 1:30)),
  x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10))
)
m <- travel_matrix(pts, method = "euclidean")
sch <- schedule_fieldwork(m,
  units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 1),
  days = 5, max_stops = 4, iterations = 30
)
if (requireNamespace("highs", quietly = TRUE)) {
  off <- data.frame(team = "base1-1", day = 1, available = FALSE)
  schedule_calendar(sch, availability = off)
}
#> 
#> ── Field schedule ──────────────────────────────────────────────────────────────
#> 30 units, 2 bases, 3 teams, 5 days available: the work fits.
#> "base1": 12 units, 2 teams, 3 routes, 2 of 5 days.
#> "base2": 18 units, 1 team, 5 routes, 5 of 5 days.
```
