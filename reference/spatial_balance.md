# Spatial balance of a sample

The Voronoi measure of Stevens and Olsen (2004): every unit of the frame
is assigned to its nearest sampled unit, the inclusion probabilities
assigned to each sampled unit are summed, and the balance is the mean
squared deviation of those sums from one. Zero is perfect balance;
simple random samples give values near one. With strata the measure is
computed within each stratum and pooled.

## Usage

``` r
spatial_balance(sample, by_stratum = FALSE)
```

## Arguments

- sample:

  A
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  sample.

- by_stratum:

  Return one value per stratum instead of the pooled one.

## Value

A number, or a named vector with `by_stratum = TRUE`.

## References

Stevens, D. L. and Olsen, A. R. (2004). Spatially balanced sampling of
natural resources. *Journal of the American Statistical Association*,
99, 262-278.

## Examples

``` r
cells <- expand.grid(x = 1:10, y = 1:10)
spatial_balance(select_units(cells, n = 10, method = "lpm", seed = 1))
#> [1] 0.102
spatial_balance(select_units(cells, n = 10, method = "srs", seed = 1))
#> [1] 0.268
```
