# Multiplicity (point) estimator of a total from an area sample of points

Each point that hits an establishment contributes `y / expected_hits` of
that establishment; the sum over hits is unbiased for the population
total whatever the number of times an establishment is hit (the more
points fall on an establishment, the larger its contribution, matching
its larger chance of selection). The variance is estimated at the cell
level (ultimate-cluster approximation): the cell contributions are
treated as cell totals and the variance estimator of the cell design is
applied (local-mean for `"lpm"`, replicates for replicated systematic
samples, simple random sampling otherwise).

## Usage

``` r
point_estimator(hits, sample)
```

## Arguments

- hits:

  Data frame with one row per point that hit an establishment: columns
  `unit` (cell), `establishment`, `y` (value of the whole establishment)
  and `expected_hits` (from
  [`expected_hits()`](https://castlaboratory.github.io/fieldopt/reference/expected_hits.md)).

- sample:

  The `fieldopt_sample` of cells.

## Value

A one-row tibble as in
[`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md),
with `n_hits` and `n_establishments`.
