# E1b summary: price and gain of spatial balance with real variables (frame F4)
#
# Usage:  Rscript experiments/analysis/e1b_summary.R [out_dir]
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(knitr)
})
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else "experiments/out/e1b"
fig_dir <- "experiments/figures"
res <- readRDS(file.path(out_dir, "e1b_results.rds"))
st <- res$settings
session <- readLines(file.path(out_dir, "session.txt"))
var_levels <- st$VARS
design_levels <- st$DESIGNS$design
labels <- c(pop = "population", households = "households", agri = "agriculture share",
            pasture = "pasture share", mosaic = "mosaic of uses share", native = "native vegetation share",
            urban = "urban share", elev = "altitude")

# ---- true variances and design effects ------------------------------------------------
per <- res$est |>
  left_join(res$truth, by = "y") |>
  group_by(design, n, y) |>
  summarise(
    true_var = var(total), mean_est = mean(variance),
    coverage = mean(abs(total - true_total) <= qt(0.975, df) * sqrt(variance)),
    method = first(method), .groups = "drop"
  ) |>
  mutate(rel_bias = mean_est / true_var - 1, y = factor(y, var_levels), design = factor(design, design_levels)) |>
  group_by(y, n) |>
  mutate(deff = true_var / true_var[design == "srs"]) |>
  ungroup()
deff_tab <- per |>
  filter(design %in% c("lpm", "systematic", "systematic_r4")) |>
  select(y, design, n, deff) |>
  pivot_wider(names_from = n, values_from = deff, names_prefix = "n = ") |>
  arrange(y, design) |>
  left_join(res$autocorr |> mutate(y = factor(y, var_levels)) |> select(y, moran_i), by = "y") |>
  relocate(moran_i, .after = y)

# ---- price: travel ratio ------------------------------------------------------------------
cv <- res$curves |> arrange(selection, limit, n)
interp <- function(x, y, xo, log = FALSE) {
  if (log) exp(approx(log(x), log(y), log(xo), rule = 2)$y) else approx(x, y, xo, rule = 2)$y
}
travel_ratio <- cv |>
  group_by(limit) |>
  group_modify(\(d, k) {
    s <- d |> filter(selection == "srs")
    d |> filter(selection != "srs") |> mutate(rho = travel_mean / interp(s$n, s$travel_mean, n))
  }) |>
  ungroup()
rho_tab <- travel_ratio |>
  mutate(band = case_when(n <= 40 ~ "n <= 40", n <= 150 ~ "40 < n <= 150", TRUE ~ "n > 150")) |>
  group_by(selection, limit, band) |>
  summarise(rho = mean(rho), .groups = "drop") |>
  pivot_wider(names_from = band, values_from = rho) |>
  select(selection, limit, `n <= 40`, `40 < n <= 150`, `n > 150`)
fit_law <- cv |>
  filter(n >= 20) |>
  group_by(selection, limit) |>
  summarise(exponent = coef(lm(log(travel_mean) ~ log(n)))[2], .groups = "drop")

# ---- equal budget ---------------------------------------------------------------------------
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
design_curve <- c(srs = "srs", lpm = "lpm", systematic = "systematic", systematic_r4 = "systematic")
budget_rows <- expand_grid(limit = unique(cv$limit), interviews = names(st$INTERVIEW_COST), n_srs = c(20, 40, 80, 160)) |>
  pmap(\(limit, interviews, n_srs) {
    ic <- st$INTERVIEW_COST[[interviews]]
    Gs <- map(design_curve, \(p) G_of(cv |> filter(limit == !!limit, selection == p)))
    budget <- Gs$srs(n_srs) + ic * n_srs
    n_p <- map_dbl(Gs, \(G) n_at_budget(G, ic, budget, 2, max(st$N_VAR)))
    map(var_levels, \(v) {
      V <- map_dbl(names(n_p), \(p) {
        d <- per |> filter(design == p, y == v) |> arrange(n)
        interp(d$n, d$true_var, n_p[[p]], log = TRUE)
      })
      tibble(limit = limit, interviews = interviews, n_srs = n_srs, y = v, design = names(n_p),
             n = n_p, efficiency = V / V[1], n_ratio = n_p / n_p[1])
    }) |> list_rbind()
  }) |> list_rbind() |>
  mutate(y = factor(y, var_levels))
eff_tab <- budget_rows |>
  filter(design != "srs") |>
  group_by(y, design) |>
  summarise(best = min(efficiency), worst = max(efficiency), wins = mean(efficiency < 1),
            efficiency = mean(efficiency), .groups = "drop") |>
  relocate(efficiency, .after = design) |>
  arrange(y, design)

# ---- estimators -------------------------------------------------------------------------------
est_tab <- per |>
  group_by(y, design, method) |>
  summarise(rel_bias = mean(rel_bias), coverage = mean(coverage), .groups = "drop") |>
  arrange(y, design)

# ---- figures -----------------------------------------------------------------------------------
theme_set(theme_minimal(base_size = 10))
p1 <- per |>
  filter(design != "srs") |>
  ggplot(aes(n, deff, colour = design)) +
  geom_hline(yintercept = 1, colour = "grey50") +
  geom_line() + geom_point(size = 0.8) +
  scale_x_log10() +
  facet_wrap(~y, nrow = 2, labeller = as_labeller(labels)) +
  labs(x = "sample size n (log scale)", y = "design effect V(design) / V(srs)", colour = "design")
