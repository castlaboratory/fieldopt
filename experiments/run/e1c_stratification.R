# E1c — skewed variables: stratification and size measures from earlier land use
#
# Usage:  Rscript experiments/run/e1c_stratification.R [cores] [pilot]
#
# E1b found that population, households, urban and agriculture shares are so
# skewed across the 1 km cells of frame F4 that the 95% intervals cover 0.61
# to 0.86 under every equal-probability design. E1c tests the two standard
# remedies with auxiliary information available before the survey: the
# MapBiomas shares of 2018 (urban18, agri18, mosaic18), six years before the
# 2022-2024 targets.
#
#   srs, lpm           as in E1b (references)
#   strat_lpm          three strata from 2018 land use: urban (urban18 >= 0.10),
#                      farmed (agri18 + mosaic18 >= 0.10, not urban) and other;
#                      lpm within strata; allocation by Bethel's multivariate
#                      rule on the three 2018 shares (equal target CVs, equal
#                      cost), scaled to n
#   pps_lpm            lpm with inclusion probabilities proportional to
#                      size = 0.1 + urban18 + agri18 + mosaic18 (a cell with no
#                      2018 use keeps a tenth of the weight of a fully used one)
#
# Each design gets its routed cost curve (concentrating the sample in towns and
# farmed areas shortens the routes), its true design variance per variable,
# and the bias and t-interval coverage of design_variance().
suppressPackageStartupMessages({
  library(fieldopt)
  library(dplyr)
  library(tibble)
  library(purrr)
  library(tidyr)
})
args <- commandArgs(trailingOnly = TRUE)
cores <- if (length(args) >= 1) as.integer(args[1]) else 10L
pilot <- length(args) >= 2 && args[2] == "pilot"
out_dir <- if (pilot) "experiments/out/e1c_pilot" else "experiments/out/e1c"
e1b_dir <- "experiments/out/e1b"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(capture.output(sessionInfo()), paste("start", format(Sys.time()))),
           file.path(out_dir, "session.txt"))
t0 <- Sys.time()

R_REP <- if (pilot) 3L else 10L
ITER <- 60L
SPEED <- 60
PER_TRAVEL <- 1.5
PER_UNIT <- 60
PER_ROUTE_DAY <- 200
DAY <- 480
R_SAMPLES <- if (pilot) 100L else 1000L
N_VAR <- c(20, 40, 80, 160)
DESIGNS <- c("srs", "lpm", "strat_lpm", "pps_lpm")
VARS <- c("pop", "households", "agri", "pasture", "mosaic", "native", "urban", "elev")
DEPOT <- c(lat = -8.2833, lon = -35.9761)

cells <- arrow::read_parquet("experiments/data/f4_ipojuca_cells.parquet") |>
  as_tibble() |>
  filter(if_all(all_of(c(VARS, "urban18", "agri18", "mosaic18")), \(v) !is.na(v))) |>
  mutate(
    stratum = case_when(urban18 >= 0.10 ~ "urban", agri18 + mosaic18 >= 0.10 ~ "farmed", TRUE ~ "other"),
    size = 0.1 + urban18 + agri18 + mosaic18
  )
N <- nrow(cells)
message("F4: ", N, " cells; strata: ", paste(names(table(cells$stratum)), table(cells$stratum), collapse = ", "))
frame <- bind_rows(tibble(unit = "depot", lat = DEPOT[["lat"]], lon = DEPOT[["lon"]]),
                   cells |> select(unit, lat, lon, stratum, size))
matrix <- travel_matrix(frame |> select(unit, lat, lon), method = "haversine", detour = 1.3, speed = SPEED)
day_limit <- {
  m <- unclass(matrix)
  d <- which(rownames(m) == "depot")
  max(DAY, 2.2 * max(m[d, -d]))
}
cost_model_of <- function(limit) {
  field_cost_model(per_travel = PER_TRAVEL, per_unit = PER_UNIT, per_interview = 0, interviews_per_unit = 1,
                   per_route = if (limit == "daily") PER_ROUTE_DAY else 0, currency = "cost")
}

# allocation shares of the strata: Bethel on the 2018 shares, equal CV targets
strata_tab <- cells |>
  group_by(stratum) |>
  summarise(size = n(), cost = 1, sd_urban = sd(urban18), sd_agri = sd(agri18), sd_mosaic = sd(mosaic18), .groups = "drop")
bethel <- multivariate_allocation(strata_tab, sd = c("sd_urban", "sd_agri", "sd_mosaic"),
  target_cv = c(0.1, 0.1, 0.1), totals = c(sum(cells$urban18), sum(cells$agri18), sum(cells$mosaic18)))
shares <- setNames(bethel$n / sum(bethel$n), bethel$stratum)
Nh <- setNames(strata_tab$size, strata_tab$stratum)
alloc_of <- function(n) {
  a <- pmax(round(n * shares), 2)
  a <- pmin(a, Nh[names(a)])
  a[which.max(a)] <- a[which.max(a)] + (n - sum(a))   # keep the total at n
  a
}
message("allocation shares: ", paste(names(shares), round(shares, 3), collapse = ", "))

