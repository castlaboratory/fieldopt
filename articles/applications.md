# Where fieldopt applies: beyond agricultural surveys

The package was built for agricultural surveys with an area frame, but
its pieces are general: a probability sample of places, the cost of
visiting them, and the estimate that comes out. Any survey that sends
people to locations fits. Four settings, each with the functions it
uses.

| Setting | Units | Balanced on | Field constraint | Main functions |
|----|----|----|----|----|
| Agricultural area frame | grid cells, points | space, intensity | team-days, service per cell | all (plan vignette) |
| Environmental monitoring | sites (lakes, plots, stations) | space, covariates | daily range of boats or vehicles | `select_units(method = "cube")`, [`route_fieldwork()`](https://castlaboratory.github.io/fieldopt/reference/route_fieldwork.md) |
| Household survey | enumeration areas, then households | population size | interviewer-days, several offices | [`two_stage_allocation()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_allocation.md), `schedule_fieldwork(region = )` |
| Establishment survey | listed firms plus area segments | coverage of the unlisted | screening in the field | [`frame_overlap()`](https://castlaboratory.github.io/fieldopt/reference/frame_overlap.md), [`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md), [`dual_frame_estimator()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_estimator.md) |

## Environmental monitoring: sites balanced on covariates

Three hundred candidate lakes with altitude and surface; the monitoring
programme can visit forty a season with two boats, each out for at most
ten hours a day including four hours of sampling per lake. The cube
method balances the sample on the covariates while the routes keep the
days feasible.

``` r

set.seed(31)
lakes <- data.frame(unit = paste0("lake", 1:300), x = runif(300, 0, 200), y = runif(300, 0, 120))
lakes$altitude <- 200 + 8 * lakes$y + rnorm(300, sd = 40)
lakes$surface <- exp(rnorm(300, 2, 0.8))
s <- select_units(lakes, n = 40, method = "cube", balance = c("altitude", "surface"), seed = 2)
rbind(frame = c(altitude = mean(lakes$altitude), surface = mean(lakes$surface)),
      sample = c(mean(lakes$altitude[s$sampled]), mean(lakes$surface[s$sampled])))
#>        altitude  surface
#> frame  685.1421 10.18864
#> sample 674.4446 10.28326
harbour <- data.frame(unit = "harbour", x = 100, y = 0)
m <- travel_matrix(rbind(harbour, lakes[s$sampled, c("unit", "x", "y")]), method = "euclidean", unit = "min")
r <- route_fieldwork(m, units = lakes$unit[s$sampled], depot = "harbour", max_length = 600,
                     service_time = 240, iterations = 100)
c(days = r$n_routes, longest_day = round(max(r$durations)))
#>        days longest_day 
#>          36         598
```

## Household survey: enumeration areas from several offices

Enumeration areas are selected with probability proportional to their
households, then a fixed number of households inside each; the two-stage
allocation says how many of each, and the schedule assigns the areas to
the regional offices and their interviewers.

``` r

set.seed(5)
ea <- data.frame(unit = paste0("ea", 1:400), x = runif(400, 0, 60), y = runif(400, 0, 40))
ea$households <- round(exp(rnorm(400, 5, 0.4)))
two_stage_allocation(n_primary = 400, m_secondary = mean(ea$households), s2_between = 0.04, s2_within = 0.22,
                     c1 = 350, c2 = 18, target_cv = 0.03, mean = 0.4)
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 249 primary units with m = 10 secondary units each (optimal m 10.52): cost
#> 132000, variance of the total 621600 (SE 788.4, CV 3%).
s <- select_units(ea, n = 36, size = "households", seed = 9)
offices <- data.frame(unit = c("office_w", "office_e"), x = c(12, 48), y = c(20, 20))
m <- travel_matrix(rbind(offices, ea[s$sampled, c("unit", "x", "y")]), method = "euclidean", unit = "min")
m <- travel_matrix(rbind(offices, ea[s$sampled, c("unit", "x", "y")]), method = "euclidean", matrix = 3 * unclass(m), unit = "min")
sch <- schedule_fieldwork(m, units = ea$unit[s$sampled], teams = c(office_w = 3, office_e = 2), days = 10,
                          max_length = 480, service_time = 300, iterations = 60)
sch$summary
#> # A tibble: 2 × 7
#>   base     units teams routes days_needed days_available fits 
#> * <chr>    <int> <dbl>  <int>       <int>          <dbl> <lgl>
#> 1 office_w    18     3     18           6             10 TRUE 
#> 2 office_e    18     2     18           9             10 TRUE
```

## Establishment survey: a list and an area frame

A register covers the large establishments but misses the small and the
new ones; an area frame covers everything but is expensive. The
dual-frame design samples both, sizes them for the money available, and
the estimator combines the two samples. The dual-frame vignette shows
the estimation; the allocation below spends a budget between the frames.

``` r

domains <- data.frame(domain = c("a", "ab", "b"), size = c(5000, 800, 150),
                      mean = c(12, 90, 110), sd = c(10, 60, 70))
dual_frame_allocation(domains, cost_a = 220, cost_b = 35, deff_a = 1.6, budget = 150000)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum variance for budget 150000: n_A = 530 (frame A, cost 220/unit), n_B =
#> 950 (frame B, cost 35/unit), theta = 0.088 (optimised).
#> Cost 149800; variance 8492000 (frame A 8490000, frame B 0); CV 1.96% of the
#> total 148500.
#> Expected overlap units: 73.1 in the A sample, 800 in the B sample; a bound on a
#> sample size was active.
```

## What stays the same across settings

Every setting goes through the same objects: a frame with coordinates, a
`fieldopt_sample` with known inclusion probabilities, a travel matrix, a
`fieldopt_routes` or `fieldopt_schedule`, and a one-row tibble with the
estimate and its variance. The cost side
([`field_cost_model()`](https://castlaboratory.github.io/fieldopt/reference/field_cost_model.md),
[`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md))
and the connectors to `survey`, `sf`, OSRM, `vrpr` and `highs` are the
same too.
