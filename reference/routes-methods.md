# Tidy and glance methods for routes and frontiers

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) of a
`fieldopt_routes` returns one row per stop (`route`, `stop`, `unit`, and
`leg`, the travel from the previous stop or the depot);
[`glance()`](https://generics.r-lib.org/reference/glance.html) one row
with the total travel, the lower bound, the gap, the number of routes
and the cost when a model was given.
[`glance()`](https://generics.r-lib.org/reference/glance.html) of a
`fieldopt_frontier` returns one row with the range of sample sizes,
costs and variances covered, the selection method and the replicates.

## Usage

``` r
# S3 method for class 'fieldopt_routes'
tidy(x, ...)

# S3 method for class 'fieldopt_routes'
glance(x, ...)

# S3 method for class 'fieldopt_frontier'
glance(x, ...)

# S3 method for class 'fieldopt_schedule'
tidy(x, ...)

# S3 method for class 'fieldopt_schedule'
glance(x, ...)
```

## Arguments

- x:

  A `fieldopt_routes` or `fieldopt_frontier`.

- ...:

  Unused.

## Value

A tibble.

## Examples

``` r
set.seed(1)
pts <- data.frame(unit = c("depot", paste0("s", 1:8)), x = c(0, runif(8)), y = c(0, runif(8)))
r <- route_fieldwork(travel_matrix(pts, method = "euclidean"), paste0("s", 1:8), "depot",
  max_stops = 4, iterations = 20
)
tidy(r)
#> # A tibble: 8 × 4
#>   route  stop unit     leg
#>   <int> <int> <chr>  <dbl>
#> 1     1     1 s5    0.716 
#> 2     1     2 s1    0.0862
#> 3     1     3 s3    0.523 
#> 4     1     4 s2    0.247 
#> 5     2     1 s8    0.827 
#> 6     2     2 s7    0.393 
#> 7     2     3 s6    0.389 
#> 8     2     4 s4    0.208 
glance(r)
#> # A tibble: 1 × 8
#>   n_units n_routes total lower_bound   gap optimal longest_route travel_unit
#>     <int>    <int> <dbl>       <dbl> <dbl> <lgl>           <dbl> <chr>      
#> 1       8        2  4.69        4.69     0 TRUE             2.74 distance   
```
