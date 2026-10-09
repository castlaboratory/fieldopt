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
#> 1 route from "depot" through 18 units: total travel 272 km (lower bound 230,
#> gap 18.3%).
#> Route 1 (272): s2 > s7 > s57 > s14 > s47 > s60 > s35 > s54 > s55 > s49 > s19 >
#> s41 > s1 > s53 > s26 > s34 > s11 > s17
#> Cost (BRL): travel 489.7 + units 720 + interviews 1296 = 2506.
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
#> 4 routes from "depot" through 18 units: total travel 345.3 km (lower bound 230,
#> gap 50.2%).
#> Route 1 (90.66): s17 > s53 > s1 > s41
#> Route 2 (83.6): s34 > s26 > s11 > s7
#> Route 3 (94.05): s2 > s57 > s14 > s47 > s60 > s35
#> Route 4 (77.03): s54 > s49 > s19 > s55
#> Cost (BRL): travel 621.6 + units 720 + interviews 1296 = 2638.
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
#> 5 routes from "depot" through 18 units: total travel 383.4 km (lower bound 230,
#> gap 66.7%).
#> Route 1 (90.66): s17 > s53 > s1 > s41
#> Route 2 (83.6): s34 > s26 > s11 > s7
#> Route 3 (39.02): s2 > s57
#> Route 4 (93.14): s14 > s47 > s60 > s35
#> Route 5 (77.03): s54 > s49 > s19 > s55
#> Cost (BRL): travel 690.2 + units 720 + interviews 1296 = 2706.
```

## Comparing

``` r

data.frame(organisation = c("one tour", "100 km per route", "4 stops per route"),
           routes = c(one$n_routes, days$n_routes, stops$n_routes),
           travel_km = round(c(one$total, days$total, stops$total), 1),
           cost = round(c(one$cost[["total"]], days$cost[["total"]], stops$cost[["total"]])))
#>        organisation routes travel_km cost
#> 1          one tour      1     272.0 2506
#> 2  100 km per route      4     345.3 2638
#> 3 4 stops per route      5     383.4 2706
```

The travel grows with the number of routes because every route starts
and ends at the depot; the question for the planner is whether the extra
kilometres are cheaper than the extra days or teams, which is a cost
model question, not a routing one.

## A road-network matrix

Distances from coordinates understate travel on real roads. When a
routing engine is available, pass its matrix: the units must be in the
same order as the coordinates, which are then used only for names and
plots.

``` r

# with the osrm package and a running server
net <- osrm::osrmTable(src = frame[, c("unit", "lon", "lat")],
                       dst = frame[, c("unit", "lon", "lat")])$durations
m_net <- travel_matrix(frame, matrix = net, unit = "min")
route_fieldwork(m_net, units = sel, depot = "depot", max_length = 480)
```

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
#> 272.0344 272.0344
```
