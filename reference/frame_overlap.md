# Overlap between a list frame and the area frame

Finds, for every establishment of a list frame, the cell of the area
frame it falls in, and marks its domain: `"ab"` when it lies in a cell
of the frame (it can be reached through the area sample as well), `"b"`
otherwise. The cells get the count and the names of the listed
establishments inside them, which is what field teams need to screen the
overlap out of the area sample (the screening design) or what
[`dual_frame_estimator()`](https://castlaboratory.github.io/fieldopt/reference/dual_frame_estimator.md)
needs as domains.

## Usage

``` r
frame_overlap(list, cells, cell_size = 1, coords = NULL, pairs = NULL)
```

## Arguments

- list:

  Data frame of the list frame with a column `unit` and the coordinate
  columns (or an `sf` object of points).

- cells:

  The area frame as in
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  (or an `sf` object of polygons with a `unit` column).

- cell_size:

  Side of the square cells, in the unit of the coordinates (ignored for
  polygons).

- coords:

  Names of the coordinate columns in both tables.

- pairs:

  Optional data frame with columns `unit` (list) and `cell`.

## Value

A list with `list` (the list frame with columns `cell` and `domain`) and
`cells` (the area frame with columns `listed`, the number of listed
establishments inside, and `listed_units`, their names).

## Details

Locations are matched with coordinates: square cells of side `cell_size`
around the cell centres (the columns `coords`), or exact polygons when
`cells` and `list` are `sf` objects (the `sf` package is then used). A
table of `pairs` from record linkage (for example from the `reclin2`
package) can add or override matches: rows with the list unit and the
cell it belongs to.

## Examples

``` r
cells <- expand.grid(x = 1:5, y = 1:5)
cells$unit <- paste0("c", 1:25)
farms <- data.frame(unit = c("f1", "f2", "f3"), x = c(1.2, 3.4, 9), y = c(1.1, 2.6, 9))
ov <- frame_overlap(farms, cells, cell_size = 1)
ov$list
#> # A tibble: 3 × 5
#>   unit      x     y cell  domain
#>   <chr> <dbl> <dbl> <chr> <chr> 
#> 1 f1      1.2   1.1 c1    ab    
#> 2 f2      3.4   2.6 c13   ab    
#> 3 f3      9     9   NA    b     
ov$cells[ov$cells$listed > 0, ]
#> # A tibble: 2 × 5
#>       x     y unit  listed listed_units
#>   <int> <int> <chr>  <int> <list>      
#> 1     1     1 c1         1 <chr [1]>   
#> 2     3     3 c13        1 <chr [1]>   
```
