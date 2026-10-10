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
territory; then 3, 6 or 9 points per cell depending on the stratum, laid
out as a regular grid with one random offset per cell
(`layout = "systematic"`), which keeps each point uniform over the cell
while spreading them.

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
#>  8     8     1 c8    low           1 0.0501 FALSE  
#>  9     9     1 c9    low           1 0.0501 FALSE  
#> 10    10     1 c10   low           1 0.0501 FALSE  
#> # ℹ 890 more rows
ppc <- c(low = 3, mid = 6, high = 9)
points <- select_points(cells_s, points_per_cell = ppc, cell_size = 1, layout = "systematic", seed = 7)
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
#> [1] 168
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
#> 1 22091. 1191097. 1091. 0.0494     3381540.   100   900 stratified local…    401
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
model <- field_cost_model(per_travel = 2.5, per_unit = 60, per_interview = 25,
                          interviews_per_unit = 4, currency = "BRL")
routed_unit_cost(frame, "depot", model, n = sum(n_h), method = "euclidean",
                 n_rep = 3, iterations = 60)
#> # A tibble: 1 × 6
#>       n cost_per_unit travel_per_unit cost_mean routes_mean n_rep
#>   <dbl>         <dbl>           <dbl>     <dbl>       <dbl> <dbl>
#> 1   100          167.            2.66    16666.           1     3
```

## The design effect of point sampling

The dual-frame allocation below needs the design effect of the area
sample relative to simple random sampling of establishments.
[`point_design_effect()`](https://castlaboratory.github.io/fieldopt/reference/point_design_effect.md)
simulates the whole area design (cells, points, hits, multiplicity
estimator) and returns the bias, the empirical variance, the mean of the
variance estimates, the number of interviews and the design effect.

``` r

deff <- point_design_effect(cells, areas, n = n_h, strata = "intensity",
                            points_per_cell = ppc, cell_size = 1, n_sim = 60, seed = 9)
deff
#> # A tibble: 1 × 10
#>   n_sim  total mean_estimate  bias variance     cv mean_variance_estimate
#> * <dbl>  <dbl>         <dbl> <dbl>    <dbl>  <dbl>                  <dbl>
#> 1    60 22075.        22189.  114. 1120913. 0.0480               1416757.
#> # ℹ 3 more variables: interviews <dbl>, variance_srs <dbl>, deff <dbl>
```

The bias is negligible and the variance estimator of
[`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
tracks the empirical variance; the design effect is what enters
`deff_a`.

## Two-stage allocation: how many cells, how many points

