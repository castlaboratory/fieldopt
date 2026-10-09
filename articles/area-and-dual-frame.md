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
#>  8     8     1 c8    low           1 0.0501 TRUE   
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
model <- field_cost_model(per_travel = 2.5, per_unit = 60, per_interview = 25,
                          interviews_per_unit = 4, currency = "BRL")
routed_unit_cost(frame, "depot", model, n = sum(n_h), method = "euclidean",
                 n_rep = 3, iterations = 60)
#> # A tibble: 1 × 6
#>       n cost_per_unit travel_per_unit cost_mean routes_mean n_rep
#>   <dbl>         <dbl>           <dbl>     <dbl>       <dbl> <dbl>
#> 1   100          167.            2.70    16675.           1     3
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
#> 1    60 22075.        22132.  56.8 1783359. 0.0605               1413371.
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
#> 49300, variance of the total 1218000 (SE 1104, CV 5%).
ts$history
#> # A tibble: 2 × 6
#>   round    c1     n     m   cost variance_total
#>   <int> <dbl> <int> <int>  <dbl>          <dbl>
#> 1     1  90.1   170     9 53568.       1218047.
#> 2     2  65.0   170     9 49304.       1218047.
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
#> Minimum cost for target variance 878900: n_A = 81 (frame A, cost 167.7/unit),
#> n_B = 135 (frame B, cost 45/unit), theta = 0.16 (optimised).
#> Cost 19660; variance 877200 (frame A 697000, frame B 180000); CV 5% of the
#> total 18750.
#> Expected overlap units: 11.6 in the A sample, 112.5 in the B sample.
df$history
#> # A tibble: 3 × 7
#>   round cost_a   n_a   n_b theta   cost variance
#>   <int>  <dbl> <int> <int> <dbl>  <dbl>    <dbl>
#> 1     1   190.    80   141 0.155 21553.  871821.
#> 2     2   168.    81   135 0.16  19645.  877223.
#> 3     3   168.    81   135 0.16  19659.  877223.
tidy(df)
#> # A tibble: 2 × 8
#>   frame     n cost_per_unit   cost  deff variance overlap_units
#>   <chr> <int>         <dbl>  <dbl> <dbl>    <dbl>         <dbl>
#> 1 A        81          168. 13584. 0.839  697399.          11.6
#> 2 B       135           45   6075  1      179823.         112. 
#> # ℹ 1 more variable: weight_on_overlap <dbl>
dual_frame_allocation(domains, cost_a = df$cost_a, cost_b = 45, deff_a = deff$deff,
                      theta = "screening", target_cv = 0.05)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 878900: n_A = 89 (frame A, cost 167.7/unit),
#> n_B = 151 (frame B, cost 45/unit), theta = 0 (fixed).
#> Cost 21720; variance 875000 (frame A 708000, frame B 167000); CV 4.99% of the
#> total 18750.
#> Expected overlap units: 12.7 in the A sample, 125.8 in the B sample.
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
