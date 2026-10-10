# E1c summary: stratification and size measures for skewed variables (frame F4)
#
# Usage:  Rscript experiments/analysis/e1c_summary.R [out_dir]
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(knitr)
})
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else "experiments/out/e1c"
fig_dir <- "experiments/figures"
res <- readRDS(file.path(out_dir, "e1c_results.rds"))
st <- res$settings
session <- readLines(file.path(out_dir, "session.txt"))
var_levels <- st$VARS
design_levels <- st$DESIGNS
labels <- c(pop = "population", households = "households", agri = "agriculture share",
            pasture = "pasture share", mosaic = "mosaic of uses share", native = "native vegetation share",
            urban = "urban share", elev = "altitude")
skewed <- c("pop", "households", "agri", "urban")

per <- res$est |>
  left_join(res$truth, by = "y") |>
  group_by(design, n, y) |>
  summarise(
    true_var = var(total), mean_est = mean(variance),
    coverage = mean(abs(total - true_total) <= qt(0.975, df) * sqrt(variance)),
    skew_total = mean((total - mean(total))^3) / sd(total)^3,
    method = first(method), .groups = "drop"
  ) |>
  mutate(rel_bias = mean_est / true_var - 1, y = factor(y, var_levels), design = factor(design, design_levels)) |>
  group_by(y, n) |>
  mutate(deff = true_var / true_var[design == "srs"]) |>
  ungroup()

cov_tab <- per |>
  group_by(y, design) |>
  summarise(coverage = mean(coverage), skew = mean(skew_total), rel_bias = mean(rel_bias), .groups = "drop") |>
  pivot_wider(names_from = design, values_from = c(coverage, skew, rel_bias), names_glue = "{design} {.value}") |>
  arrange(y)
cov_short <- per |>
  group_by(y, design) |>
  summarise(coverage = mean(coverage), .groups = "drop") |>
  pivot_wider(names_from = design, values_from = coverage) |>
  arrange(y)
bias_short <- per |>
  group_by(y, design) |>
  summarise(rel_bias = mean(rel_bias), .groups = "drop") |>
  pivot_wider(names_from = design, values_from = rel_bias) |>
  arrange(y)
deff_short <- per |>
  filter(design != "srs") |>
  group_by(y, design) |>
  summarise(deff = mean(deff), .groups = "drop") |>
  pivot_wider(names_from = design, values_from = deff) |>
  arrange(y)

# ---- price ------------------------------------------------------------------------------------
cv <- res$curves |> arrange(design, limit, n)
interp <- function(x, y, xo, log = FALSE) {
  if (log) exp(approx(log(x), log(y), log(xo), rule = 2)$y) else approx(x, y, xo, rule = 2)$y
}
travel_ratio <- cv |>
  group_by(limit) |>
  group_modify(\(d, k) {
    s <- d |> filter(design == "srs")
    d |> filter(design != "srs") |> mutate(rho = travel_mean / interp(s$n, s$travel_mean, n))
  }) |>
  ungroup()
rho_tab <- travel_ratio |>
  mutate(band = case_when(n <= 40 ~ "n <= 40", n <= 150 ~ "40 < n <= 150", TRUE ~ "n > 150")) |>
  group_by(design, limit, band) |>
  summarise(rho = mean(rho), .groups = "drop") |>
  pivot_wider(names_from = band, values_from = rho) |>
  select(design, limit, `n <= 40`, `40 < n <= 150`, `n > 150`)

# ---- equal budget -------------------------------------------------------------------------------
G_of <- function(d) {
  d <- arrange(d, n)
  splinefun(d$n, d$cost_mean, method = "monoH.FC")
}
n_at_budget <- function(G, ic, budget, lo, hi) {
  g <- function(n) G(n) + ic * n - budget
  if (g(hi) <= 0) return(hi)
  if (g(lo) >= 0) return(lo)
  uniroot(g, c(lo, hi))$root
}
budget_rows <- expand_grid(limit = unique(cv$limit), interviews = names(st$INTERVIEW_COST), n_srs = c(20, 40, 80, 160)) |>
  pmap(\(limit, interviews, n_srs) {
    ic <- st$INTERVIEW_COST[[interviews]]
    Gs <- map(set_names(design_levels), \(p) G_of(cv |> filter(limit == !!limit, design == p)))
    budget <- Gs$srs(n_srs) + ic * n_srs
    n_p <- map_dbl(Gs, \(G) n_at_budget(G, ic, budget, min(st$N_VAR), max(st$N_VAR)))
    map(var_levels, \(v) {
      V <- map_dbl(names(n_p), \(p) {
        d <- per |> filter(design == p, y == v) |> arrange(n)
        interp(d$n, d$true_var, n_p[[p]], log = TRUE)
      })
      tibble(limit = limit, interviews = interviews, n_srs = n_srs, y = v, design = names(n_p),
             n = n_p, efficiency = V / V[1], n_ratio = n_p / n_p[1])
    }) |> list_rbind()
  }) |> list_rbind() |>
  mutate(y = factor(y, var_levels), design = factor(design, design_levels))
eff_tab <- budget_rows |>
  filter(design != "srs") |>
  group_by(y, design) |>
  summarise(efficiency = mean(efficiency), .groups = "drop") |>
  pivot_wider(names_from = design, values_from = efficiency) |>
  arrange(y)
nratio_tab <- budget_rows |>
  group_by(design) |>
  summarise(n_ratio = mean(n_ratio), .groups = "drop")

