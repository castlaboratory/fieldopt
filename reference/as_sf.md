# Put results back on the geometries of a spatial frame

Joins a sample, a frontier allocation or any data frame with a `unit`
column to the geometries of the `sf` object the frame came from, for
maps.

## Usage

``` r
as_sf(x, sf, unit = NULL)
```

## Arguments

- x:

  A data frame with a `unit` column (a `fieldopt_sample`, for example).

- sf:

  The `sf` object that
  [`as_frame()`](https://castlaboratory.github.io/fieldopt/reference/as_frame.md)
  was applied to.

- unit:

  Name of the column with the unit names in `sf`, as in
  [`as_frame()`](https://castlaboratory.github.io/fieldopt/reference/as_frame.md).

## Value

An `sf` object with the columns of `x`.

## Examples

``` r
if (requireNamespace("sf", quietly = TRUE)) {
  sq <- sf::st_sfc(sf::st_polygon(list(rbind(c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)))),
                   crs = 4326)
  cells <- sf::st_sf(geometry = sf::st_make_grid(sq, n = 4))
  s <- select_units(as_frame(cells), n = 4, seed = 1)
  as_sf(s, cells)
}
#> Simple feature collection with 16 features and 5 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 0 ymin: 0 xmax: 1 ymax: 1
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>                          geometry       lat   lon     area   pi sampled
#> 1  POLYGON ((0 0, 0.25 0, 0.25... 0.1250001 0.125 772.7707 0.25   FALSE
#> 2  POLYGON ((0.25 0, 0.5 0, 0.... 0.1250001 0.375 772.7707 0.25   FALSE
#> 3  POLYGON ((0.5 0, 0.75 0, 0.... 0.1250001 0.625 772.7707 0.25    TRUE
#> 4  POLYGON ((0.75 0, 1 0, 1 0.... 0.1250001 0.875 772.7707 0.25   FALSE
#> 5  POLYGON ((0 0.25, 0.25 0.25... 0.3750003 0.125 772.7560 0.25   FALSE
#> 6  POLYGON ((0.25 0.25, 0.5 0.... 0.3750003 0.375 772.7560 0.25   FALSE
#> 7  POLYGON ((0.5 0.25, 0.75 0.... 0.3750003 0.625 772.7560 0.25   FALSE
#> 8  POLYGON ((0.75 0.25, 1 0.25... 0.3750003 0.875 772.7560 0.25    TRUE
#> 9  POLYGON ((0 0.5, 0.25 0.5, ... 0.6250005 0.125 772.7265 0.25    TRUE
#> 10 POLYGON ((0.25 0.5, 0.5 0.5... 0.6250005 0.375 772.7265 0.25   FALSE
```
