# E1 — the price and the gain of spatial balance
#
# Usage:  Rscript experiments/run/e1_spatial_balance.R [cores] [pilot]
#
# Spatially balanced designs (local pivotal method, systematic sampling along a
# Hilbert curve) reduce the variance of the Horvitz-Thompson total when the
# study variable is spatially autocorrelated, and lengthen the routes because
# the sample is spread out. E1 measures both on the frames of E2 and compares
# the designs at equal budget.
#
# Stage 1 tabulates the routed cost curve G(n) of the systematic design (the
#   lpm and srs curves are reused from experiments/out/e2 when present).
# Stage 2 draws R samples per (frame, design, n) once and stores the inclusion
#   indicators; the design variance of the total of any field is then the
#   variance over those samples (all designs have equal inclusion probabilities
#   n/N, so the HT total is N/n times the sample sum).
# Stage 3 simulates Gaussian random fields with exponential covariance at
#   several ranges on each frame and computes the variances.
# Every unit of work is one rds in experiments/out/e1/; the script resumes.
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
out_dir <- if (pilot) "experiments/out/e1_pilot" else "experiments/out/e1"
e2_dir <- "experiments/out/e2"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(capture.output(sessionInfo()), paste("start", format(Sys.time()))),
           file.path(out_dir, "session.txt"))
t0 <- Sys.time()

# ---- settings (cost settings as in E2) -------------------------------------------
R_REP <- if (pilot) 3L else 10L        # routed replicates per sample size (cost curves)
ITER <- 60L
SPEED <- 60
PER_TRAVEL <- 1.5
PER_UNIT <- 60
PER_ROUTE_DAY <- 200
DAY <- 480
N_MAX <- 450
R_SAMPLES <- if (pilot) 100L else 1000L  # samples per (frame, design, n) for the variances
N_VAR <- c(10, 20, 40, 80, 160)
DESIGNS <- c("srs", "lpm", "systematic")
RANGES <- c(iid = 0, short = 0.02, medium = 0.1, long = 0.3)   # exponential range / sqrt(area)
NUGGET <- 0.2                           # share of the variance that is not spatial
N_FIELDS <- if (pilot) 4L else 20L      # field realisations per (frame, range)
INTERVIEW_COST <- c(none = 0, four = 100)   # extra cost per visited unit (interviews)

# ---- frames (identical to E2) ------------------------------------------------------
make_frames <- function() {
  f1 <- read_areaframe("~/Github/areaframe/cells.parquet") |>
    select(unit, lat, lon)
  i <- which.min((f1$lon + 60.67)^2 + (f1$lat - 2.82)^2)
  f1 <- bind_rows(tibble(unit = "depot", lat = f1$lat[i], lon = f1$lon[i]), f1[-i, ])
  set.seed(2)
  g <- expand.grid(x = seq(5, 295, by = 10), y = seq(5, 295, by = 10))
  f2 <- bind_rows(tibble(unit = "depot", x = 150, y = 150),
                  tibble(unit = paste0("g", seq_len(nrow(g))), x = g$x, y = g$y))
  centres <- tibble(cx = c(60, 220, 240, 90), cy = c(70, 60, 230, 240), n = c(300, 200, 250, 150))
  cl <- pmap(centres, \(cx, cy, n) tibble(x = cx + rnorm(n, sd = 25), y = cy + rnorm(n, sd = 25))) |>
    list_rbind() |>
    mutate(across(c(x, y), \(v) pmin(pmax(v, 0), 300)))
  f3 <- bind_rows(tibble(unit = "depot", x = 30, y = 30),
                  tibble(unit = paste0("k", seq_len(nrow(cl))), x = cl$x, y = cl$y))
  list(
    F1 = list(frame = f1, method = "haversine", detour = 1.3, coords = c("lat", "lon")),
    F2 = list(frame = f2, method = "euclidean", detour = 1.3, coords = c("x", "y")),
    F3 = list(frame = f3, method = "euclidean", detour = 1.3, coords = c("x", "y"))
  )
}
frames <- make_frames()
frame_area <- c(
  F1 = sum(read_areaframe("~/Github/areaframe/cells.parquet")$area),
  F2 = 300 * 300,
  F3 = diff(range(frames$F3$frame$x)) * diff(range(frames$F3$frame$y))
)
matrices <- map(frames, \(f) travel_matrix(f$frame, method = f$method, detour = f$detour, speed = SPEED))
# planar km coordinates of the units (no depot), for the covariance of the fields
km_coords <- function(fr) {
  u <- fr$frame |> filter(unit != "depot")
  if (fr$method == "haversine") {
    lat0 <- mean(u$lat) * pi / 180
    cbind(x = u$lon * 111.32 * cos(lat0), y = u$lat * 110.57)
  } else {
    cbind(x = u$x, y = u$y)
  }
}

n_grid_of <- function(N) {
  g <- c(10, 15, 20, 30, 40, 50, 60, 80, 100, 125, 150, 200, 250, 300, 350, 400, 450, 500, 600, 700, 800)
  g <- g[g < min(N, N_MAX + 1)]
  if (pilot) g <- g[seq(1, length(g), by = 3)]
  if (N <= N_MAX) g <- c(g, N)
  unique(g)
}
cost_model_of <- function(limit) {
  field_cost_model(
    per_travel = PER_TRAVEL, per_unit = PER_UNIT, per_interview = 0, interviews_per_unit = 1,
    per_route = if (limit == "daily") PER_ROUTE_DAY else 0, currency = "cost"
  )
}
limit_of <- function(frame, limit) {
  if (limit == "single") return(Inf)
  m <- unclass(matrices[[frame]])
  d <- which(rownames(m) == "depot")
  max(DAY, 2.2 * max(m[d, -d]))
}

