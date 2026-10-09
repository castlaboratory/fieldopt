# Two-stage allocation with a field cost function

`n` primary units (segments, grid cells) are visited and `m` secondary
units (points, tracts, establishments) are observed in each, at a cost
`c1 * n + c2 * n * m`. With `s2_between` the variance among primary-unit
means and `s2_within` the variance within primary units, the variance of
the estimated mean per secondary unit is
`(1 - n/N) s2_between / n + (1 - m/M) s2_within / (n m)` and the
cost-optimal `m` is
`sqrt(c1 s2_within / (c2 (s2_between - s2_within / M)))` (Cochran 1977,
Section 10.6). The cost `c1` of visiting a primary unit is where the
routing enters: it is not a constant but depends on how spread the
sample is; take it from
[`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
at the candidate `n` and iterate.

## Usage

``` r
two_stage_allocation(
  n_primary,
  m_secondary,
  s2_between,
  s2_within,
  c1,
  c2,
  target_variance = NULL,
  target_cv = NULL,
  budget = NULL,
  mean = NULL
)
```

## Arguments

- n_primary, m_secondary:

  Primary units in the population and secondary units per primary unit
  (an average when they differ).

- s2_between, s2_within:

  Variance among primary-unit means and within primary units.

- c1, c2:

  Cost per primary unit visited and per secondary unit observed.

- target_variance, target_cv, budget:

  Exactly one: target variance of the estimated **total**, target
  coefficient of variation (needs `mean`), or budget.

- mean:

  Population mean per secondary unit, for `target_cv`.

## Value

A list of class `fieldopt_two_stage`: `n`, `m`, `m_optimal`, `cost`,
`variance_mean`, `variance_total`, `se_total`, `cv` (when `mean` is
given), `bounded`.

## Examples

``` r
two_stage_allocation(n_primary = 5000, m_secondary = 20, s2_between = 4, s2_within = 25,
                     c1 = 300, c2 = 20, budget = 1e5)
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 185 primary units with m = 12 secondary units each (optimal m 11.68): cost
#> 99900, variance of the total 253300000 (SE 15910).
two_stage_allocation(5000, 20, 4, 25, c1 = 300, c2 = 20, target_cv = 0.03, mean = 12)
#> 
#> ── Two-stage allocation ────────────────────────────────────────────────────────
#> n = 38 primary units with m = 12 secondary units each (optimal m 11.68): cost
#> 20520, variance of the total 1.264e+09 (SE 35550, CV 2.96%).
```