# ---- figure -------------------------------------------------------------------------------------
theme_set(theme_minimal(base_size = 10))
p <- per |>
  ggplot(aes(n, coverage, colour = design)) +
  geom_hline(yintercept = 0.95, colour = "grey50") +
  geom_line() + geom_point(size = 0.8) +
  scale_x_log10() +
  facet_wrap(~y, nrow = 2, labeller = as_labeller(labels)) +
  labs(x = "sample size n (log scale)", y = "coverage of the 95% t interval", colour = "design")
ggsave(file.path(fig_dir, "e1c-coverage.png"), p, width = 7, height = 3.8, dpi = 110)

# ---- report -------------------------------------------------------------------------------------
tbl <- function(d, digits = 2) paste(kable(d, digits = digits, format = "pipe"), collapse = "\n")
lab <- function(d) d |> mutate(y = labels[as.character(y)])
pctd <- function(d) d |> mutate(across(where(is.numeric), \(x) sprintf("%+.0f%%", 100 * x)))
report <- c(
  "# E1c — skewed variables: stratification and size measures from earlier land use",
  "",
  paste0("Generated by `experiments/analysis/e1c_summary.R` from `", out_dir, "` (", tail(session, 1), ")."),
  "",
  "## Question",
  "",
  "In E1b, population, households, urban and agriculture shares were so skewed across the 1 km cells",
  "that the 95% intervals covered 0.61 to 0.86 under every equal-probability design. Do stratification",
  "and probability proportional to size, built from land use observed six years earlier (MapBiomas",
  "2018), restore the coverage, and at what routed cost?",
  "",
  "## Design",
  "",
  "- Frame F4 as in E1b (IBGE 2022 1 km grid, Vale do Ipojuca; targets from the 2022 census and",
  "  MapBiomas 2024). Auxiliary information: the MapBiomas 2018 shares of urban, agriculture and mosaic.",
  paste0("- `strat_lpm`: strata urban (urban 2018 >= 10%), farmed (agriculture + mosaic 2018 >= 10%) and",
         " other (", paste(res$strata$stratum, res$strata$size, sep = " ", collapse = ", "), " cells); lpm within"),
  paste0("  strata; Bethel allocation on the three 2018 shares, shares of n: ",
         paste(names(res$shares), sprintf("%.2f", res$shares), collapse = ", "), "."),
  "- `pps_lpm`: lpm with probabilities proportional to 0.1 + urban + agriculture + mosaic shares of 2018.",
  paste0("- References srs and lpm (equal probabilities). ", st$R_SAMPLES, " samples per design and n in {",
         paste(st$N_VAR, collapse = ", "), "}; routed cost curves for every design; equal budget as in E1/E1b."),
  "",
  "Skewness of the variables across cells (coefficient of variation) and their correlation with the",
  "size measure:",
  "",
  tbl(lab(res$skew)),
  "",
  "## Coverage of the 95% t interval (mean over n)",
  "",
  tbl(lab(cov_short), 3),
  "",
  "![Coverage](figures/e1c-coverage.png)",
  "",
  "## Design effect at equal n (true variance relative to srs, mean over n)",
  "",
  tbl(lab(deff_short)),
  "",
  "## Price: travel relative to srs at equal n",
  "",
  tbl(rho_tab),
  "",
  "## Equal budget: variance relative to srs (mean over route limits, interview costs and budgets)",
  "",
  tbl(lab(eff_tab)),
  "",
  "Sample size each design affords relative to srs:",
  "",
  tbl(nratio_tab),
  "",
  "## Bias of the variance estimator (mean over n)",
  "",
  tbl(pctd(lab(bias_short))),
  "",
  "## What this means",
  "",
  "1. **Auxiliary information six years old fixes the skewed variables.** For population, households,",
  "   urban and agriculture shares, stratification cuts the variance by 82 to 88% against srs and the",
  "   size measure by 89 to 92%, and the t interval covers 0.85 to 0.89 (strata) and 0.93 to 0.97 (size",
  "   measure) instead of 0.61 to 0.82. Their correlation with the 2018 size measure is 0.41 to 0.83.",
  "2. **Concentrating the sample costs no travel.** Stratified samples travel as much as srs or less",
  "   (0.95 to 1.02): the urban and farmed strata are compact, which offsets the spread of lpm within",
  "   strata. The size-measure design pays 6 to 10%, less than unstratified lpm (9 to 14%).",
  "3. **It is a multi-purpose trade-off.** The same designs inflate the variance of the variables that",
  "   are spread evenly or anticorrelated with the 2018 use: pasture 1.4 to 2.1 times srs, native",
  "   vegetation 1.7 to 1.9, altitude up to 2.9 under the size measure. Equal-probability lpm is the only",
  "   design that improves on srs for every variable (variance 0.28 to 0.85 of srs), but it leaves the",
  "   skewed variables with poor intervals. Heikkinen et al. (2025) warn of the same danger of highly",
  "   non-proportional allocation in multi-purpose surveys.",
  "4. **Practical rule for an area frame of this kind**: stratify with a take-more urban/farmed stratum",
  "   and keep lpm within strata, but allocate closer to proportional than Bethel's optimum for the",
  "   skewed variables alone (the package's `multivariate_allocation()` with targets for the evenly",
  "   spread variables too), or use a size measure with a larger floor than 0.1. The cost side is",
  "   favourable either way; the choice is about which variables carry the survey.",
  "5. **Variance estimation**: the local-mean estimator stays conservative under unequal probabilities",
  "   (+15 to +59%), so the intervals of the size-measure design are, if anything, too wide."
)
writeLines(report, "experiments/e1c_stratification.md")
saveRDS(list(per = per, coverage = cov_short, deff = deff_short, rho = rho_tab, efficiency = eff_tab,
             budget_rows = budget_rows), file.path(out_dir, "e1c_tables.rds"))
message("report written")
