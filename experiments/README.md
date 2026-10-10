# experiments/

Reproducible experiments behind the fieldopt methodology notes. Nothing here is part of
the R package (the directory is in `.Rbuildignore`); `out/` is gitignored.

```
run/        runners, one per experiment; resumable (one rds per unit of work in out/<exp>/)
analysis/   scripts that turn out/<exp>/ into tables, figures (figures/) and a report (*.md)
figures/    the figures the reports embed (tracked, small PNGs)
out/        results (gitignored): <exp>/{*.rds, session.txt, run.log}
```

| Experiment | Question | Run | Report |
|---|---|---|---|
| E1 | What does spatial balance cost in travel and gain in variance, and which wins at equal budget? lpm and systematic (Hilbert) against srs, Gaussian fields at four spatial ranges, routed cost curves of each design, same frames and costs as E2 | `Rscript experiments/run/e1_spatial_balance.R [cores] [pilot]` then `Rscript experiments/analysis/e1_summary.R` | `e1_spatial_balance.md` |
| E3 | Are the variance estimators of `design_variance()` right under srs, lpm and systematic designs? Bias and coverage on the E1 fields; found and fixed the local-mean neighbourhood (fieldopt-core 0.10.0) | `Rscript experiments/run/e3_variance_estimators.R [cores] [pilot]` then `Rscript experiments/analysis/e3_summary.R` | `e3_variance_estimators.md` |
| E2 | How wrong is allocation with a constant cost per primary unit when the real cost is routed? Two-stage (Cochran) and dual-frame (Hartley) allocation; linear rule, the package's fixed-point loop, a marginal-cost loop and an oracle, on a real 449-cell grid and two synthetic frames | `Rscript experiments/run/e2_allocation_cost.R [cores] [pilot]` then `Rscript experiments/analysis/e2_summary.R` | `e2_allocation_cost.md` |

The runs need the development version of the package installed (`devtools::install()`),
`arrow` for the real frame, and `dplyr`, `tidyr`, `purrr`, `ggplot2`, `knitr`. The real
frame is `cells.parquet` from the areaframe project, read with `read_areaframe()`.
