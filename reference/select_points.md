# Select points inside sampled grid cells

For an area frame of square cells (segments) selected with
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md),
draws `points_per_cell` uniform random points inside each sampled cell.
In the field, each point identifies the field (and so the establishment)
it falls on; an establishment can be hit several times. The point
density of a cell, `pi * points / area`, is what
[`expected_hits()`](https://castlaboratory.github.io/fieldopt/reference/expected_hits.md)
and
[`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
need.

## Usage

``` r
select_points(
  sample,
  points_per_cell,
  cell_size,
  layout = c("random", "systematic"),
  seed = 1
)
```

## Arguments

- sample:

  A `fieldopt_sample` of cells with coordinate columns giving the cell
  centres.

- points_per_cell:

  Points per sampled cell: a single number, a vector named by stratum
  (for example more points where agricultural use is more intense), or
  the name of a column of the sample.

- cell_size:

  Side of the square cells, in the units of the coordinates (one number,
  or `c(dx, dy)`).

- layout:

  `"random"` (independent uniform points) or `"systematic"` (a regular
  grid of `k1 x k2 = m` points with one random offset per cell, which
  spreads the points inside the cell; each point is still uniform over
  the cell, so the density is the same).

- seed:

  Seed.

## Value

A tibble of class `fieldopt_points` with one row per point: `unit` (the
cell), `point`, the two coordinates, `pi_cell`, `points_in_cell` and
`density` (expected points per unit area of the cell).

## Examples

``` r
cells <- expand.grid(x = 1:10, y = 1:10)
cells$unit <- paste0("c", 1:100)
s <- select_units(cells, n = 12, seed = 2)
p <- select_points(s, points_per_cell = 9, cell_size = 1, layout = "systematic")
nrow(p)
#> [1] 108
head(p)
#> 6 systematic points in 1 sampled cell of size 1 x 1.
#> # A tibble: 6 × 7
#>   unit  point     x     y pi_cell points_in_cell density
#>   <chr> <int> <dbl> <dbl>   <dbl>          <dbl>   <dbl>
#> 1 c1        1 0.589 0.624    0.12              9    1.08
#> 2 c1        2 0.922 0.624    0.12              9    1.08
#> 3 c1        3 1.26  0.624    0.12              9    1.08
#> 4 c1        4 0.589 0.957    0.12              9    1.08
#> 5 c1        5 0.922 0.957    0.12              9    1.08
#> 6 c1        6 1.26  0.957    0.12              9    1.08
```