# ---- stage 1: routed cost curves --------------------------------------------------
curve_cells <- expand.grid(frame = names(frames), selection = DESIGNS, limit = c("single", "daily"),
                           stringsAsFactors = FALSE)
run_frontier <- function(frame, selection, limit) {
  name <- sprintf("frontier_%s_%s_%s.rds", frame, selection, limit)
  for (dir in c(out_dir, if (!pilot) e2_dir)) {
    if (file.exists(file.path(dir, name))) return(readRDS(file.path(dir, name)))
  }
  fr <- frames[[frame]]$frame
  N <- nrow(fr) - 1L
  t1 <- Sys.time()
  f <- cost_variance_frontier(fr, "depot", cost_model_of(limit),
    n_grid = n_grid_of(N), selection = selection, matrix = matrices[[frame]],
    max_length = limit_of(frame, limit), n_rep = R_REP, iterations = ITER, seed = 11
  )
  res <- tibble(frame = frame, selection = selection, limit = limit, N = N) |>
    bind_cols(as_tibble(unclass(f))[, c("n", "cost_mean", "cost_sd", "cost_per_unit", "travel_mean", "routes_mean")]) |>
    mutate(seconds = as.numeric(difftime(Sys.time(), t1, units = "secs")))
  saveRDS(res, file.path(out_dir, name))
  res
}
message("stage 1: ", nrow(curve_cells), " cost curves (lpm and srs reused from E2 when present)")
curves <- parallel::mclapply(seq_len(nrow(curve_cells)),
  \(i) run_frontier(curve_cells$frame[i], curve_cells$selection[i], curve_cells$limit[i]),
  mc.cores = cores) |> list_rbind()
message("stage 1 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

# ---- stage 2: samples ---------------------------------------------------------------
sample_cells <- expand.grid(frame = names(frames), design = DESIGNS, n = N_VAR, stringsAsFactors = FALSE)
run_samples <- function(frame, design, n) {
  file <- file.path(out_dir, sprintf("samples_%s_%s_%d.rds", frame, design, n))
  if (file.exists(file)) return(readRDS(file))
  fr <- frames[[frame]]
  u <- fr$frame |> filter(unit != "depot")
  idx <- vapply(seq_len(R_SAMPLES), \(r) {
    s <- select_units(u, n = n, coords = fr$coords, method = design, seed = 100000 + r)
    which(s$sampled)
  }, integer(n))
  res <- list(frame = frame, design = design, n = n, N = nrow(u), idx = t(idx))
  saveRDS(res, file)
  res
}
message("stage 2: ", nrow(sample_cells), " sample sets of ", R_SAMPLES)
samples <- parallel::mclapply(seq_len(nrow(sample_cells)),
  \(i) run_samples(sample_cells$frame[i], sample_cells$design[i], sample_cells$n[i]),
  mc.cores = cores)
message("stage 2 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

# ---- stage 3: fields and variances ------------------------------------------------
fields_of <- function(frame, range_name) {
  file <- file.path(out_dir, sprintf("fields_%s_%s.rds", frame, range_name))
  if (file.exists(file)) return(readRDS(file))
  xy <- km_coords(frames[[frame]])
  N <- nrow(xy)
  set.seed(7 + match(range_name, names(RANGES)) * 100 + match(frame, names(frames)))
  phi <- RANGES[[range_name]] * sqrt(frame_area[[frame]])
  z <- if (phi == 0) {
    matrix(rnorm(N * N_FIELDS), N)
  } else {
    h <- as.matrix(dist(xy))
    L <- chol((1 - NUGGET) * exp(-h / phi) + diag(NUGGET + 1e-8, N))
    t(L) %*% matrix(rnorm(N * N_FIELDS), N)
  }
  y <- 10 + 3 * z    # mean 10, sd 3
  saveRDS(y, file)
  y
}
var_cells <- expand.grid(frame = names(frames), range = names(RANGES), stringsAsFactors = FALSE)
variances <- map(seq_len(nrow(var_cells)), \(k) {
  frame <- var_cells$frame[k]
  rg <- var_cells$range[k]
  y <- fields_of(frame, rg)
  keep(samples, \(s) s$frame == frame) |>
    map(\(s) {
      # HT totals of every field for every sample: N/n * sum of the sampled y
      tot <- apply(s$idx, 1, \(i) colSums(y[i, , drop = FALSE])) * s$N / s$n
      tot <- matrix(tot, nrow = ncol(y))
      tibble(frame = frame, range = rg, design = s$design, n = s$n, field = seq_len(ncol(y)),
             variance = apply(tot, 1, var), bias = rowMeans(tot) - colSums(y))
    }) |> list_rbind()
}) |> list_rbind()
message("stage 3 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

saveRDS(list(curves = curves, variances = variances, frame_area = frame_area, settings = list(
  R_REP = R_REP, ITER = ITER, SPEED = SPEED, PER_TRAVEL = PER_TRAVEL, PER_UNIT = PER_UNIT,
  PER_ROUTE_DAY = PER_ROUTE_DAY, DAY = DAY, R_SAMPLES = R_SAMPLES, N_VAR = N_VAR, RANGES = RANGES,
  NUGGET = NUGGET, N_FIELDS = N_FIELDS, INTERVIEW_COST = INTERVIEW_COST)),
  file.path(out_dir, "e1_results.rds"))
cat(paste("end", format(Sys.time()), "elapsed", round(difftime(Sys.time(), t0, units = "mins"), 1), "min"),
    file = file.path(out_dir, "session.txt"), append = TRUE, sep = "\n")
message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