With the between-cell and within-cell variance components (from a pilot
or from the frame) and the costs per cell and per point, Cochran’s rule
gives the number of points per cell and then the number of cells for a
target precision.
[`two_stage_design()`](https://castlaboratory.github.io/fieldopt/reference/two_stage_design.md)
measures the cost per cell by routing a sample of the allocated size and
iterates until the number of cells settles.

``` r

cell_tot <- tapply(areas$y, areas$unit, sum)
ts <- two_stage_design(frame, "depot", model, m_secondary = 9,
                       s2_between = var(cell_tot / 9), s2_within = var(areas$y) * 2,
                       target_cv = 0.05, mean = mean(cell_tot) / 9,
                       method = "euclidean", n_rep = 3, iterations = 60)
ts
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 170 primary units with m = 9 secondary units each (optimal m 9): cost
#> 49310, variance of the total 1218000 (SE 1104, CV 5%).
ts$history
#> # A tibble: 2 × 6
#>   round    c1     n     m   cost variance_total
#>   <int> <dbl> <int> <int>  <dbl>          <dbl>
#> 1     1  90.1   170     9 53568.       1218047.
#> 2     2  65.0   170     9 49308.       1218047.
```

## Dual-frame allocation: area plus list

The list frame holds the large establishments, which are also on the
area frame (the overlap `ab`); small establishments are on the area
frame only (`a`); a few specialised units are on the list only (`b`).
Given the sizes, means and standard deviations of the three domains, the
cost per list unit and the design effect from the simulation,
[`dual_frame_design()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_design.md)
runs Hartley’s allocation with the area cost measured by routing,
iterating until the area sample size settles; `theta = "screening"`
gives the design in which the area sample does not use the overlap.

``` r

domains <- data.frame(domain = c("a", "ab", "b"),
                      size = c(1500, 250, 50),
                      mean = c(6, 30, 45), sd = c(5, 20, 35))
df <- dual_frame_design(frame, "depot", model, domains, cost_b = 45, deff_a = deff$deff,
                        target_cv = 0.05, method = "euclidean", n_rep = 3, iterations = 60)
df
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 878900: n_A = 56 (frame A, cost 169.4/unit),
#> n_B = 117 (frame B, cost 45/unit), theta = 0.168 (optimised).
#> Cost 14750; variance 875300 (frame A 647000, frame B 229000); CV 4.99% of the
#> total 18750.
#> Expected overlap units: 8 in the A sample, 97.5 in the B sample.
df$history
#> # A tibble: 3 × 7
#>   round cost_a   n_a   n_b theta   cost variance
#>   <int>  <dbl> <int> <int> <dbl>  <dbl>    <dbl>
#> 1     1   190.    55   122 0.153 15946.  870584.
#> 2     2   169.    56   117 0.168 14750.  875297.
#> 3     3   169.    56   117 0.168 14750.  875304.
tidy(df)
#> # A tibble: 2 × 8
#>   frame     n cost_per_unit  cost  deff variance overlap_units weight_on_overlap
#>   <chr> <int>         <dbl> <dbl> <dbl>    <dbl>         <dbl>             <dbl>
#> 1 A        56          169. 9485. 0.528  646660.           8               0.168
#> 2 B       117           45  5265  1      228645.          97.5             0.832
dual_frame_allocation(domains, cost_a = df$cost_a, cost_b = 45, deff_a = deff$deff,
                      theta = "screening", target_cv = 0.05)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 878900: n_A = 62 (frame A, cost 169.4/unit),
#> n_B = 131 (frame B, cost 45/unit), theta = 0 (fixed).
#> Cost 16400; variance 868400 (frame A 650000, frame B 219000); CV 4.97% of the
#> total 18750.
#> Expected overlap units: 8.9 in the A sample, 109.2 in the B sample.
```

## Estimating from both frames

The domains come from the overlap between the frames:
[`frame_overlap()`](https://castlaboratory.github.io/fieldopt/reference/frame_overlap.md)
places each listed establishment in the cell it falls in (by
coordinates, by polygons, or by a table of pairs from record linkage,
for example with the `reclin2` package) and marks it `ab` or `b`, and
tells each cell which listed establishments it holds, which is what the
teams use to screen the overlap out of the area sample.

Once both samples are in,
[`dual_frame_estimator()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_estimator.md)
combines them. Each sampled unit carries its domain (`a` or `ab` on the
area frame, `b` or `ab` on the list); Hartley’s estimator mixes the two
estimates of the overlap with a weight `theta` that can be fixed, set to
zero (screening) or estimated to minimise the variance, and the
Fuller-Burmeister estimator adds the difference between the two
estimates of the overlap size. The variances come from the variance
estimator of each design.

``` r

cells$domain <- ifelse(cells$intensity == "high" & runif(nrow(cells)) < 0.6, "ab", "a")
cells$crop_est <- ifelse(cells$domain == "ab", 60, 12) + rnorm(nrow(cells), sd = 3)
ab <- cells[cells$domain == "ab", ]   # the overlap: the same holdings, seen from the list
list_frame <- data.frame(unit = c(paste0("l", seq_len(nrow(ab))), paste0("b", 1:12)),
                         x = runif(nrow(ab) + 12), y = runif(nrow(ab) + 12),
                         domain = rep(c("ab", "b"), c(nrow(ab), 12)),
                         crop_est = c(ab$crop_est, 90 + rnorm(12, sd = 5)))
sa <- select_units(cells, n = 40, strata = "intensity", seed = 3)
sb <- select_units(list_frame, n = 20, method = "srs", seed = 4)
dual_frame_estimator(sa, sb, y = "crop_est", domain = "domain")
#> # A tibble: 1 × 13
#>    total variance    se     cv estimator theta theta_fixed    y_a y_ab_a y_ab_b
#>    <dbl>    <dbl> <dbl>  <dbl> <chr>     <dbl> <lgl>        <dbl>  <dbl>  <dbl>
#> 1 18802.  217013.  466. 0.0248 hartley   0.157 FALSE       10021.  5475.  8584.
#> # ℹ 3 more variables: y_b <dbl>, n_a <int>, n_b <int>
dual_frame_estimator(sa, sb, y = "crop_est", domain = "domain", theta = "screening")
#> # A tibble: 1 × 13
#>    total variance    se     cv estimator theta theta_fixed    y_a y_ab_a y_ab_b
#>    <dbl>    <dbl> <dbl>  <dbl> <chr>     <dbl> <lgl>        <dbl>  <dbl>  <dbl>
#> 1 19292.  345814.  588. 0.0305 hartley       0 TRUE        10021.  5475.  8584.
#> # ℹ 3 more variables: y_b <dbl>, n_a <int>, n_b <int>
dual_frame_estimator(sa, sb, y = "crop_est", domain = "domain", estimator = "fuller-burmeister")
#> # A tibble: 1 × 13
#>    total variance    se     cv estimator      beta_1 beta_2    y_a y_ab_a y_ab_b
#>    <dbl>    <dbl> <dbl>  <dbl> <chr>           <dbl>  <dbl>  <dbl>  <dbl>  <dbl>
#> 1 18802.  215797.  465. 0.0247 fuller-burmei…  0.386  -13.9 10021.  5475.  8584.
#> # ℹ 3 more variables: y_b <dbl>, n_a <int>, n_b <int>
```

The selection scales to national frames: the local pivotal method and
the systematic and cube methods run on a million cells in about a second
(a grid index keeps the nearest-neighbour searches local), and the
selection is done within strata, so the size of the whole frame is not a
constraint.

For everything else the estimation needs, calibration to known totals,
domain estimates, nonresponse adjustment,
[`as_svydesign()`](https://castlaboratory.github.io/fieldopt/reference/as_svydesign.md)
hands a sample to the `survey` package as a design object with the right
weights, strata and, for replicated systematic samples, the replicate
weights.

``` r

d <- as_svydesign(sa)
survey::svytotal(~crop_est, d)
#>          total     SE
#> crop_est 15496 1828.3
survey::svyby(~crop_est, ~intensity, d, survey::svytotal)
#>      intensity crop_est        se
#> low        low 5046.943  300.3568
#> mid        mid 3494.187  151.6314
#> high      high 6954.904 1797.0785
```

## Auxiliaries: the ratio estimator and balanced samples

Area frames come with auxiliaries known for every cell: the area of
farmland from the land-cover map, the number of holdings from the last
census. The ratio estimator uses one such total at the estimation stage,
and the cube method uses several at the selection stage, drawing a
sample whose Horvitz-Thompson estimates of the auxiliaries match their
totals.
[`spatial_balance()`](https://castlaboratory.github.io/fieldopt/reference/spatial_balance.md)
measures how evenly a sample covers the territory (Stevens and Olsen’s
Voronoi measure: zero is perfect).

``` r

cells$farmland <- cells$size * runif(nrow(cells), 15, 35)
cells$crop_r <- 0.5 * cells$farmland + rnorm(nrow(cells), sd = 3)
s_lpm <- select_units(cells, n = 40, strata = "intensity", seed = 5)
ratio_estimator(s_lpm, y = "crop_r", x = "farmland")[, c("total", "se", "variance", "variance_ht")]
#> # A tibble: 1 × 4
#>    total    se variance variance_ht
#>    <dbl> <dbl>    <dbl>       <dbl>
#> 1 22495.  391.  152859.    1266972.
s_cube <- select_units(cells, n = 40, strata = "intensity", method = "cube", balance = "farmland", seed = 5)
c(lpm = spatial_balance(s_lpm), cube = spatial_balance(s_cube),
  srs = spatial_balance(select_units(cells, n = 40, strata = "intensity", method = "srs", seed = 5)))
#>       lpm      cube       srs 
#> 0.1117390 0.4083660 0.3075266
```

## References

Cochran, W. G. (1977). *Sampling Techniques*, third edition. Wiley.

Hartley, H. O. (1974). Multiple frame methodology and selected
applications. *Sankhya C*, 36, 99–118.

Lohr, S. L. and Rao, J. N. K. (2006). Estimation in multiple-frame
surveys. *Journal of the American Statistical Association*, 101(475),
1019–1030.

Nealon, J. P. (1984). Review of the multiple and area frame estimators.
USDA Statistical Reporting Service, Staff Report 80.

Deville, J.-C. and Tillé, Y. (2004). Efficient balanced sampling: the
cube method. *Biometrika*, 91(4), 893–912.

Fuller, W. A. and Burmeister, L. F. (1972). Estimators for samples
selected from two overlapping frames. *Proceedings of the Social
Statistics Section, American Statistical Association*, 245–249.

Stevens, D. L. and Olsen, A. R. (2004). Spatially balanced sampling of
natural resources. *Journal of the American Statistical Association*,
99, 262–278.
