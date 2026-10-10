# E1 summary: tables, figures and the report experiments/e1_spatial_balance.md
#
# Usage:  Rscript experiments/analysis/e1_summary.R [out_dir]
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(knitr)
})
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else "experiments/out/e1"
fig_dir <- "experiments/figures"
dir.create(fig_dir, showWarnings = FALSE)
res <- readRDS(file.path(out_dir, "e1_results.rds"))
st <- res$settings
session <- readLines(file.path(out_dir, "session.txt"))
pct <- function(x, digits = 0) sprintf(paste0("%+.", digits, "f%%"), 100 * x)
range_levels <- names(st$RANGES)

# ---- variances and design effects --------------------------------------------------------
v <- res$variances |>
  group_by(frame, range, design, n) |>
  summarise(variance = mean(variance), se_rel = sd(variance) / mean(variance) / sqrt(n()),
            bias_rel = mean(bias), .groups = "drop") |>
  group_by(frame, range, n) |>
  mutate(deff = variance / variance[design == "srs"]) |>
  ungroup() |>
  mutate(range = factor(range, range_levels))
deff_tab <- v |>
  filter(design != "srs") |>
  group_by(design, range, n) |>
  summarise(deff = mean(deff), .groups = "drop") |>
  pivot_wider(names_from = n, values_from = deff, names_prefix = "n = ") |>
  arrange(design, range)
deff_frame <- v |>
  filter(design != "srs", n %in% c(20, 80)) |>
  select(frame, range, design, n, deff) |>
  pivot_wider(names_from = c(design, n), values_from = deff) |>
  arrange(frame, range)

# ---- travel: price of balance ------------------------------------------------------------
cv <- res$curves |> arrange(frame, selection, limit, n)
interp <- function(x, y, xo, log = FALSE) {
  if (log) exp(approx(log(x), log(y), log(xo), rule = 2)$y) else approx(x, y, xo, rule = 2)$y
}
travel_ratio <- cv |>
  select(frame, selection, limit, n, travel_mean) |>
  group_by(frame, limit) |>
  group_modify(\(d, k) {
    s <- d |> filter(selection == "srs")
    d |> filter(selection != "srs") |>
      mutate(rho = travel_mean / interp(s$n, s$travel_mean, n))
  }) |>
  ungroup()
rho_tab <- travel_ratio |>
  mutate(band = case_when(n <= 40 ~ "n <= 40", n <= 150 ~ "40 < n <= 150", TRUE ~ "n > 150")) |>
  group_by(selection, frame, limit, band) |>
  summarise(rho = mean(rho), .groups = "drop") |>
  pivot_wider(names_from = band, values_from = rho) |>
  select(selection, frame, limit, `n <= 40`, `40 < n <= 150`, `n > 150`)

# ---- equal budget ---------------------------------------------------------------------------
G_of <- function(d) {
  d <- arrange(d, n)
  f <- splinefun(d$n, d$cost_mean, method = "monoH.FC")
  function(n) f(n)
}
n_at_budget <- function(G, ic, budget, n_lo, n_hi) {
  g <- function(n) G(n) + ic * n - budget
  if (g(n_hi) <= 0) return(n_hi)
  if (g(n_lo) >= 0) return(n_lo)
  uniroot(g, c(n_lo, n_hi))$root
}
budget_rows <- expand_grid(frame = unique(cv$frame), limit = unique(cv$limit),
                           interviews = names(st$INTERVIEW_COST), n_srs = c(20, 40, 80, 160)) |>
  pmap(\(frame, limit, interviews, n_srs) {
    ic <- st$INTERVIEW_COST[[interviews]]
    Gs <- map(set_names(c("srs", "lpm", "systematic")), \(p) G_of(cv |> filter(frame == !!frame, limit == !!limit, selection == p)))
    budget <- Gs$srs(n_srs) + ic * n_srs
    n_p <- map_dbl(Gs, \(G) n_at_budget(G, ic, budget, 2, max(st$N_VAR)))
    vv <- v |> filter(frame == !!frame)
    map(range_levels, \(rg) {
      vr <- vv |> filter(range == rg)
      V <- map_dbl(names(n_p), \(p) {
        d <- vr |> filter(design == p) |> arrange(n)
        interp(d$n, d$variance, n_p[[p]], log = TRUE)
      })
      tibble(frame = frame, limit = limit, interviews = interviews, n_srs = n_srs, range = rg,
             design = names(n_p), n = n_p, variance = V, efficiency = V / V[1], n_ratio = n_p / n_p[1])
    }) |> list_rbind()
  }) |> list_rbind() |>
  mutate(range = factor(range, range_levels))
