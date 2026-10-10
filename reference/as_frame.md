# Turn a spatial object into a frame

Converts an `sf` object (points or polygons) into the plain data frame
that
[`travel_matrix()`](https://castlaboratory.github.io/fieldopt/reference/travel_matrix.md)
and
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
expect: a column `unit`, the coordinates `lat`/`lon` (centroids for
polygons, in WGS 84) and, for polygons, their `area` in square
kilometres, next to the other columns of the object. Nothing spatial is
kept: use
[`as_sf()`](https://castlaboratory.github.io/fieldopt/reference/as_sf.md)
to put the results back on the geometries.

## Usage

``` r
as_frame(x, unit = NULL)
```

## Arguments

- x:

  An `sf` object (the `sf` package must be installed), or a data frame
  returned unchanged.

- unit:

  Name of the column with the unit names; made from the row numbers when
  `NULL` and no `unit` column exists.

## Value

A tibble with `unit`, `lat`, `lon`, `area` (polygons only) and the
attribute columns.

## Examples

``` r
if (requireNamespace("sf", quietly = TRUE)) {
  sq <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)))),
    crs = 4326
  )
  cells <- sf::st_sf(crop = 3, geometry = sf::st_make_grid(sq, n = 3))
  as_frame(cells)
}
#> # A tibble: 9 × 5
#>   unit    lat   lon  area  crop
#>   <chr> <dbl> <dbl> <dbl> <dbl>
#> 1 u1    0.167 0.167 1374.     3
#> 2 u2    0.167 0.500 1374.     3
#> 3 u3    0.167 0.833 1374.     3
#> 4 u4    0.500 0.167 1374.     3
#> 5 u5    0.500 0.500 1374.     3
#> 6 u6    0.500 0.833 1374.     3
#> 7 u7    0.833 0.167 1374.     3
#> 8 u8    0.833 0.500 1374.     3
#> 9 u9    0.833 0.833 1374.     3
```