n_grid <- c(10, 15, 20, 30, 40, 50, 60, 80, 100, 125, 150, 200, 250, 300, 350, 400, 450)
if (pilot) n_grid <- n_grid[seq(1, length(n_grid), by = 4)]
n_grid <- n_grid[n_grid >= 15]   # strata need at least 2 units each

# ---- stage 1: cost curves -----------------------------------------------------------
curve_cells <- expand_grid(design = DESIGNS, limit = c("single", "daily"))
run_frontier <- function(design, limit) {
  file <- file.path(out_dir, sprintf("frontier_F4_%s_%s.rds", design, limit))
  if (file.exists(file)) return(readRDS(file))
  if (design %in% c("srs", "lpm") && !pilot) {
    old <- file.path(e1b_dir, sprintf("frontier_F4_%s_%s.rds", design, limit))
    if (file.exists(old)) {
      res <- readRDS(old) |> rename(design = selection)
      saveRDS(res, file)
      return(res)
    }
  }
  args <- list(frame, "depot", cost_model_of(limit), matrix = matrix,
               max_length = if (limit == "daily") day_limit else Inf, n_rep = R_REP, iterations = ITER, seed = 11)
  f <- switch(design,
    srs = do.call(cost_variance_frontier, c(args, list(n_grid = n_grid, selection = "srs"))),
    lpm = do.call(cost_variance_frontier, c(args, list(n_grid = n_grid, selection = "lpm"))),
    strat_lpm = do.call(cost_variance_frontier, c(args, list(n_grid = map(n_grid, alloc_of), strata = "stratum", selection = "lpm"))),
    pps_lpm = do.call(cost_variance_frontier, c(args, list(n_grid = n_grid, size = "size", selection = "lpm")))
  )
  res <- tibble(frame = "F4", design = design, limit = limit, N = N) |>
    bind_cols(as_tibble(unclass(f))[, c("n", "cost_mean", "cost_sd", "cost_per_unit", "travel_mean", "routes_mean")])
  saveRDS(res, file)
  res
}
curves <- parallel::mclapply(seq_len(nrow(curve_cells)),
  \(i) run_frontier(curve_cells$design[i], curve_cells$limit[i]), mc.cores = cores) |> list_rbind()
message("stage 1 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

# ---- stage 2: samples, true variances and estimates ---------------------------------
units <- cells |> select(unit, lat, lon, stratum, size, all_of(VARS))
truth <- tibble(y = VARS, true_total = map_dbl(VARS, \(v) sum(units[[v]])))
draw <- function(design, n, seed) {
  switch(design,
    srs = select_units(units, n = n, coords = c("lat", "lon"), method = "srs", seed = seed),
    lpm = select_units(units, n = n, coords = c("lat", "lon"), method = "lpm", seed = seed),
    strat_lpm = select_units(units, n = alloc_of(n), coords = c("lat", "lon"), strata = "stratum", method = "lpm", seed = seed),
    pps_lpm = select_units(units, n = n, size = "size", coords = c("lat", "lon"), method = "lpm", seed = seed)
  )
}
sample_cells <- expand_grid(design = DESIGNS, n = N_VAR)
run_samples <- function(design, n) {
  file <- file.path(out_dir, sprintf("est_F4_%s_%d.rds", design, n))
  if (file.exists(file)) return(readRDS(file))
  res <- map(seq_len(R_SAMPLES), \(r) {
    s <- draw(design, n, 600000 + r)
    map(VARS, \(v) {
      dv <- design_variance(s, v)
      tibble(r = r, y = v, total = dv$total, variance = dv$variance, method = dv$variance_method, df = dv$df)
    }) |> list_rbind()
  }) |> list_rbind() |>
    mutate(frame = "F4", design = design, n = n, .before = 1)
  saveRDS(res, file)
  res
}
est <- parallel::mclapply(seq_len(nrow(sample_cells)),
  \(k) run_samples(sample_cells$design[k], sample_cells$n[k]), mc.cores = cores) |> list_rbind()
message("stage 2 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

saveRDS(list(curves = curves, est = est, truth = truth, N = N, strata = strata_tab, shares = shares,
             skew = tibble(y = VARS, cv = map_dbl(VARS, \(v) sd(units[[v]]) / mean(units[[v]])),
                           cor_size = map_dbl(VARS, \(v) cor(units[[v]], units$size))),
             settings = list(R_REP = R_REP, ITER = ITER, R_SAMPLES = R_SAMPLES, N_VAR = N_VAR, DESIGNS = DESIGNS,
                             VARS = VARS, INTERVIEW_COST = c(none = 0, four = 100), day_limit = day_limit)),
        file.path(out_dir, "e1c_results.rds"))
cat(paste("end", format(Sys.time()), "elapsed", round(difftime(Sys.time(), t0, units = "mins"), 1), "min"),
    file = file.path(out_dir, "session.txt"), append = TRUE, sep = "\n")
message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