ggsave(file.path(fig_dir, "e1b-deff.png"), p1, width = 7, height = 3.8, dpi = 110)
p2 <- budget_rows |>
  filter(design != "srs") |>
  group_by(y, design) |>
  summarise(lo = min(efficiency), hi = max(efficiency), efficiency = mean(efficiency), .groups = "drop") |>
  ggplot(aes(efficiency, y, colour = design)) +
  geom_vline(xintercept = 1, colour = "grey50") +
  geom_pointrange(aes(xmin = lo, xmax = hi), position = position_dodge(width = 0.5), size = 0.25) +
  scale_y_discrete(labels = labels) +
  labs(x = "variance at equal budget / variance of srs", y = NULL, colour = "design")
ggsave(file.path(fig_dir, "e1b-equal-budget.png"), p2, width = 6.5, height = 3.4, dpi = 110)

# ---- report ------------------------------------------------------------------------------------
tbl <- function(d, digits = 2) paste(kable(d, digits = digits, format = "pipe"), collapse = "\n")
pct <- function(x) sprintf("%+.0f%%", 100 * x)
report <- c(
  "# E1b — spatial balance with real study variables",
  "",
  paste0("Generated by `experiments/analysis/e1b_summary.R` from `", out_dir, "` (", tail(session, 1), ")."),
  "",
  "## Data",
  "",
  paste0("Frame F4: the ", res$N, " cells of 1 km² of the IBGE 2022 statistical grid (grade estatística,",
         " `BR1KM_20251002`) in the Vale do Ipojuca microregion, Pernambuco agreste (IBGE code 26008), built by"),
  "`experiments/data/build_f4_ipojuca.R`. Variables per cell: population and private households (IBGE,",
  "Censo Demográfico 2022); shares of agriculture, pasture, mosaic of uses (MapBiomas class 21, mostly",
  "smallholder crops mixed with pasture), native vegetation and urban area (MapBiomas Collection 10,",
  "2024, 30 m); mean altitude (Copernicus DEM GLO-30). Depot in Caruaru; travel by haversine distance x",
  "1.3 at 60 km/h; costs as in E1 and E2 (1.5 per minute, 60 per visited cell, 200 per daily route).",
  paste0("Designs srs, lpm, systematic (Hilbert) in one and in four replicates; ", st$R_SAMPLES,
         " samples per design and n in {", paste(st$N_VAR, collapse = ", "), "}."),
  "",
  "## Spatial structure of the variables",
  "",
  "Moran's I with the 8 nearest cells, and the coefficient of variation across cells:",
  "",
  tbl(res$autocorr |> mutate(y = labels[y])),
  "",
  "## Gain: design effect at equal n (true variance)",
  "",
  tbl(deff_tab |> mutate(y = labels[as.character(y)])),
  "",
  "![Design effects](figures/e1b-deff.png)",
  "",
  "## Price: travel of the design over the travel of srs at equal n",
  "",
  tbl(rho_tab),
  "",
  "Exponent of n in the travel (BHH predicts 0.5):",
  "",
  tbl(fit_law, 3),
  "",
  "## Equal budget",
  "",
  "Variance of the design over the variance of srs at the same budget (mean, best and worst over route",
  "limits, interview costs and budgets buying 20 to 160 srs units; `wins` is the share of cases below 1):",
  "",
  tbl(eff_tab |> mutate(y = labels[as.character(y)])),
  "",
  "![Equal budget](figures/e1b-equal-budget.png)",
  "",
  "## Variance estimators (as E3)",
  "",
  "Relative bias of `design_variance()` and coverage of the t interval, mean over n:",
  "",
  tbl(est_tab |> mutate(y = labels[as.character(y)], rel_bias = pct(rel_bias)), 3),
  "",
  "## What this means",
  "",
  "1. **The price of balance on a real 1 km grid is 7 to 14% more travel** at equal n, slightly more than",
  "   on the synthetic frames of E1 because the frame is larger (the advantage of srs samples, which clump",
  "   by chance, persists to larger n). The travel exponent is 0.44 to 0.45, close to BHH.",
  "2. **Every real variable is spatially autocorrelated** (Moran's I 0.50 to 0.95 with 8 neighbours), and",
  "   balance wins at equal budget for all of them with lpm: the variance falls by 13 to 14% for population",
  "   and households, 18 to 32% for the land-use shares and 72% for altitude. This is the region of E1",
  "   between the `short` and `long` ranges, as the Moran's I suggests.",
  "3. **lpm is the safest design**: it never loses by more than 4% (population, households at the",
  "   smallest budget) and wins in most cases. Systematic sampling in one replicate is close to lpm for",
  "   the land-use shares; with four replicates it gives up part of the gain (the replicates are",
  "   coarser samples) in exchange for an unbiased variance estimate.",
  "4. **Estimators**: as in E3, srs and replicates are unbiased and the local-mean estimator is",
  "   conservative (+7 to +46%). The low coverage for population, households, agriculture and urban",
  "   share (0.61 to 0.86 for *every* design, srs included) is not a variance problem: these variables",
  "   are extremely skewed (coefficient of variation 4 to 6 across cells; most cells are empty and a",
  "   few hold towns), so the HT total is far from normal at n <= 160. Such variables need stratification",
  "   by size (urban cells apart) or probability proportional to a size measure, not a better variance",
  "   estimator; the shares of pasture, mosaic and native vegetation and altitude cover 0.92 to 0.97.",
  "5. For the paper: E1's conclusion holds on real data. With a routed price of about 10% in travel, a",
  "   spatially balanced design is worth it for every variable an agricultural or household area-frame",
  "   survey measures here; the size of the gain tracks the spatial autocorrelation of the variable."
)
writeLines(report, "experiments/e1b_real_variables.md")
saveRDS(list(per = per, deff = deff_tab, rho = rho_tab, efficiency = eff_tab, estimators = est_tab,
             budget_rows = budget_rows), file.path(out_dir, "e1b_tables.rds"))
message("report written")