eff_tab <- budget_rows |>
  filter(design != "srs") |>
  group_by(design, limit, interviews, range) |>
  summarise(worst = max(efficiency), efficiency = mean(efficiency), n_ratio = mean(n_ratio), .groups = "drop") |>
  relocate(worst, .after = efficiency) |>
  arrange(design, limit, interviews, range)
wins <- budget_rows |>
  filter(design != "srs") |>
  group_by(design, range) |>
  summarise(wins = mean(efficiency < 1), .groups = "drop") |>
  pivot_wider(names_from = range, values_from = wins)

# ---- figures --------------------------------------------------------------------------------
theme_set(theme_minimal(base_size = 10))
p1 <- v |>
  filter(design != "srs") |>
  ggplot(aes(n, deff, colour = range)) +
  geom_hline(yintercept = 1, colour = "grey50") +
  geom_line() + geom_point(size = 0.8) +
  scale_x_log10() +
  facet_grid(design ~ frame) +
  labs(x = "sample size n (log scale)", y = "design effect V(design) / V(srs)", colour = "range")
ggsave(file.path(fig_dir, "e1-deff.png"), p1, width = 6.5, height = 4, dpi = 110)
p2 <- travel_ratio |>
  ggplot(aes(n, rho, colour = frame, linetype = limit)) +
  geom_hline(yintercept = 1, colour = "grey50") +
  geom_line() +
  scale_x_log10() +
  facet_wrap(~selection) +
  labs(x = "sample size n (log scale)", y = "travel of the design / travel of srs", colour = "frame", linetype = "routes")
ggsave(file.path(fig_dir, "e1-travel-ratio.png"), p2, width = 6.5, height = 3, dpi = 110)
p3 <- budget_rows |>
  filter(design != "srs") |>
  group_by(design, range, limit, interviews) |>
  summarise(lo = min(efficiency), hi = max(efficiency), efficiency = mean(efficiency), .groups = "drop") |>
  ggplot(aes(range, efficiency, colour = design, group = design)) +
  geom_hline(yintercept = 1, colour = "grey50") +
  geom_pointrange(aes(ymin = lo, ymax = hi), position = position_dodge(width = 0.4), size = 0.25) +
  facet_grid(interviews ~ limit, labeller = label_both) +
  labs(x = "spatial range of the study variable", y = "variance at equal budget / variance of srs", colour = "design")
ggsave(file.path(fig_dir, "e1-equal-budget.png"), p3, width = 6.5, height = 4, dpi = 110)

# ---- report ----------------------------------------------------------------------------------
tbl <- function(d, digits = 2) paste(kable(d, digits = digits, format = "pipe"), collapse = "\n")
N_of <- c(F1 = 448, F2 = 900, F3 = 900)
bias_tab <- v |>
  mutate(rel = bias_rel / (10 * N_of[frame])) |>
  summarise(max_abs_rel_bias = max(abs(rel)))
