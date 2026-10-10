# Travel matrix between the units of a frame

Builds the dense matrix of travel distances or times between all units,
depot included, in one of three ways:

## Usage

``` r
travel_matrix(
  coords,
  method = c("haversine", "euclidean", "osrm"),
  matrix = NULL,
  unit = NULL,
  detour = 1,
  measure = c("duration", "distance"),
  server = getOption("osrm.server"),
  profile = getOption("osrm.profile"),
  block = 100,
  bases = NULL,
  speed = NULL
)
```

## Arguments

- coords:

  Data frame or matrix with two coordinate columns: `lat`, `lon`
  (degrees) for `"haversine"` and `"osrm"`, or `x`, `y` (planar, any
  unit) for `"euclidean"`. Row names, or a column `unit`, name the
  units. A
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  sample is accepted and only its sampled units are used, so that
  `frame |> select_units(n) |> travel_matrix(bases = towns)` builds the
  matrix of the field work.

- method:

  `"haversine"`, `"euclidean"` or `"osrm"`.

- matrix:

  Optional square numeric matrix of travel costs already computed; when
  given, `method` is ignored except for the coordinate columns it
  implies.

- unit:

  Label of the travel unit (`"km"`, `"min"`, ...), kept for reports; set
  automatically unless a matrix is supplied.

- detour:

  Multiplier applied to straight-line distances (`>= 1`). Ignored, with
  a warning, for `"osrm"` and supplied matrices.

- measure:

  For `"osrm"`: `"duration"` (minutes) or `"distance"` (kilometres on
  the network).

- server, profile:

  For `"osrm"`: the base URL of the routing server and the profile
  (`"car"`, `"bike"`, `"foot"`); default to the `osrm` package options.

- block:

  For `"osrm"`: number of origins and of destinations per request
  (`block^2` cells each).

- bases:

  Optional data frame of depots (a `unit` column and the same coordinate
  columns) put in front of `coords`.

- speed:

  Optional speed in coordinate units per hour (kilometres per hour with
  `"haversine"`): the distances are turned into minutes and `unit`
  becomes `"min"`. Ignored for `"osrm"` durations.

## Value

A square numeric matrix of class `fieldopt_matrix` with unit names as
dimnames and attributes `coords`, `method`, `unit`, `detour` and, for
`"osrm"`, `snap` (the distance in kilometres from each unit to the point
of the network it was snapped to: large values flag units far from any
road).

## Details

- from coordinates, as straight-line distances: great-circle
  (`"haversine"`, kilometres) with `lat`/`lon`, or Euclidean with planar
  `x`/`y`. A `detour` factor (the ratio of road to straight-line
  distance, typically 1.2 to 1.4 on rural road networks) turns them into
  a planning estimate of road distances when no network is available;

- from a road network, with `method = "osrm"`: durations (minutes) or
  distances (kilometres) from an OSRM server through the `osrm` package,
  requested in blocks so that the server's table limit is respected (the
  public demo server allows 10 000 cells per request, and is meant for
  small tests only: run your own server for a frame);

- from a matrix computed elsewhere (`matrix`), with the coordinates used
  only for names and plots.

Road matrices need not be symmetric (one-way streets, different
durations by direction); the routing solver prices every leg in the
direction travelled.

## Examples

``` r
segments <- data.frame(
  unit = c("depot", "s1", "s2", "s3"),
  lat = c(-8.05, -8.10, -8.00, -8.12),
  lon = c(-34.90, -34.95, -34.85, -34.80)
)
travel_matrix(segments)
#> Travel matrix: 4 units, haversine (km); mean off-diagonal 12.65.
travel_matrix(segments, detour = 1.3)
#> Travel matrix: 4 units, haversine x 1.3 (km); mean off-diagonal 16.44.
if (FALSE) { # \dontrun{
# road durations from the OSRM demo server (small frames only)
travel_matrix(segments, method = "osrm", measure = "duration")
} # }
```
