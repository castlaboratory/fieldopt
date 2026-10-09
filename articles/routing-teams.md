# Routing for one or several teams

The same sample can be worked by one team on a long tour or by several
teams on short routes. The total travel differs, the number of days
differs and the cost differs. This vignette compares those organisations
on one sample.

``` r

library(fieldopt)
set.seed(7)
frame <- data.frame(unit = c("depot", paste0("s", 1:60)),
                    lat = c(-8.05, -8.05 + runif(60, -0.25, 0.25)),
                    lon = c(-35.00, -35.00 + runif(60, -0.35, 0.35)))
m <- travel_matrix(frame)
model <- field_cost_model(per_travel = 1.8, per_unit = 40, per_interview = 12,
                          interviews_per_unit = 6, currency = "BRL")
s <- select_units(frame[-1, ], n = 18, seed = 3)
sel <- s$unit[s$sampled]
```

## One tour

``` r

one <- route_fieldwork(m, units = sel, depot = "depot", cost_model = model)
one
#> 
#> ── Field routes ────────────────────────────────────────────────────────────────
#> 1 route from "depot" through 18 units: total travel 281.1 km (lower bound
#> 249.6, gap 12.6%).
#> Route 1 (281.1): s30 > s9 > s32 > s27 > s48 > s1 > s29 > s31 > s43 > s19 > s6 >
#> s13 > s54 > s47 > s4 > s16 > s12 > s37
#> Cost (BRL): travel 506 + routes 0 + units 720 + interviews 1296 = 2522.
```

## Routes limited by length

A team that must return to the depot every day has a maximum route
length, here 100 km. The solver splits the tour optimally under that
limit (Prins 2004) and improves each route locally.

``` r

days <- route_fieldwork(m, units = sel, depot = "depot", max_length = 100,
                        cost_model = model)
days
#> 
#> ── Field routes ────────────────────────────────────────────────────────────────
#> 5 routes from "depot" through 18 units: total travel 403.1 km (lower bound
#> 213.2, gap 89%).
#> Route 1 (86.76): s37 > s54 > s13 > s6 > s19 > s43
#> Route 2 (97.48): s47 > s4 > s16 > s12
#> Route 3 (88.51): s30 > s9 > s32
#> Route 4 (99.02): s27 > s48 > s1 > s29
#> Route 5 (31.29): s31
#> Cost (BRL): travel 725.5 + routes 0 + units 720 + interviews 1296 = 2741.
autoplot(days)
```

![](routing-teams_files/figure-html/days-1.png)

## Routes limited by stops

A team that can interview at most four units a day has a stop limit
instead.

``` r

stops <- route_fieldwork(m, units = sel, depot = "depot", max_stops = 4,
                         cost_model = model)
stops
#> 
#> ── Field routes ────────────────────────────────────────────────────────────────
#> 6 routes from "depot" through 18 units: total travel 406.2 km (lower bound
#> 213.2, gap 90.5%).
#> Route 1 (19.98): s30
#> Route 2 (97.48): s12 > s16 > s4 > s47
#> Route 3 (120.2): s9 > s32 > s27 > s48
#> Route 4 (79.38): s31 > s1 > s29 > s43
#> Route 5 (82.91): s6 > s19 > s13 > s54
#> Route 6 (6.175): s37
#> Cost (BRL): travel 731.1 + routes 0 + units 720 + interviews 1296 = 2747.
```

## Comparing

``` r

data.frame(organisation = c("one tour", "100 km per route", "4 stops per route"),
           routes = c(one$n_routes, days$n_routes, stops$n_routes),
           travel_km = round(c(one$total, days$total, stops$total), 1),
           cost = round(c(one$cost[["total"]], days$cost[["total"]], stops$cost[["total"]])))
#>        organisation routes travel_km cost
#> 1          one tour      1     281.1 2522
#> 2  100 km per route      5     403.1 2741
#> 3 4 stops per route      6     406.2 2747
```

The travel grows with the number of routes because every route starts
and ends at the depot; the question for the planner is whether the extra
kilometres are cheaper than the extra days or teams, which is a cost
model question, not a routing one.

## Road distances

Distances from coordinates understate travel on real roads. Two ways to
do better, both feeding the same routing and cost functions:

- a **detour factor**, the ratio of road to straight-line distance,
  which on rural networks usually lies between 1.2 and 1.4: a planning
  estimate when no network is at hand;
- a **road-network matrix** from an OSRM server, with `method = "osrm"`:
  durations in minutes or distances in kilometres, requested in blocks
  so that the server’s table limit is respected. The public demo server
  is for small tests; run your own server (with OpenStreetMap data of
  the region) for a frame. A matrix computed by any other engine can be
  passed through `matrix` instead.

