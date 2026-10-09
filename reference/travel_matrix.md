# Travel matrix between the units of a frame

Builds the dense matrix of travel distances (or times) between all
units, depot included, from coordinates, or wraps a matrix computed
elsewhere, for example on a road network with OSRM. Distances from
coordinates are a first approximation; a network matrix is the honest
input when it is available.

## Usage

``` r
travel_matrix(
  coords,
  method = c("haversine", "euclidean"),
  matrix = NULL,
  unit = NULL
)
```

## Arguments

- coords:

  Data frame or matrix with two coordinate columns: `lat`, `lon`
  (degrees) for `method = "haversine"`, or `x`, `y` (planar, any unit)
  for `method = "euclidean"`. Row names, or a column `unit`, name the
  units.

- method:

  `"haversine"` (great-circle distance in kilometres) or `"euclidean"`.

- matrix:

  Optional square numeric matrix of travel costs already computed; when
  given, `coords` is only used for names and plotting.

- unit:

  Label of the travel unit (`"km"`, `"min"`, ...), kept for reports.

## Value

A square numeric matrix of class `fieldopt_matrix` with unit names as
dimnames and attributes `coords`, `method` and `unit`.

## Examples

``` r
segments <- data.frame(unit = c("depot", "s1", "s2", "s3"),
                       lat = c(-8.05, -8.10, -8.00, -8.12),
                       lon = c(-34.90, -34.95, -34.85, -34.80))
travel_matrix(segments)
#> Travel matrix: 4 units, haversine (km); mean off-diagonal 12.65.
```
