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
select_points(sample, points_per_cell, cell_size, seed = 1)
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

- seed:

  Seed.

## Value

A tibble of class `fieldopt_points` with one row per point: `unit` (the
cell), `point`, the two coordinates, `pi_cell`, `points_in_cell` and
`density` (expected points per unit area of the cell).

## Examples

``` r
cells <- expand.grid(x = 1:10, y = 1:10); cells$unit <- paste0("c", 1:100)
s <- select_units(cells, n = 12, seed = 2)
p <- select_points(s, points_per_cell = 9, cell_size = 1)
nrow(p); head(p)
#> [1] 108
#> # A tibble: 6 × 7
#>   unit  point     x     y pi_cell points_in_cell density
#>   <chr> <int> <dbl> <dbl>   <dbl>          <dbl>   <dbl>
#> 1 c10       1  9.77 0.562    0.12              9    1.08
#> 2 c10       2  9.87 0.706    0.12              9    1.08
#> 3 c10       3 10.1  0.677    0.12              9    1.08
#> 4 c10       4 10.4  1.19     0.12              9    1.08
#> 5 c10       5  9.70 0.884    0.12              9    1.08
#> 6 c10       6 10.4  1.27     0.12              9    1.08
```
