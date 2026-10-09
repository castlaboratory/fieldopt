# An area frame with points, a list frame, and their joint design

Agricultural surveys often combine an **area frame** (a grid of square
cells classified by intensity of agricultural use from satellite
imagery, with sample points inside the selected cells identifying the
fields and so the establishments) and a **list frame** (large and
specialised establishments, cheap to reach). This vignette walks through
such a design with `fieldopt`: stratified selection of cells, points
inside them, the multiplicity estimator, the cost of the field work, and
the dual-frame and two-stage allocations that put the pieces together.
The data are synthetic; the structure is the usual one of area frames
built on a regular grid (square segments of about 1 km²) with a list of
large producers alongside.

## The area frame: cells with intensity classes

``` r

library(fieldopt)
set.seed(2026)
side <- 30
cells <- expand.grid(x = seq_len(side), y = seq_len(side))
cells$unit <- paste0("c", seq_len(nrow(cells)))
use <- 0.5 * cells$x / side + 0.3 * sin(cells$y / 4) + rnorm(nrow(cells), sd = 0.15)
cells$intensity <- cut(use, c(-Inf, 0.25, 0.5, Inf), c("low", "mid", "high"))
cells$size <- c(low = 1, mid = 2, high = 4)[as.character(cells$intensity)]
table(cells$intensity)
#> 
#>  low  mid high 
#>  399  275  226
```

Each cell holds a few establishments; the agricultural area of an
establishment inside a cell is what the point sampling needs. Here every
cell has two establishments with 40 % and 20 % of its area, and a crop
value per establishment that follows the intensity.

``` r

areas <- rbind(
  data.frame(establishment = paste0(cells$unit, "-1"), unit = cells$unit, area = 0.4),
  data.frame(establishment = paste0(cells$unit, "-2"), unit = cells$unit, area = 0.2))
areas$y <- round(rgamma(nrow(areas), shape = 4, rate = 4 / (20 * areas$area * cells$size[match(areas$unit, cells$unit)])), 1)
truth <- sum(areas$y)
truth
#> [1] 22075.4
```

## Stratified selection of cells and points inside them

Cells are selected within intensity strata, more where use is intense,
with the local pivotal method so that the sample spreads over the
territory; then 3, 6 or 9 points per cell depending on the stratum.

``` r

n_h <- c(low = 20, mid = 35, high = 45)
cells_s <- select_units(cells, n = n_h, strata = "intensity", seed = 7)
cells_s
#> Sample of 100 units from 900 by "lpm", 3 strata.
#> # A tibble: 900 × 7
#>        x     y unit  intensity  size     pi sampled
#>  * <int> <int> <chr> <fct>     <dbl>  <dbl> <lgl>  
#>  1     1     1 c1    low           1 0.0501 FALSE  
#>  2     2     1 c2    low           1 0.0501 FALSE  
#>  3     3     1 c3    low           1 0.0501 FALSE  
#>  4     4     1 c4    low           1 0.0501 FALSE  
#>  5     5     1 c5    low           1 0.0501 FALSE  
#>  6     6     1 c6    low           1 0.0501 FALSE  
#>  7     7     1 c7    low           1 0.0501 FALSE  
#>  8     8     1 c8    low           1 0.0501 TRUE   
#>  9     9     1 c9    low           1 0.0501 FALSE  
#> 10    10     1 c10   low           1 0.0501 FALSE  
#> # ℹ 890 more rows
ppc <- c(low = 3, mid = 6, high = 9)
points <- select_points(cells_s, points_per_cell = ppc, cell_size = 1, seed = 7)
nrow(points)
#> [1] 675
```

In the field each point is visited and the establishment it falls on is
interviewed about its whole operation. Here the field is simulated: a
point hits establishment 1 with probability 0.4, establishment 2 with
probability 0.2, and otherwise falls on non-agricultural land.

``` r

set.seed(8)
u <- runif(nrow(points))
which_e <- ifelse(u < 0.4, "-1", ifelse(u < 0.6, "-2", NA))
hits <- data.frame(unit = points$unit, establishment = paste0(points$unit, which_e))[!is.na(which_e), ]
hits$y <- areas$y[match(hits$establishment, areas$establishment)]
nrow(hits); length(unique(hits$establishment))
#> [1] 401
#> [1] 170
```

## The multiplicity estimator

An establishment can be hit several times; the estimator divides the
value of every hit by the expected number of hits of that establishment
under the design, which depends on the cells it spans, their inclusion
probabilities and their point densities.

``` r

eh <- expected_hits(areas, cells_s, points_per_cell = ppc, cell_size = 1)
hits$expected_hits <- eh$expected_hits[match(hits$establishment, eh$establishment)]
point_estimator(hits, cells_s)
#> # A tibble: 1 × 10
#>    total variance    se     cv variance_srs     n     N variance_method   n_hits
#>    <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int> <chr>              <int>
#> 1 21557. 1390104. 1179. 0.0547     4322582.   100   900 stratified local…    401
#> # ℹ 1 more variable: n_establishments <int>
truth
#> [1] 22075.4
```