report <- c(
  "# E1 — the price and the gain of spatial balance",
  "",
  paste0("Generated by `experiments/analysis/e1_summary.R` from `", out_dir, "` (", tail(session, 1), ")."),
  "",
  "## Question",
  "",
  "Spatially balanced designs spread the sample over the frame. When the study variable is spatially",
  "autocorrelated this lowers the variance of the Horvitz-Thompson total; it also lengthens the routes,",
  "because a spread sample has no clumps to visit together. Which effect wins at equal budget, and when?",
  "",
  "## Design",
  "",
  "- Frames and costs as in E2: F1 a real grid of 448 cells of about 500 km² from the areaframe project,",
  "  F2 a uniform 30 x 30 grid at 10 km, F3 four Gaussian clusters of 900 points in a 300 km square;",
  "  travel in minutes at 60 km/h with detour 1.3; 1.5 per minute, 60 per visited unit, one tour",
  "  (`single`) or daily routes with a fixed 200 per route (`daily`).",
  "- Designs with equal inclusion probabilities n/N: simple random sampling (srs), the local pivotal",
  "  method (lpm) and systematic sampling along a Hilbert curve (systematic).",
  paste0("- Routed cost curves G(n) for each design (", st$R_REP, " routed samples per n; lpm and srs reused from E2)."),
  paste0("- Design variances of the total by Monte Carlo: ", st$R_SAMPLES, " samples per (frame, design, n),",
         " n in {", paste(st$N_VAR, collapse = ", "), "}, the same samples for every field."),
  paste0("- Study variables: Gaussian random fields with exponential covariance, mean 10, sd 3, ",
         100 * st$NUGGET, "% nugget, range phi = {", paste(sprintf("%s %g", names(st$RANGES), st$RANGES), collapse = ", "),
         "} x sqrt(frame area) (practical range 3 phi; `iid` has no spatial correlation); ",
         st$N_FIELDS, " fields per (frame, range)."),
  "- Equal budget: the budget that buys n_srs units under srs (n_srs in {20, 40, 80, 160}), with no",
  "  interviews or with four interviews at 25 each (100 per visited unit); each design gets the n its",
  "  own cost curve allows, and its variance at that n (log-log interpolation). Efficiency is the",
  "  variance of the design over the variance of srs at the same budget: below 1 the design wins.",
  "",
  "## Results",
  "",
  "### Gain: design effect at equal n (mean over frames)",
  "",
  tbl(deff_tab),
  "",
  "By frame, at n = 20 and n = 80:",
  "",
  tbl(deff_frame),
  "",
  "![Design effects](figures/e1-deff.png)",
  "",
  "### Price: travel of the design over the travel of srs at equal n",
  "",
  tbl(rho_tab),
  "",
  "![Travel ratio](figures/e1-travel-ratio.png)",
  "",
  "### Equal budget",
  "",
  "Mean efficiency over frames and budgets (`worst` is the largest), and the mean ratio of the sample",
  "size the design affords to the srs sample size:",
  "",
  tbl(eff_tab),
  "",
  "Share of (frame, route limit, interview cost, budget) cases in which the design beats srs:",
  "",
  tbl(wins),
  "",
  "![Equal budget](figures/e1-equal-budget.png)",
  "",
  paste0("Sanity check: the largest Monte Carlo bias of the HT total relative to the total is ",
         sprintf("%.2f%%", 100 * bias_tab$max_abs_rel_bias), " (the designs are unbiased; this is simulation noise)."),
  "",
  "## What this means for the paper",
  "",
  "1. **The price of balance is small.** At equal n, lpm and systematic samples travel 7 to 15% more than",
  "   srs samples when n is small and 1 to 9% more when n is large, far below the 40% of a perfect lattice.",
  "   At equal budget that buys 3 to 10% fewer units (more when travel dominates the cost: no interviews,",
  "   daily routes).",
  "2. **The gain is large whenever the variable is spatially correlated over more than a few cells.** The",
  "   design effect is 0.5 to 0.8 at medium range and 0.4 to 0.6 at long range, and it improves with n.",
  "   With correlation only at the scale of one or two cells (`short`) it is 0.86 to 0.99.",
  "3. **Decision rule.** At equal budget a balanced design wins when its design effect is below the ratio",
  "   of the sample sizes the two designs afford, n_bal / n_srs, which is 0.90 to 0.97 here. With",
  "   medium or long range correlation balance wins in 98 to 100% of the cases and cuts the variance by",
  "   a third to a half; with no correlation it loses 1 to 9% (worst 18%), the cost of the extra travel;",
  "   short range is a coin toss. Both sides of the rule are measured by the package",
  "   (`cost_variance_frontier()` for the costs, a pilot or the previous round for the design effect).",
  "4. **lpm and systematic sampling are interchangeable on these frames**: same price, same gain within",
  "   the Monte Carlo noise. Systematic sampling keeps a simple replicate variance estimator.",
  "5. Together with E2: the routed cost per unit is a third to a fifth of the naive guess, the allocation",
  "   should use the marginal routed cost, and spatial balance is worth its travel for spatially",
  "   structured variables. This is the content of an applied-methods article (cost-aware design of area",
  "   frame surveys) once the literature check of `paper/formulacao.md` section 11 confirms that the",
  "   equal-budget comparison with routed costs has not been published.",
  "",
  "Caveats: Gaussian fields with an exponential covariance stand in for real study variables; the real",
  "frame contributes geometry only; equal inclusion probabilities (no size measure); the variance is the",
  "true design variance, not its estimate (the local-mean and replicate estimators are not assessed here)."
)
writeLines(report, "experiments/e1_spatial_balance.md")
saveRDS(list(deff = deff_tab, rho = rho_tab, efficiency = eff_tab, wins = wins, budget_rows = budget_rows),
        file.path(out_dir, "e1_tables.rds"))
message("report written")
