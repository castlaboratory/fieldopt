# Read the cells of an area frame exported by the areaframe service

Reads a frame of grid cells as exported by the area-frame service (a
Parquet file with `cell_index`, `centroid_lon`, `centroid_lat`,
`area_m2` and the geometry as WKB, plus any stratum or covariate
columns) or any spatial file `sf` can read (GeoPackage, GeoJSON,
shapefile), and returns the plain frame
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
works on: `unit`, `lat`, `lon`, `area` in square kilometres (also used
as `size`), and the other columns. With `sf = TRUE` the geometries are
kept and an `sf` object is returned instead (see
[`as_frame()`](https://castlaboratory.github.io/fieldopt/reference/as_frame.md)
and
[`as_sf()`](https://castlaboratory.github.io/fieldopt/reference/as_sf.md)).

## Usage

``` r
read_areaframe(path, sf = FALSE)
```

## Arguments

- path:

  Path to the file.

- sf:

  Return an `sf` object with the geometries.

## Value

A tibble, or an `sf` object.

## Examples

``` r
if (FALSE) { # \dontrun{
cells <- read_areaframe("cells.parquet")
s <- select_units(cells, n = 300, size = "area", strata = "stratum")
} # }
```
