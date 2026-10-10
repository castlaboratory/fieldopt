# E2 — summary: tables, figures and the report experiments/e2_allocation_cost.md
#
# Usage:  Rscript experiments/analysis/e2_summary.R [out_dir] [report]
#         (defaults: experiments/out/e2 and experiments/e2_allocation_cost.md)
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
})
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else "experiments/out/e2"
report <- if (length(args) >= 2) args[2] else "experiments/e2_allocation_cost.md"
fig_dir <- "experiments/figures"
dir.create(fig_dir, showWarnings = FALSE)
res <- readRDS(file.path(out_dir, "e2_results.rds"))
st <- res$settings
curves <- res$curves
proc_levels <- c("A", "B", "B'", "C")
pal <- c(A = "#eb6834", B = "#2a78d6", `B'` = "#1baf7a", C = "#eda100") # validated (dataviz skill)
theme_set(theme_minimal(base_size = 11) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "#e5e5e5", linewidth = 0.3),
  strip.text = element_text(face = "bold"), legend.position = "bottom"
))
frame_labels <- c(F1 = "F1 real grid (449 cells)", F2 = "F2 uniform grid (900)", F3 = "F3 clustered (900)")
pct <- function(x) sprintf("%+.1f%%", 100 * x)
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d)
md_table <- function(df) paste(knitr::kable(df, format = "pipe"), collapse = "\n")

# ---- relative errors against the oracle C -------------------------------------------
rel_to_C <- function(d, size_col) {
  d |>
    group_by(across(any_of(c("frame", "selection", "limit", "s2_ratio", "constraint")))) |>
    mutate(
      n_C = .data[[size_col]][procedure == "C"], cost_C = cost[procedure == "C"], var_C = variance[procedure == "C"],
      rel_n = .data[[size_col]] / n_C - 1, rel_cost = cost / cost_C - 1, rel_var = variance / var_C - 1,
      budget_gap = if_else(constraint == "budget", cost / target - 1, NA_real_)
    ) |>
    ungroup() |>
    filter(procedure != "C") |>
    mutate(procedure = factor(procedure, proc_levels))
}
ts <- rel_to_C(res$twostage, "n")
du <- rel_to_C(res$dual, "n_a")

summarise_errors <- function(d, ...) {
  d |>
    group_by(procedure, ...) |>
    summarise(
      `n (target)` = mean(rel_n[constraint == "target_variance"]),
      `cost (target)` = mean(rel_cost[constraint == "target_variance"]),
      `n (budget)` = mean(rel_n[constraint == "budget"]),
      `variance (budget)` = mean(rel_var[constraint == "budget"]),
      `spend vs budget` = mean(budget_gap[constraint == "budget"]),
      .groups = "drop"
    ) |>
    mutate(across(where(is.numeric), pct))
}
ts_by_frame <- summarise_errors(ts, frame, selection, limit) |> arrange(frame, selection, limit, procedure)
ts_by_ratio <- summarise_errors(ts |> mutate(s2_ratio = sprintf("S2/S1 = %g", s2_ratio)), s2_ratio) |> arrange(s2_ratio, procedure)
ts_overall <- summarise_errors(ts)
du_by_frame <- summarise_errors(du, frame, selection, limit) |> arrange(frame, selection, limit, procedure)
du_overall <- summarise_errors(du)
worst <- bind_rows(two_stage = ts, dual_frame = du, .id = "problem") |>
  group_by(problem, procedure) |>
  summarise(
    `max cost (target)` = max(rel_cost[constraint == "target_variance"]),
    `max variance (budget)` = max(rel_var[constraint == "budget"]),
    `min spend vs budget` = min(budget_gap[constraint == "budget"]),
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), pct))

# ---- the cost curves: average and marginal cost, naive c1 --------------------------------
naive <- res$twostage |>
  filter(procedure == "A", constraint == "target_variance") |>
  distinct(frame, c1_naive = c1_used)
curve_tbl <- curves |>
  group_by(frame, selection, limit) |>
  arrange(n, .by_group = TRUE) |>
  mutate(
    c1_avg = cost_mean / n,
    c1_marginal = splinefun(n, cost_mean, method = "monoH.FC")(n, deriv = 1)
  ) |>
  ungroup() |>
  left_join(naive, by = "frame")
c1_at_oracle <- res$twostage |>
  filter(procedure == "C", constraint == "target_variance") |>
  left_join(naive, by = "frame") |>
  group_by(frame, selection, limit) |>
  summarise(n_C = round(mean(n)), `c1 routed / c1 naive` = mean(c1_used / c1_naive), .groups = "drop") |>
  mutate(`c1 routed / c1 naive` = fmt(`c1 routed / c1 naive`))

