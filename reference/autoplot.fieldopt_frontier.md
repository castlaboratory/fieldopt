# Plot the cost-variance frontier

Plot the cost-variance frontier

## Usage

``` r
# S3 method for class 'fieldopt_frontier'
autoplot(object, ...)
```

## Arguments

- object:

  A `fieldopt_frontier`.

- ...:

  Unused.

## Value

A ggplot of mean cost against mean variance (or against `n` when no
study variable was given), labelled by sample size.
