# The sampled units of a sample

The rows of a
[`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
sample that were selected, as a plain tibble, for pipelines:
`frame |> select_units(n) |> sampled()`.

## Usage

``` r
sampled(sample)
```

## Arguments

- sample:

  A
  [`select_units()`](https://castlaboratory.github.io/fieldopt/reference/select_units.md)
  sample.

## Value

A tibble with the sampled rows (coordinates, `pi` and the other
columns).

## Examples

``` r
cells <- expand.grid(x = 1:6, y = 1:6)
cells |> select_units(n = 5, seed = 1) |> sampled()
#> # A tibble: 5 × 5
#>       x     y unit     pi sampled
#>   <int> <int> <chr> <dbl> <lgl>  
#> 1     6     1 u6    0.139 TRUE   
#> 2     1     3 u13   0.139 TRUE   
#> 3     3     3 u15   0.139 TRUE   
#> 4     6     5 u30   0.139 TRUE   
#> 5     2     6 u32   0.139 TRUE   
```