``` r

m_detour <- travel_matrix(frame, detour = 1.3)
m_detour
#> Travel matrix: 61 units, haversine x 1.3 (km); mean off-diagonal 42.48.
```

``` r

m_road <- travel_matrix(frame, method = "osrm", measure = "duration")
route_fieldwork(m_road, units = sel, depot = "depot", max_length = 480)   # 8 hours per route
```

The `snap` attribute of an OSRM matrix gives the distance from each unit
to the nearest point of the network the server could use; units snapped
from far away are the ones whose access the field team should check.

## Time at the unit, cost per team-day and the calendar

When the matrix is in minutes, a day has a length and so does the work
at each unit: `service_time` is added to the travel of a route when the
limit is checked (a segment with nine points and a few interviews can
take two hours), and the cost model’s `per_route` charges each route as
a team-day (allowances, vehicle, lodging). Routes are then days of work.

``` r

m_min <- travel_matrix(frame, detour = 1.3, unit = "min")   # treat the km as minutes at 60 km/h
daily <- field_cost_model(per_travel = 0.5, per_route = 400, per_unit = 20, per_interview = 15,
                          interviews_per_unit = 3, currency = "BRL")
day <- route_fieldwork(m_min, units = sel, depot = "depot", max_length = 480, service_time = 120,
                       iterations = 50, cost_model = daily)
day
#> 
#> ── Field routes ────────────────────────────────────────────────────────────────
#> 7 routes from "depot" through 18 units: total travel 666.7 min (lower bound
#> 277.2, gap 141%).
#> Route 1 (115.1, duration 475.1): s30 > s9 > s32
#> Route 2 (107.5, duration 347.5): s27 > s48
#> Route 3 (100.4, duration 460.4): s29 > s1 > s31
#> Route 4 (80.36, duration 440.4): s43 > s19 > s6
#> Route 5 (79.66, duration 319.7): s13 > s54
#> Route 6 (117.7, duration 357.7): s47 > s4
#> Route 7 (66.13, duration 426.1): s16 > s12 > s37
#> Cost (BRL): travel 333.4 + routes 2800 + units 360 + interviews 810 = 4303.
glance(day)
#> # A tibble: 1 × 8
#>   n_units n_routes total lower_bound   gap longest_route travel_unit  cost
#>     <int>    <int> <dbl>       <dbl> <dbl>         <dbl> <chr>       <dbl>
#> 1      18        7  667.        277.  1.41          118. min         4303.
```

With several teams based in several towns,
[`schedule_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/schedule_fieldwork.md)
assigns the units to the nearest base (or balances them when a base is
short of team-days), routes each base and distributes the routes over
the teams and the days available, longest first. The calendar says who
goes where on which day and whether the work fits.

``` r

frame2 <- rbind(frame, data.frame(unit = "base2", lat = -8.30, lon = -35.30))
m2 <- travel_matrix(frame2, detour = 1.3, unit = "min")
sch <- schedule_fieldwork(m2, units = sel, teams = c(depot = 1, base2 = 1), days = 3,
                          max_length = 480, service_time = 120, iterations = 50, cost_model = daily)
sch
#> 
#> ── Field schedule ──────────────────────────────────────────────────────────────
#> 18 units, 2 bases, 2 teams, 3 days available: the work does not fit.
#> "depot": 17 units, 1 team, 6 routes, 6 of 3 days (short of days).
#> "base2": 1 unit, 1 team, 1 route, 1 of 3 days.
#> Cost (BRL): 4277.
head(sch$calendar[, c("base", "team", "day", "stops", "travel", "duration")])
#> # A tibble: 6 × 6
#>   base  team      day stops travel duration
#>   <chr> <chr>   <int> <int>  <dbl>    <dbl>
#> 1 base2 base2-1     1     1   40.2     160.
#> 2 depot depot-1     1     3  118.      478.
#> 3 depot depot-1     2     3  100.      460.
#> 4 depot depot-1     3     3   84.9     445.
#> 5 depot depot-1     4     3   83.9     444.
#> 6 depot depot-1     5     3   79.7     440.
autoplot(sch)
```

![](routing-teams_files/figure-html/schedule-1.png)

## Solver settings

`iterations` is the number of GRASP restarts; `alpha` the greediness of
the construction (0 is pure greedy, 1 pure random). The default 200
iterations with `alpha = 0.3` is enough for a few hundred units; the
`gap` field reports how far the solution is from a two-edge lower bound,
which is loose, so gaps of 20 to 40 percent are normal for good
solutions.

``` r

quick <- route_fieldwork(m, units = sel, depot = "depot", iterations = 10, seed = 2)
long <- route_fieldwork(m, units = sel, depot = "depot", iterations = 500, seed = 2)
c(quick = quick$total, long = long$total)
#>    quick     long 
#> 281.1368 281.1368
```
