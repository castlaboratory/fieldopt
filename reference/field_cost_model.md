# Field cost model

Converts a routing solution and a sample into money (or time): a cost
per unit of travel, a fixed cost per route (a team-day: allowances,
vehicle, lodging), a fixed cost per visited unit (access, setup) and a
cost per interview.

## Usage

``` r
field_cost_model(
  per_travel = 1,
  per_unit = 0,
  per_interview = 0,
  interviews_per_unit = 1,
  per_route = 0,
  currency = "cost"
)
```

## Arguments

- per_travel:

  Cost per unit of the travel matrix (per km, per minute).

- per_unit:

  Fixed cost of visiting one unit.

- per_interview:

  Cost of one interview.

- interviews_per_unit:

  Expected interviews per visited unit: a single number, a vector with
  one value per row of the travel matrix (depot included, in the same
  order), or a function of the row indices of the visited units.

- per_route:

  Fixed cost of one route (one team for one day).

- currency:

  Label for reports.

## Value

An object of class `field_cost_model`.

## Examples

``` r
field_cost_model(per_travel = 1.2, per_unit = 50, per_interview = 15, interviews_per_unit = 8)
#> Field cost model (cost): 1.2 per travel unit, 0 per route, 50 per visited unit,
#> 15 per interview.
```
