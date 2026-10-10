# Design effect and bias of point sampling by simulation

Repeats the whole area-frame design, selecting cells with
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md),
placing points with
[`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md),
letting each point hit the establishment whose land it falls on (with
probability equal to the establishment's share of the cell), and
estimating the total with
[`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md).
Returns the empirical variance of the estimator, its bias, the mean
number of interviews, and the design effect relative to a simple random
sample of establishments with the same number of interviews: the
`deff_a` that
[`dual_frame_allocation()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_allocation.md)
asks for.

## Usage

``` r
point_design_effect(
  cells,
  areas,
  n,
  points_per_cell,
  cell_size,
  size = NULL,
  strata = NULL,
  method = c("lpm", "systematic", "srs"),
  replicates = 1,
  n_sim = 200,
  seed = 1
)
```

## Arguments

- cells:

  Data frame of cells as in
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  (with `unit`, coordinates and, when used, strata and size columns).

- areas:

  Data frame with one row per (establishment, cell) pair:
  `establishment`, `unit`, `area` (land of the establishment inside the
  cell, in the square units of `cell_size`) and `y` (the study variable
  of the whole establishment, repeated across its cells).

- n:

  Sample size: a single number (allocated to strata in proportion to the
  sum of `size`, or to the number of units when `size` is `NULL`), or a
  vector named by stratum.

- points_per_cell:

  Points per sampled cell: a single number, a vector named by stratum
  (for example more points where agricultural use is more intense), or
  the name of a column of the sample.

- cell_size:

  Side of the square cells, in the units of the coordinates (one number,
  or `c(dx, dy)`).

- size:

  Column of the size measure for probability-proportional-to-size
  selection, or `NULL` for equal probabilities within stratum.

- strata:

  Column with the stratum of each unit, or `NULL`.

- method:

  `"lpm"`, `"systematic"`, `"srs"` or `"cube"` (balanced sampling by the
  cube method of Deville and Tillé 2004, with the fast flight phase and
  landing by suppression of variables).

- replicates:

  Number of independent interpenetrating replicates for `"systematic"`
  (each a systematic sample of about `n / replicates` units; replicates
  may share units). Ignored by the other methods.

- n_sim:

  Number of simulated surveys.

- seed:

  Seed.

## Value

A one-row tibble of class `fieldopt_point_deff`: `n_sim`, `total`,
`mean_estimate`, `bias`, `variance`, `cv`, `mean_variance_estimate` (the
mean of the
[`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
variance estimates, to be compared with `variance`), `interviews`,
`variance_srs`, `deff`; attribute `estimates` holds the simulated
values.

## Details

Hits are attributed by the establishments' shares of the cell area, not
by the geometry of their fields, so the simulator does not distinguish
the random and systematic point layouts; it captures the cell design,
the point intensity and the multiplicity, which is what drives the
design effect at the cell level.

## Examples

``` r
set.seed(4)
cells <- expand.grid(x = 1:10, y = 1:10); cells$unit <- paste0("c", 1:100)
areas <- rbind(
  data.frame(establishment = paste0(cells$unit, "-1"), unit = cells$unit, area = 0.5),
  data.frame(establishment = paste0(cells$unit, "-2"), unit = cells$unit, area = 0.2))
areas$y <- round(rgamma(nrow(areas), 3, 3 / (10 * areas$area)), 1)
point_design_effect(cells, areas, n = 15, points_per_cell = 6, cell_size = 1, n_sim = 20)
#> # A tibble: 1 × 10
#>   n_sim total mean_estimate  bias variance    cv mean_variance_estimate
#> * <dbl> <dbl>         <dbl> <dbl>    <dbl> <dbl>                  <dbl>
#> 1    20  711.          694. -16.3    7923. 0.125                 11714.
#> # ℹ 3 more variables: interviews <dbl>, variance_srs <dbl>, deff <dbl>
```
