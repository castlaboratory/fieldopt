# Dual-frame allocation (area frame plus list frame with overlap)

Hartley's (1962, 1974) design for two frames whose union covers the
population: frame A (typically the area frame, complete but expensive)
and frame B (the list, cheap but incomplete). The population splits into
the domains `a` (A only), `ab` (both) and `b` (B only), and the total is
estimated by `Y_a + theta * Y_ab(A) + (1 - theta) * Y_ab(B) + Y_b`: the
overlap is estimated from both samples and mixed with weight `theta`.
With simple random sampling in each frame (other designs enter through
design effects) the variance is a sum of two frame terms, so for each
`theta` the cost-optimal `n_A`, `n_B` follow the cost-weighted Neyman
rule; `theta` is then optimised. `theta = 0` is the **screening**
design, in which overlap units found in the area sample are not used
(the list covers them), the usual practice when the list holds the large
producers.

## Usage

``` r
dual_frame_allocation(
  domains,
  cost_a,
  cost_b,
  deff_a = 1,
  deff_b = 1,
  theta = NULL,
  target_variance = NULL,
  target_cv = NULL,
  budget = NULL
)
```

## Arguments

- domains:

  Data frame with one row per domain `a`, `ab`, `b` (column `domain`)
  and columns `size` (units), `mean` and `sd` of the study variable.

- cost_a, cost_b:

  Cost per sampled unit in frame A and frame B.

- deff_a, deff_b:

  Design effects of the two samples relative to simple random sampling
  (an area sample of segments or points usually has `deff_a > 1`).

- theta:

  `NULL` to optimise, a number in `[0, 1]`, or `"screening"` (zero).

- target_variance, target_cv, budget:

  Exactly one: target variance of the estimated total, target
  coefficient of variation (relative to the population total implied by
  `domains`), or budget.

## Value

A list of class `fieldopt_dual_frame`: `n_a`, `n_b`, `theta`, `cost`,
`variance`, `se`, `cv`, `total` (implied population total),
`variance_a`, `variance_b`, `overlap_a`, `overlap_b` (expected overlap
units in each sample), `bounded`, and the inputs.

## Details

The cost per area unit should include the field work: take it from the
routing, for example `cost_mean / n` of a
[`cost_variance_frontier()`](https://castlaboratory.github.io/fieldopt/reference/cost_variance_frontier.md)
at the sample size under consideration, and iterate once or twice.

## References

Hartley, H. O. (1962). Multiple frame surveys. *Proceedings of the
Social Statistics Section, ASA*, 203–206. Hartley, H. O. (1974).
Multiple frame methodology and selected applications. *Sankhya C*, 36,
99–118. Lohr, S. L. and Rao, J. N. K. (2006). Estimation in
multiple-frame surveys. *JASA*, 101(475), 1019–1030.

## Examples

``` r
domains <- data.frame(domain = c("a", "ab", "b"), size = c(8000, 1500, 500),
                      mean = c(5, 40, 60), sd = c(6, 30, 50))
dual_frame_allocation(domains, cost_a = 200, cost_b = 40, budget = 1e5)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum variance for budget 1e+05: n_A = 312 (frame A, cost 200/unit), n_B =
#> 940 (frame B, cost 40/unit), theta = 0.085 (optimised).
#> Cost 1e+05; variance 11780000 (frame A 8860000, frame B 2920000); CV 2.64% of
#> the total 130000.
#> Expected overlap units: 49.3 in the A sample, 705 in the B sample.
dual_frame_allocation(domains, cost_a = 200, cost_b = 40, theta = "screening", target_cv = 0.05)
#> 
#> ── Dual-frame allocation ───────────────────────────────────────────────────────
#> Minimum cost for target variance 42250000: n_A = 108 (frame A, cost 200/unit),
#> n_B = 323 (frame B, cost 40/unit), theta = 0 (fixed).
#> Cost 34520; variance 42070000 (frame A 27800000, frame B 14300000); CV 4.99% of
#> the total 130000.
#> Expected overlap units: 17.1 in the A sample, 242.2 in the B sample.
```
