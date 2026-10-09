# Tidy and glance methods for allocations

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) returns one
row per stratum, frame or stage;
[`glance()`](https://generics.r-lib.org/reference/glance.html) one row
with the totals.

## Usage

``` r
# S3 method for class 'fieldopt_allocation'
tidy(x, ...)

# S3 method for class 'fieldopt_allocation'
glance(x, ...)

# S3 method for class 'fieldopt_dual_frame'
tidy(x, ...)

# S3 method for class 'fieldopt_dual_frame'
glance(x, ...)

# S3 method for class 'fieldopt_two_stage'
tidy(x, ...)

# S3 method for class 'fieldopt_two_stage'
glance(x, ...)
```

## Arguments

- x:

  A `fieldopt_allocation`, `fieldopt_dual_frame` or
  `fieldopt_two_stage`.

- ...:

  Unused.

## Value

A tibble.

## Examples

``` r
strata <- data.frame(stratum = c("list", "area"), size = c(2000, 800),
                     sd = c(12, 30), cost = c(40, 180))
a <- frame_allocation(strata, budget = 20000)
tidy(a); glance(a)
#> # A tibble: 2 × 7
#>   stratum  size    sd  cost     n cost_total variance
#>   <chr>   <dbl> <dbl> <dbl> <int>      <dbl>    <dbl>
#> 1 list     2000    12    40   162       6480 3267556.
#> 2 area      800    30   180    75      13500 6960000 
#> # A tibble: 1 × 6
#>   mode   target     n  cost  variance bounded
#>   <chr>   <dbl> <int> <dbl>     <dbl> <lgl>  
#> 1 budget  20000   237 19980 10227556. FALSE  
```