The variance uses the cell design (local-mean estimator on the cell
contributions). The same cells selected as a spatially ordered
systematic sample with four interpenetrating replicates give a
replicate-based variance instead:

``` r

cells_r <- select_units(cells, n = n_h, strata = "intensity", method = "systematic", replicates = 4, seed = 7)
cells_r$crop <- tapply(areas$y, areas$unit, sum)[cells_r$unit]
design_variance(cells_r, "crop")
#> # A tibble: 1 × 8
#>    total variance    se     cv variance_srs     n     N variance_method
#>    <dbl>    <dbl> <dbl>  <dbl>        <dbl> <int> <int> <chr>          
#> 1 21651.  345846.  588. 0.0272     3296859.    91   900 replicates
```

## What the field work costs

The cells are visited from a depot; the routing gives the travel, the
cost model the money. The cost per visited cell is the input the
allocations below need, and it depends on how many cells are visited and
how spread they are, which is why it is computed rather than assumed.

``` r

frame <- rbind(data.frame(unit = "depot", x = side / 2, y = side / 2), cells[, c("unit", "x", "y")])
m <- travel_matrix(frame, method = "euclidean", unit = "km")
model <- field_cost_model(per_travel = 2.5, per_unit = 60, per_interview = 25,
                          interviews_per_unit = 4, currency = "BRL")
routes <- route_fieldwork(m, units = cells_s$unit[cells_s$sampled], depot = "depot",
                          max_stops = 8, cost_model = model)
routes$cost
#>     travel      units interviews      total 
#>   1208.023   6000.000  10000.000  17208.023
c1 <- routes$cost[["total"]] / sum(cells_s$sampled)
c1
#> [1] 172.0802
```

## Two-stage allocation: how many cells, how many points

With the between-cell and within-cell variance components (from a pilot
or from the frame) and the costs per cell and per point, Cochran’s rule
gives the number of points per cell and then the number of cells for a
target precision.

``` r

cell_tot <- tapply(areas$y, areas$unit, sum)
two_stage_allocation(n_primary = nrow(cells), m_secondary = 9,
                     s2_between = var(cell_tot / 9), s2_within = var(areas$y) * 2,
                     c1 = routes$cost[["travel"]] / sum(cells_s$sampled) + model$per_unit,
                     c2 = model$per_interview, target_cv = 0.05, mean = mean(cell_tot) / 9)
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 170 primary units with m = 9 secondary units each (optimal m 9): cost
#> 50500, variance of the total 1218000 (SE 1104, CV 5%).
```

## Dual-frame allocation: area plus list

The list frame holds the large establishments, which are also on the
area frame (the overlap `ab`); small establishments are on the area
frame only (`a`); a few specialised units are on the list only (`b`).
Given the sizes, means and standard deviations of the three domains and
the cost per unit in each frame (the area cost from the routing above),
Hartley’s allocation gives the two sample sizes and the mixing weight,
or the screening design in which the area sample does not use the
overlap.

``` r

domains <- data.frame(domain = c("a", "ab", "b"),
                      size = c(1500, 250, 50),
                      mean = c(6, 30, 45), sd = c(5, 20, 35))
dual_frame_allocation(domains, cost_a = c1, cost_b = 45, deff_a = 1.6, target_cv = 0.05)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 878900: n_A = 137 (frame A, cost
#> 172.080226773024/unit), n_B = 168 (frame B, cost 45/unit), theta = 0.153
#> (optimised).
#> Cost 31130; variance 875600 (frame A 759000, frame B 117000); CV 4.99% of the
#> total 18750.
#> Expected overlap units: 19.6 in the A sample, 140 in the B sample.
dual_frame_allocation(domains, cost_a = c1, cost_b = 45, deff_a = 1.6, theta = "screening", target_cv = 0.05)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 878900: n_A = 150 (frame A, cost
#> 172.080226773024/unit), n_B = 186 (frame B, cost 45/unit), theta = 0 (fixed).
#> Cost 34180; variance 876200 (frame A 772000, frame B 105000); CV 4.99% of the
#> total 18750.
#> Expected overlap units: 21.4 in the A sample, 155 in the B sample.
```

`deff_a` carries the design effect of the point sampling relative to
simple random sampling of establishments; estimate it from the variance
ratio of a pilot. The allocation is a planning tool: the cost per area
unit changes with `n_A`, so run the routing at the allocated size and
iterate once.

## References

Cochran, W. G. (1977). *Sampling Techniques*, third edition. Wiley.

Hartley, H. O. (1974). Multiple frame methodology and selected
applications. *Sankhya C*, 36, 99–118.

Lohr, S. L. and Rao, J. N. K. (2006). Estimation in multiple-frame
surveys. *Journal of the American Statistical Association*, 101(475),
1019–1030.

Nealon, J. P. (1984). Review of the multiple and area frame estimators.
USDA Statistical Reporting Service, Staff Report 80.
