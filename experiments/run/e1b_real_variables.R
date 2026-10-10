# E1b — price and gain of spatial balance with real study variables
#
# Usage:  Rscript experiments/run/e1b_real_variables.R [cores] [pilot]
#
# E1 used simulated Gaussian fields. E1b repeats the comparison on frame F4,
# the 1 km cells of the IBGE 2022 statistical grid in the Vale do Ipojuca
# microregion (Pernambuco), with the real per-cell variables built by
# experiments/data/build_f4_ipojuca.R: population and households (Censo
# 2022), shares of agriculture, pasture, mosaic of uses, native vegetation and
# urban area (MapBiomas Collection 10, 2024) and altitude (Copernicus DEM).
# Costs as in E1/E2; travel by haversine distance x 1.3 at 60 km/h from a
# depot in Caruaru.
#
# Stage 1: routed cost curves G(n) of srs, lpm and systematic (one tour and
#          daily routes).
# Stage 2: R samples per (design, n), stored as indices; true design variance
#          of each variable's HT total and, per sample, the estimate of
#          design_variance() (bias and coverage, as E3).
# Stage 3: Moran's I of each variable (8 nearest neighbours), to place the
#          variables on the spatial-range scale of E1.
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
out_dir <- if (pilot) "experiments/out/e1b_pilot" else "experiments/out/e1b"
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
DESIGNS <- tribble(
  ~design,         ~method,      ~replicates,
  "srs",           "srs",        1L,
  "lpm",           "lpm",        1L,
  "systematic",    "systematic", 1L,
  "systematic_r4", "systematic", 4L
)
VARS <- c("pop", "households", "agri", "pasture", "mosaic", "native", "urban", "elev")
DEPOT <- c(lat = -8.2833, lon = -35.9761)   # Caruaru

cells <- arrow::read_parquet("experiments/data/f4_ipojuca_cells.parquet") |>
  as_tibble() |>
  filter(if_all(all_of(VARS), \(v) !is.na(v)))
frame <- bind_rows(tibble(unit = "depot", lat = DEPOT[["lat"]], lon = DEPOT[["lon"]]),
                   cells |> select(unit, lat, lon))
N <- nrow(cells)
area <- N   # km2: one cell per km2
message("F4: ", N, " cells")
matrix <- travel_matrix(frame, method = "haversine", detour = 1.3, speed = SPEED)
day_limit <- {
  m <- unclass(matrix)
  d <- which(rownames(m) == "depot")
  max(DAY, 2.2 * max(m[d, -d]))
}
cost_model_of <- function(limit) {
  field_cost_model(per_travel = PER_TRAVEL, per_unit = PER_UNIT, per_interview = 0, interviews_per_unit = 1,
                   per_route = if (limit == "daily") PER_ROUTE_DAY else 0, currency = "cost")
}
n_grid <- c(10, 15, 20, 30, 40, 50, 60, 80, 100, 125, 150, 200, 250, 300, 350, 400, 450)
if (pilot) n_grid <- n_grid[seq(1, length(n_grid), by = 4)]

# ---- stage 1: cost curves -----------------------------------------------------------
curve_cells <- expand_grid(selection = c("srs", "lpm", "systematic"), limit = c("single", "daily"))
run_frontier <- function(selection, limit) {
  file <- file.path(out_dir, sprintf("frontier_F4_%s_%s.rds", selection, limit))
  if (file.exists(file)) return(readRDS(file))
  f <- cost_variance_frontier(frame, "depot", cost_model_of(limit),
    n_grid = n_grid, selection = selection, matrix = matrix,
    max_length = if (limit == "daily") day_limit else Inf, n_rep = R_REP, iterations = ITER, seed = 11
  )
  res <- tibble(frame = "F4", selection = selection, limit = limit, N = N) |>
    bind_cols(as_tibble(unclass(f))[, c("n", "cost_mean", "cost_sd", "cost_per_unit", "travel_mean", "routes_mean")])
  saveRDS(res, file)
  res
}
curves <- parallel::mclapply(seq_len(nrow(curve_cells)),
  \(i) run_frontier(curve_cells$selection[i], curve_cells$limit[i]), mc.cores = cores) |> list_rbind()
message("stage 1 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

# ---- stage 2: samples, true variances and estimates ---------------------------------
units <- cells |> select(unit, lat, lon, all_of(VARS))
truth <- tibble(y = VARS, true_total = map_dbl(VARS, \(v) sum(units[[v]])))
sample_cells <- expand_grid(design = DESIGNS$design, n = N_VAR)
run_samples <- function(design, n) {
  file <- file.path(out_dir, sprintf("est_F4_%s_%d.rds", design, n))
  if (file.exists(file)) return(readRDS(file))
  d <- DESIGNS[DESIGNS$design == design, ]
  res <- map(seq_len(R_SAMPLES), \(r) {
    s <- select_units(units, n = n, coords = c("lat", "lon"), method = d$method,
                      replicates = d$replicates, seed = 400000 + r)
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

# ---- stage 3: spatial autocorrelation of the variables --------------------------------
lat0 <- mean(units$lat) * pi / 180
xy <- cbind(units$lon * 111.32 * cos(lat0), units$lat * 110.57)
knn <- function(xy, k) {
  t(vapply(seq_len(nrow(xy)), \(i) {
    d <- (xy[, 1] - xy[i, 1])^2 + (xy[, 2] - xy[i, 2])^2
    d[i] <- Inf
    order(d)[seq_len(k)]
  }, integer(k)))
}
nb <- knn(xy, 8)
moran <- map_dbl(VARS, \(v) {
  z <- units[[v]] - mean(units[[v]])
  lag <- rowMeans(matrix(z[nb], nrow = nrow(nb)))
  sum(z * lag) / sum(z^2)
})
autocorr <- tibble(y = VARS, moran_i = moran, cv = map_dbl(VARS, \(v) sd(units[[v]]) / mean(units[[v]])))

saveRDS(list(curves = curves, est = est, truth = truth, autocorr = autocorr, N = N, area = area,
             settings = list(R_REP = R_REP, ITER = ITER, SPEED = SPEED, PER_TRAVEL = PER_TRAVEL,
                             PER_UNIT = PER_UNIT, PER_ROUTE_DAY = PER_ROUTE_DAY, DAY = DAY, day_limit = day_limit,
                             R_SAMPLES = R_SAMPLES, N_VAR = N_VAR, DESIGNS = DESIGNS, VARS = VARS,
                             INTERVIEW_COST = c(none = 0, four = 100))),
        file.path(out_dir, "e1b_results.rds"))
cat(paste("end", format(Sys.time()), "elapsed", round(difftime(Sys.time(), t0, units = "mins"), 1), "min"),
    file = file.path(out_dir, "session.txt"), append = TRUE, sep = "\n")
message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
