# Expected number of point hits of each establishment

An establishment with agricultural area `area` inside cell `unit` is hit
by a point of that cell with expected count `density * area`; summed
over the cells it spans, this is the multiplicity factor that
[`point_estimator()`](https://castlaboratory.github.io/fieldopt/reference/point_estimator.md)
divides by. Cells outside the sample contribute `pi * points / area` as
well, so the expectation is over the whole design; supply
`points_per_cell` for them.

## Usage

``` r
expected_hits(areas, sample, points_per_cell, cell_size)
```

## Arguments

- areas:

  Data frame with columns `establishment`, `unit` (cell) and `area`
  (agricultural area of the establishment inside that cell, in the
  square units of `cell_size`).

- sample:

  The `fieldopt_sample` of cells.

- points_per_cell:

  As in
  [`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md),
  applied to every cell of the frame.

- cell_size:

  As in
  [`select_points()`](https://castlaboratory.github.io/fieldopt/reference/select_points.md).

## Value

A tibble with `establishment` and `expected_hits`.