# ---- travel law: exponent and the BHH constant --------------------------------------------
travel_tbl <- curves |>
  mutate(km = travel_mean * st$SPEED / 60 / 1.3, area = res$frame_area[frame], x = sqrt(n * area))
exponent <- travel_tbl |>
  filter(n >= 20) |>
  group_by(frame, selection, limit) |>
  summarise(
    `exponent b` = coef(lm(log(travel_mean) ~ log(n)))[2],
    `beta (km / sqrt(nA))` = if (limit[1] == "single") coef(lm(km ~ 0 + x))[1] else NA_real_,
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), \(v) fmt(v, 3)))
balance_ratio <- travel_tbl |>
  select(frame, selection, limit, n, travel_mean) |>
  pivot_wider(names_from = selection, values_from = travel_mean) |>
  mutate(ratio = lpm / srs) |>
  group_by(frame, limit) |>
  summarise(
    `n range` = paste(min(n), max(n), sep = "-"), `travel lpm / srs (mean)` = fmt(mean(ratio)),
    `at n <= 60` = fmt(mean(ratio[n <= 60])), `at n >= 150` = fmt(mean(ratio[n >= 150])), .groups = "drop"
  )

# ---- figures ------------------------------------------------------------------------------
p1 <- curve_tbl |>
  filter(n <= 300) |>
  select(frame, selection, limit, n, average = c1_avg, marginal = c1_marginal, c1_naive) |>
  pivot_longer(c(average, marginal), names_to = "cost", values_to = "c1") |>
  ggplot(aes(n, c1, colour = selection, linetype = cost)) +
  geom_hline(aes(yintercept = c1_naive), colour = "#9a9a9a", linewidth = 0.4) +
  geom_line(linewidth = 0.7) +
  facet_grid(limit ~ frame, labeller = labeller(frame = frame_labels, limit = c(single = "single tour", daily = "daily routes"))) +
  scale_colour_manual(values = c(lpm = "#2a78d6", srs = "#eb6834")) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(
    x = "primary units in the sample, n", y = "cost per primary unit (travel, visits, days)",
    colour = "selection", linetype = NULL,
    title = "Routed cost per primary unit falls with n; the constant c1 (grey) sits far above it"
  )
ggsave(file.path(fig_dir, "e2-cost-curves.png"), p1, width = 9, height = 5.2, dpi = 110)

err_long <- bind_rows(`two-stage` = ts, `dual frame` = du, .id = "problem") |>
  transmute(problem, frame, selection, limit, procedure,
    `cost at target variance` = if_else(constraint == "target_variance", rel_cost, NA_real_),
    `variance at budget` = if_else(constraint == "budget", rel_var, NA_real_)
  ) |>
  pivot_longer(c(`cost at target variance`, `variance at budget`), names_to = "metric", values_to = "rel") |>
  filter(!is.na(rel)) |>
  mutate(design = paste(selection, limit))
p2 <- err_long |>
  ggplot(aes(rel, design, colour = procedure, shape = procedure)) +
  geom_vline(xintercept = 0, colour = "#9a9a9a", linewidth = 0.4) +
  stat_summary(fun = mean, geom = "point", size = 2.6, position = position_dodge(width = 0.5)) +
  stat_summary(fun.min = min, fun.max = max, geom = "linerange", linewidth = 0.5, position = position_dodge(width = 0.5)) +
  facet_grid(problem ~ metric, scales = "free_x") +
  scale_x_continuous(labels = scales::percent) +
  scale_colour_manual(values = pal) +
  labs(
    x = "relative to the oracle C (mean over scenarios, range)", y = NULL,
    title = "Excess cost (at a target variance) and excess variance (at a budget) against the oracle"
  )
ggsave(file.path(fig_dir, "e2-errors.png"), p2, width = 9, height = 5.5, dpi = 110)

p3 <- travel_tbl |>
  filter(limit == "single") |>
  ggplot(aes(x, km, colour = selection)) +
  geom_abline(slope = 0.7124, intercept = 0, colour = "#9a9a9a", linetype = "dashed", linewidth = 0.4) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.6) +
  facet_wrap(~frame, scales = "free", labeller = labeller(frame = frame_labels)) +
  scale_colour_manual(values = c(lpm = "#2a78d6", srs = "#eb6834")) +
  labs(
    x = "sqrt(n x frame area)  [km]", y = "tour length  [straight-line km]",
    title = "Tour length against the Beardwood-Halton-Hammersley scale (dashed: 0.7124 sqrt(nA))"
  )
ggsave(file.path(fig_dir, "e2-travel-law.png"), p3, width = 9, height = 3.6, dpi = 110)

