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
| E1b | E1 with real variables: frame F4, the 7,868 cells of 1 km² of the IBGE 2022 statistical grid in the Vale do Ipojuca microregion (PE), with population and households (Censo 2022), MapBiomas 2024 land-use shares and altitude (Copernicus DEM); also the estimator check of E3 | `Rscript experiments/data/build_f4_ipojuca.R`, then `Rscript experiments/run/e1b_real_variables.R [cores] [pilot]` and `Rscript experiments/analysis/e1b_summary.R` | `e1b_real_variables.md` |
| E1c | Skewed variables of F4 (population, households, urban and agriculture shares): stratification and probability proportional to size from MapBiomas 2018 land use, with routed cost curves for each design; coverage, variance and the multi-purpose trade-off | `Rscript experiments/run/e1c_stratification.R [cores] [pilot]` then `Rscript experiments/analysis/e1c_summary.R` | `e1c_stratification.md` |
| E2 | How wrong is allocation with a constant cost per primary unit when the real cost is routed? Two-stage (Cochran) and dual-frame (Hartley) allocation; linear rule, the package's fixed-point loop, a marginal-cost loop and an oracle, on a real 449-cell grid and two synthetic frames | `Rscript experiments/run/e2_allocation_cost.R [cores] [pilot]` then `Rscript experiments/analysis/e2_summary.R` | `e2_allocation_cost.md` |

Frame F4 is built from public data (IBGE 2022 grid, MapBiomas, Copernicus DEM) by
`experiments/data/build_f4_ipojuca.R` and stored in `experiments/data/` (about 400 kB); the
national grid it downloads is cached in `experiments/out/cache/` (ignored). The runs need the
development version of the package installed (`devtools::install()`),
`arrow` for the real frame, and `dplyr`, `tidyr`, `purrr`, `ggplot2`, `knitr`. The real
frame is `cells.parquet` from the areaframe project, read with `read_areaframe()`.