# ---- report ------------------------------------------------------------------------------
runtime <- readLines(file.path(out_dir, "session.txt")) |> grep(pattern = "^end", value = TRUE)
r_ver <- readLines(file.path(out_dir, "session.txt"))[1]
n_scen <- list(curves = n_distinct(paste(curves$frame, curves$selection, curves$limit)),
               two_stage = nrow(res$twostage) / 8, dual = nrow(res$dual) / 8)
txt <- c(
  "# E2 — allocation with a constant per-unit cost versus the routed cost",
  "",
  sprintf("Generated by `experiments/analysis/e2_summary.R` from `%s` (%s; %s).", out_dir, r_ver, runtime),
  "",
  "## Question",
  "",
  "Classical allocation treats the cost of a primary unit as a constant c1. In a field survey the",
  "cost of visiting the sampled units is the solution of a routing problem: it depends on how many",
  "units are drawn and how spread out they are, and the cost per unit falls with the sample size.",
  "How wrong are the classical allocations, and does the package's fixed-point loop fix them?",
  "",
  "## Design",
  "",
  sprintf("- Frames: %s; %s; %s.", frame_labels[1], frame_labels[2], frame_labels[3]),
  "  F1 is a grid of 500 km² cells from the areaframe project with the depot at the cell nearest the",
  "  main town; F2 a 30 x 30 grid at 10 km spacing with the depot at the centre; F3 four Gaussian",
  "  clusters inside a 300 km square with the depot in a corner. Travel in minutes: haversine (F1) or",
  sprintf("  euclidean (F2, F3) distance x detour 1.3 at %d km/h.", st$SPEED),
  "- Selection: local pivotal method (lpm, spatially balanced) or simple random sampling (srs).",
  sprintf("- Route limits: one tour (`single`) or routes of at most a day of travel (`daily`: %d min,",  st$DAY),
  sprintf("  raised to 2.2 x the farthest one-way trip when a cell is otherwise unreachable: %s) with a",
          paste(sprintf("%s %d min", names(res$limits), round(res$limits)), collapse = ", ")),
  sprintf("  fixed cost of %d per route.", st$PER_ROUTE_DAY),
  sprintf("- Cost model: %.1f per minute of travel, %d per visited unit, %d per interview (c2).", st$PER_TRAVEL, st$PER_UNIT, st$PER_INTERVIEW),
  sprintf("- Routed cost curve T(n): `cost_variance_frontier()` on a grid of n with %d replicate samples per n and", st$R_REP),
  sprintf("  %d HGS offspring per routing; interpolated by a monotone spline. Every procedure is evaluated with", st$ITER),
  "  the same curve, so the comparison is about the allocation rule, not about routing noise.",
  sprintf("- Two-stage (Cochran): M = %d secondary units per primary unit, S1² = %d, S2²/S1² in {%s};", st$M_SECONDARY, st$S1, paste(st$S2_RATIOS, collapse = ", ")),
  "  the target variance is the one reached by n = N/5 primary units with m = 5.",
  sprintf("- Dual frame (Hartley): domains a / ab / b of sizes N - 0.15N / 0.15N / 30 with means 6 / 30 / 45 and sds 5 / 20 / 35, list cost %d per unit, target CV %.2f; the area unit costs one interview on top of the routed cost.", st$COST_B, st$TARGET_CV_DUAL),
  "- Constraints: a target variance (compare the realised cost) and a budget equal to the oracle's cost",
  "  at that target (compare the realised variance and the real spend against the budget).",
  "",
  "Procedures:",
  "",
  "- **A, linear**: the classical allocation with the package's default constant c1 = per-unit cost +",
  "  per-minute cost x median one-way trip from the depot (`c1_start` of `two_stage_design()`).",
  "- **B, routed loop**: `two_stage_design()` / `dual_frame_design()`, the fixed-point iteration that",
  "  replaces c1 by the average routed cost T(n)/n at the current n.",
  "- **B', marginal loop**: the same iteration with the marginal cost T'(n) (finite differences on the",
  "  interpolated curve). Under a budget the marginal rule fixes the split (m, or theta and n_b/n_a) and",
  "  the level comes from the true cost curve.",
  "- **C, oracle**: exhaustive search over (n, m) or (n_a, n_b, theta) with the true routed cost curve.",
  "",
  sprintf("Scenarios: %d cost curves, %d two-stage and %d dual-frame scenarios, each with the two constraints.", n_scen$curves, n_scen$two_stage, n_scen$dual),
  "",
  "## Results",
  "",
  "### Two-stage allocation, errors relative to the oracle (mean over S2²/S1² ratios)",
  "",
  md_table(ts_by_frame),
  "",
  "By variance structure (mean over frames, selections and limits):",
  "",
  md_table(ts_by_ratio),
  "",
  "Overall:",
  "",
  md_table(ts_overall),
  "",
  "### Dual-frame allocation, errors relative to the oracle",
  "",
  md_table(du_by_frame),
  "",
  "Overall:",
  "",
  md_table(du_overall),
  "",
  "### Worst cases",
  "",
  md_table(worst),
  "",
  "`spend vs budget` is the real cost of the design relative to the budget the procedure believed it was",
  "spending: a negative value means the survey came in under budget because the assumed cost per unit was",
  "too high, with the variance that goes with the smaller sample.",
  "",
  "![Cost per primary unit against n](figures/e2-cost-curves.png)",
  "",
  "![Errors against the oracle](figures/e2-errors.png)",
  "",
  "### Side results",
  "",
  "Routed cost per unit at the oracle's n, relative to the constant c1 used by A:",
  "",
  md_table(c1_at_oracle),
  "",
  "Travel law. Exponent b of log travel = a + b log n (n >= 20) and, for single tours, the constant beta of",
  "travel = beta sqrt(n A) in straight-line km (Beardwood-Halton-Hammersley: 0.7124 for uniform random",
  "points, about 1 for a regular lattice). A is the frame area (sum of the cells for F1, the square for F2,",
  "the bounding box for F3).",
  "",
  md_table(exponent),
  "",
  "Spatial balance and travel: ratio of the routed travel of lpm to srs samples at equal n.",
  "",
  md_table(balance_ratio),
  "",
  "![Travel law](figures/e2-travel-law.png)",
  "",
  "## What this means for the paper",
  "",
  "1. **The constant-cost allocation is wrong by a wide margin.** The default c1 (median trip from the",
  "   depot) is 2.5 to 5 times the routed cost per unit at the optimum, because a tour shares the travel",
  "   among the units it visits. At a target variance the classical two-stage design costs 7 to 18%",
  "   more than necessary (dual frame: 2 to 12%); under a budget it takes 50 to 75% fewer primary units",
  "   than it could afford, comes in 25 to 65% under budget and delivers 60 to 350% more variance. The",
  "   error grows with the clustering of the frame (F3) and with S2²/S1².",
  "2. **The fixed-point loop on the average routed cost (the package's `two_stage_design()` and",
  "   `dual_frame_design()`) removes most of it** but keeps a bias of the predicted sign: with T(n)",
  "   concave the average cost exceeds the marginal cost, so the loop takes 3 to 12% too few primary",
  "   units; the loss is small at a target variance (0 to 3% extra cost) and under a budget (0 to 10%",
  "   extra variance, mostly below 3%).",
  "3. **The marginal-cost loop closes the gap**: excess cost at most 0.2% (two-stage) and 1.1% (dual",
  "   frame), excess variance at most 2 to 4%. Cochran's m* = sqrt(c1 S2² / (c2 S1²)) holds with c1",
  "   replaced by the marginal routed cost G'(n), and under a budget the level of n must come from the",
  "   true cost curve. This is Hansen, Hurwitz and Madow's (1953, Vol. II, section 6.11) optimum for a",
  "   cost with a sqrt(n) travel term (see paper/literature.md); what is new is measuring G(n) by routing.",
  "4. **The travel law is Beardwood-Halton-Hammersley in every frame**, also with daily routes: the",
  "   exponent of n is 0.43 to 0.51 and, for single tours, beta is 0.95 on the real grid and 0.83 to 0.88",
  "   on the uniform grid (above the 0.71 of random points because the depot sits on the tour and the",
  "   samples are regular); on the clustered frame beta falls to 0.6 only because the bounding box",
  "   overstates the occupied area. So G(n) = a n + beta sqrt(n A) + c is a usable closed form for the",
  "   formulation, with G'(n) = a + beta sqrt(A) / (2 sqrt(n)).",
  "5. **Spatial balance is cheap in travel**: lpm tours are 6 to 9% longer than srs tours on average,",
  "   11% at n <= 60 and 1 to 6% at n >= 150. The variance gain of spatial balance (not measured here,",
  "   E1) has to be weighed against this, but the price is far below the 40% that a perfect lattice",
  "   would suggest.",
  "",
  "Caveats: planning values are the truth here (no sampling of y); the real frame is one grid of large",
  "cells; the dual-frame scenarios have a small area sample (n_a about 26 to 39) because the list frame",
  "is cheap, so their relative errors are coarser; the marginal loop did not converge in a few scenarios",
  "(it cycled between two n) and was stopped at the last iterate."
)
writeLines(txt, report)
cat("wrote", report, "and", length(list.files(fig_dir, pattern = "^e2-")), "figures\n")
