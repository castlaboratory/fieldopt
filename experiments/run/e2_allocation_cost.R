# E2 — allocation with a constant per-unit cost versus the routed cost
#
# Usage:  Rscript experiments/run/e2_allocation_cost.R [cores] [pilot]
#
# Stage 1 tabulates the routed cost curve T(n) of each frame, selection design
# and route limit on a grid of sample sizes (cost_variance_frontier). Stage 2
# runs the two-stage allocations (A linear, B routed loop, C oracle) and
# stage 3 the dual-frame allocations. Every unit of work is saved as one rds in
# experiments/out/e2/ and skipped when the file exists, so the script resumes.
suppressPackageStartupMessages({
  library(fieldopt)
  library(dplyr)
  library(tibble)
  library(purrr)
})
args <- commandArgs(trailingOnly = TRUE)
cores <- if (length(args) >= 1) as.integer(args[1]) else 10L
pilot <- length(args) >= 2 && args[2] == "pilot"
out_dir <- "experiments/out/e2"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(capture.output(sessionInfo()), paste("start", format(Sys.time()))),
           file.path(out_dir, "session.txt"))
t0 <- Sys.time()

# ---- settings --------------------------------------------------------------
R_REP <- if (pilot) 3L else 10L        # routed replicates per sample size
ITER <- 60L                            # HGS offspring per routing
SPEED <- 60                            # km/h -> matrix in minutes
PER_TRAVEL <- 1.5                      # cost per minute of travel
PER_UNIT <- 60                         # fixed cost per visited cell
PER_INTERVIEW <- 25                    # c2
PER_ROUTE_DAY <- 200                   # fixed cost of a day (daily routes only)
DAY <- 480                             # minutes of travel per route (daily routes only);
                                       # raised to 2.2 x the farthest one-way trip when needed
M_SECONDARY <- 20                      # secondary units per primary unit
S1 <- 1                                # between-primary variance (per mean unit)
S2_RATIOS <- c(0.5, 2, 8)              # S2^2 / S1^2
N_MAX <- 450                           # largest routed sample size (the allocations land far below)
COST_B <- 45                           # list-frame cost per unit
TARGET_CV_DUAL <- 0.08

# ---- frames ----------------------------------------------------------------
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
    F1 = list(frame = f1, method = "haversine", detour = 1.3),
    F2 = list(frame = f2, method = "euclidean", detour = 1.3),
    F3 = list(frame = f3, method = "euclidean", detour = 1.3)
  )
}
frames <- make_frames()
frame_area <- c(
  F1 = sum(read_areaframe("~/Github/areaframe/cells.parquet")$area),   # km2, from the cells
  F2 = 300 * 300,                                                      # km2, the grid
  F3 = diff(range(frames$F3$frame$x)) * diff(range(frames$F3$frame$y)) # km2, bounding box
)
matrices <- map(frames, \(f) travel_matrix(f$frame, method = f$method, detour = f$detour, speed = SPEED))

n_grid_of <- function(N) {
  g <- c(10, 15, 20, 30, 40, 50, 60, 80, 100, 125, 150, 200, 250, 300, 350, 400, 450, 500, 600, 700, 800)
  g <- g[g < min(N, N_MAX + 1)]
  if (pilot) g <- g[seq(1, length(g), by = 3)]
  if (N <= N_MAX) g <- c(g, N)
  unique(g)
}
cost_model_of <- function(limit, per_interview = 0, ipu = 1) {
  field_cost_model(
    per_travel = PER_TRAVEL, per_unit = PER_UNIT, per_interview = per_interview,
    interviews_per_unit = ipu, per_route = if (limit == "daily") PER_ROUTE_DAY else 0,
    currency = "cost"
  )
}
limit_of <- function(frame, limit) {
  if (limit == "single") return(Inf)
  m <- unclass(matrices[[frame]])
  d <- which(rownames(m) == "depot")
  max(DAY, 2.2 * max(m[d, -d]))
}

cells <- expand.grid(frame = names(frames), selection = c("lpm", "srs"), limit = c("single", "daily"),
                     stringsAsFactors = FALSE)
if (pilot) cells <- cells[cells$frame == "F1", ]

# ---- stage 1: routed cost curves -----------------------------------------------
run_frontier <- function(frame, selection, limit) {
  file <- file.path(out_dir, sprintf("frontier_%s_%s_%s.rds", frame, selection, limit))
  if (file.exists(file)) return(readRDS(file))
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
  saveRDS(res, file)
  res
}
message("stage 1: ", nrow(cells), " cost curves")
curves <- parallel::mclapply(seq_len(nrow(cells)), \(i) run_frontier(cells$frame[i], cells$selection[i], cells$limit[i]),
                             mc.cores = cores) |> list_rbind()
message("stage 1 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

# interpolated routed cost of the frame (travel + per-unit + routes, no interviews)
curve_fun <- function(cv) {
  cv <- arrange(cv, n)
  f <- splinefun(cv$n, cv$cost_mean, method = "monoH.FC")
  function(n) f(pmin(pmax(n, min(cv$n)), max(cv$n)))
}
# fixed-point loop with the marginal routed cost G'(n) in place of the average
marginal_loop <- function(alloc_fun, Gprime, c1_start, max_iter = 30) {
  c1 <- c1_start
  n_prev <- NA_integer_
  hist <- numeric()
  for (it in seq_len(max_iter)) {
    a <- alloc_fun(c1)
    n <- a$n
    hist <- c(hist, n)
    if (identical(n, n_prev) || (it > 4 && n %in% hist[-length(hist)])) break
    n_prev <- n
    c1 <- max(1e-6, Gprime(n))
  }
  a$c1 <- c1
  a$rounds <- it
  a$converged <- identical(n, n_prev)
  a
}
curve_deriv <- function(cv) {
  cv <- arrange(cv, n)
  f <- splinefun(cv$n, cv$cost_mean, method = "monoH.FC")
  function(n) f(pmin(pmax(n, min(cv$n)), max(cv$n)), deriv = 1)
}
naive_c1 <- function(frame) {
  m <- unclass(matrices[[frame]])
  d <- which(rownames(m) == "depot")
  PER_UNIT + PER_TRAVEL * median(m[d, -d])
}

# ---- stage 2: two-stage allocation -----------------------------------------------
# variance per mean unit of the two-stage design (Cochran), as in the package
var_ts <- function(n, m, N, M, s1, s2) (1 - n / N) * s1 / n + pmax(0, 1 - m / M) * s2 / (n * m)
oracle_ts <- function(Tn, N, M, s1, s2, c2, target_variance = NULL, budget = NULL, n_max = N) {
  n_all <- 2:n_max
  best <- NULL
  for (m in seq_len(floor(M))) {
    cost <- Tn(n_all) + c2 * n_all * m
    v <- var_ts(n_all, m, N, M, s1, s2)
    if (!is.null(target_variance)) {
      ok <- v <= target_variance
      if (!any(ok)) next
      i <- which(ok)[which.min(cost[ok])]
    } else {
      ok <- cost <= budget
      if (!any(ok)) next
      i <- which(ok)[which.min(v[ok])]
    }
    cand <- tibble(n = n_all[i], m = m, cost = cost[i], variance = v[i])
    if (is.null(best) || (if (!is.null(target_variance)) cand$cost < best$cost else cand$variance < best$variance)) best <- cand
  }
  best
}
ts_scenarios <- expand.grid(i = seq_len(nrow(cells)), s2_ratio = S2_RATIOS, stringsAsFactors = FALSE)
run_two_stage <- function(i, s2_ratio) {
  frame <- cells$frame[i]; selection <- cells$selection[i]; limit <- cells$limit[i]
  file <- file.path(out_dir, sprintf("twostage_%s_%s_%s_r%s.rds", frame, selection, limit, s2_ratio))
  if (file.exists(file)) return(readRDS(file))
  cv <- curves |> filter(frame == !!frame, selection == !!selection, limit == !!limit)
  N <- cv$N[1]; M <- M_SECONDARY; s1 <- S1; s2 <- s2_ratio * S1; c2 <- PER_INTERVIEW
  Tn <- curve_fun(cv)
  n_max <- max(cv$n)
  fr <- frames[[frame]]$frame
  # target: the variance that the naive design reaches with roughly N/5 primary units
  target_variance <- var_ts(round(N / 5), 5, N, M, s1, s2)
  tv_total <- target_variance * (N * M)^2   # the package takes the variance of the total
  cm0 <- cost_model_of(limit)                                  # no interviews (c1 part)
  evaluate <- function(n, m) tibble(n = n, m = m, cost = Tn(n) + c2 * n * m, variance = var_ts(n, m, N, M, s1, s2))
  rows <- list()
  # --- target variance
  C <- oracle_ts(Tn, N, M, s1, s2, c2, target_variance = target_variance, n_max = n_max)
  A <- two_stage_allocation(N, M, s1, s2, c1 = naive_c1(frame), c2 = c2, target_variance = tv_total)
  B <- two_stage_design(fr, "depot", cost_model_of(limit, per_interview = c2), m_secondary = M,
    s2_between = s1, s2_within = s2, target_variance = tv_total, matrix = matrices[[frame]],
    selection = selection, max_length = limit_of(frame, limit), n_rep = R_REP, iterations = ITER, seed = 23)
  Gp <- curve_deriv(cv)
  Bm <- marginal_loop(\(c1) two_stage_allocation(N, M, s1, s2, c1 = c1, c2 = c2, target_variance = tv_total),
                      Gp, naive_c1(frame))
  rows$variance <- bind_rows(
    A = evaluate(A$n, A$m) |> mutate(c1_used = A$inputs$c1, claimed_cost = A$cost),
    B = evaluate(B$n, B$m) |> mutate(c1_used = B$c1, claimed_cost = B$cost, rounds = nrow(B$history), converged = B$converged),
    `B'` = evaluate(Bm$n, Bm$m) |> mutate(c1_used = Bm$c1, claimed_cost = Bm$cost, rounds = Bm$rounds, converged = Bm$converged),
    C = C |> mutate(c1_used = Tn(C$n) / C$n, claimed_cost = C$cost),
    .id = "procedure") |> mutate(constraint = "target_variance", target = target_variance)
  # --- budget = the oracle's cost at the target
  budget <- C$cost
  Cb <- oracle_ts(Tn, N, M, s1, s2, c2, budget = budget, n_max = n_max)
  Ab <- two_stage_allocation(N, M, s1, s2, c1 = naive_c1(frame), c2 = c2, budget = budget)
  Bb <- two_stage_design(fr, "depot", cost_model_of(limit, per_interview = c2), m_secondary = M,
    s2_between = s1, s2_within = s2, budget = budget, matrix = matrices[[frame]],
    selection = selection, max_length = limit_of(frame, limit), n_rep = R_REP, iterations = ITER, seed = 29)
  Bmb <- marginal_loop(\(c1) two_stage_allocation(N, M, s1, s2, c1 = c1, c2 = c2, budget = budget),
                       Gp, naive_c1(frame))
  # the marginal rule fixes m; the number of primary units comes from the true cost
  n_all <- 2:n_max
  ok <- Tn(n_all) + c2 * n_all * Bmb$m <= budget
  Bmb$n <- if (any(ok)) max(n_all[ok]) else 2L
  rows$budget <- bind_rows(
    A = evaluate(Ab$n, Ab$m) |> mutate(c1_used = Ab$inputs$c1, claimed_cost = Ab$cost),
    B = evaluate(Bb$n, Bb$m) |> mutate(c1_used = Bb$c1, claimed_cost = Bb$cost, rounds = nrow(Bb$history), converged = Bb$converged),
    `B'` = evaluate(Bmb$n, Bmb$m) |> mutate(c1_used = Bmb$c1, claimed_cost = Bmb$cost, rounds = Bmb$rounds, converged = Bmb$converged),
    C = Cb |> mutate(c1_used = Tn(Cb$n) / Cb$n, claimed_cost = Cb$cost),
    .id = "procedure") |> mutate(constraint = "budget", target = budget)
  res <- list_rbind(rows) |>
    mutate(frame = frame, selection = selection, limit = limit, s2_ratio = s2_ratio, N = N, .before = 1)
  saveRDS(res, file)
  res
}
message("stage 2: ", nrow(ts_scenarios), " two-stage scenarios")
twostage <- parallel::mclapply(seq_len(nrow(ts_scenarios)),
  \(k) run_two_stage(ts_scenarios$i[k], ts_scenarios$s2_ratio[k]), mc.cores = cores) |> list_rbind()
message("stage 2 done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")

# ---- stage 3: dual-frame allocation --------------------------------------------------
frame_sd <- function(only, overlap, theta) {
  n1 <- only$size; n2 <- overlap$size; n <- n1 + n2
  m1 <- only$mean; m2 <- theta * overlap$mean
  mu <- (n1 * m1 + n2 * m2) / n
  within <- (n1 - 1) * only$sd^2 + (n2 - 1) * theta^2 * overlap$sd^2
  between <- n1 * (m1 - mu)^2 + n2 * (m2 - mu)^2
  sqrt(max(0, (within + between) / (n - 1)))
}
domains_of <- function(N) {
  ab <- round(0.15 * N)
  tibble(domain = c("a", "ab", "b"), size = c(N - ab, ab, 30), mean = c(6, 30, 45), sd = c(5, 20, 35))
}
dual_var <- function(d, n_a, n_b, theta) {
  da <- as.list(d[1, ]); dab <- as.list(d[2, ]); db <- as.list(d[3, ])
  NA_ <- da$size + dab$size; NB <- db$size + dab$size
  sa <- frame_sd(da, dab, theta); sb <- frame_sd(db, dab, 1 - theta)
  NA_^2 * sa^2 / n_a * (1 - n_a / NA_) + NB^2 * sb^2 / n_b * (1 - n_b / NB)
}
# oracle over n_a (true routed cost), n_b and theta
oracle_dual <- function(Tn, d, cost_b, target_variance = NULL, budget = NULL, n_max = NULL) {
  NA_ <- d$size[1] + d$size[2]; NB <- d$size[3] + d$size[2]
  if (is.null(n_max)) n_max <- NA_
  best <- NULL
  for (theta in seq(0, 1, by = 0.02)) {
    sa <- frame_sd(as.list(d[1, ]), as.list(d[2, ]), theta)
    sb <- frame_sd(as.list(d[3, ]), as.list(d[2, ]), 1 - theta)
    n_a <- 2:n_max
    va <- NA_^2 * sa^2 / n_a * (1 - n_a / NA_)
    Ta <- Tn(n_a)
    if (!is.null(target_variance)) {
      rem <- target_variance - va
      n_b <- ceiling(NB^2 * sb^2 / (rem + NB * sb^2))
      ok <- rem > 0 & n_b >= 2 & n_b <= NB
      if (!any(ok)) next
      cost <- Ta + cost_b * n_b
      i <- which(ok)[which.min(cost[ok])]
      v_i <- va[i] + NB^2 * sb^2 / n_b[i] * (1 - n_b[i] / NB)
      cand <- tibble(theta = theta, n_a = n_a[i], n_b = n_b[i], cost = cost[i], variance = v_i)
      if (is.null(best) || cand$cost < best$cost) best <- cand
    } else {
      n_b <- floor((budget - Ta) / cost_b)
      ok <- n_b >= 2
      if (!any(ok)) next
      n_b <- pmin(n_b, NB)
      v <- va + NB^2 * sb^2 / n_b * (1 - n_b / NB)
      i <- which(ok)[which.min(v[ok])]
      c_i <- Ta[i] + cost_b * n_b[i]
      cand <- tibble(theta = theta, n_a = n_a[i], n_b = n_b[i], cost = c_i, variance = v[i])
      if (is.null(best) || cand$variance < best$variance) best <- cand
    }
  }
  best
}
run_dual <- function(i) {
  frame <- cells$frame[i]; selection <- cells$selection[i]; limit <- cells$limit[i]
  file <- file.path(out_dir, sprintf("dual_%s_%s_%s.rds", frame, selection, limit))
  if (file.exists(file)) return(readRDS(file))
  cv <- curves |> filter(frame == !!frame, selection == !!selection, limit == !!limit)
  N <- cv$N[1]
  d <- domains_of(N)
  fr <- frames[[frame]]$frame
  # the area unit costs one interview per cell on top of the routed cost
  cmA <- cost_model_of(limit, per_interview = PER_INTERVIEW, ipu = 1)
  Tn0 <- curve_fun(cv)
  Tn <- function(n) Tn0(n) + PER_INTERVIEW * n
  n_max <- max(cv$n)
  total <- sum(d$size * d$mean)
  target_variance <- (TARGET_CV_DUAL * total)^2
  evaluate <- function(n_a, n_b, theta) tibble(n_a = n_a, n_b = n_b, theta = theta,
    cost = Tn(n_a) + COST_B * n_b, variance = dual_var(d, n_a, n_b, theta))
  m <- unclass(matrices[[frame]]); dd <- which(rownames(m) == "depot")
  cost_a_naive <- PER_UNIT + PER_INTERVIEW + PER_TRAVEL * median(m[dd, -dd])
  C <- oracle_dual(Tn, d, COST_B, target_variance = target_variance, n_max = n_max)
  A <- dual_frame_allocation(d, cost_a = cost_a_naive, cost_b = COST_B, target_variance = target_variance)
  B <- dual_frame_design(fr, "depot", cmA, d, cost_b = COST_B, target_variance = target_variance,
    matrix = matrices[[frame]], selection = selection, max_length = limit_of(frame, limit),
    n_rep = R_REP, iterations = ITER, seed = 31)
  Gp0 <- curve_deriv(cv)
  Gp <- function(n) Gp0(n) + PER_INTERVIEW
  dual_alloc <- function(c1, ...) {
    a <- dual_frame_allocation(d, cost_a = c1, cost_b = COST_B, ...)
    a$n <- a$n_a
    a
  }
  Bm <- marginal_loop(\(c1) dual_alloc(c1, target_variance = target_variance), Gp, cost_a_naive)
  v_rows <- bind_rows(
    A = evaluate(A$n_a, A$n_b, A$theta) |> mutate(cost_a_used = cost_a_naive, claimed_cost = A$cost),
    B = evaluate(B$n_a, B$n_b, B$theta) |> mutate(cost_a_used = B$cost_a, claimed_cost = B$cost, rounds = nrow(B$history), converged = B$converged),
    `B'` = evaluate(Bm$n_a, Bm$n_b, Bm$theta) |> mutate(cost_a_used = Bm$c1, claimed_cost = Bm$cost, rounds = Bm$rounds, converged = Bm$converged),
    C = C |> mutate(cost_a_used = Tn(C$n_a) / C$n_a, claimed_cost = C$cost),
    .id = "procedure") |> mutate(constraint = "target_variance", target = target_variance)
  budget <- C$cost
  Cb <- oracle_dual(Tn, d, COST_B, budget = budget, n_max = n_max)
  Ab <- dual_frame_allocation(d, cost_a = cost_a_naive, cost_b = COST_B, budget = budget)
  Bb <- dual_frame_design(fr, "depot", cmA, d, cost_b = COST_B, budget = budget,
    matrix = matrices[[frame]], selection = selection, max_length = limit_of(frame, limit),
    n_rep = R_REP, iterations = ITER, seed = 37)
  Bmb <- marginal_loop(\(c1) dual_alloc(c1, budget = budget), Gp, cost_a_naive)
  NB <- d$size[3] + d$size[2]
  ratio <- Bmb$n_b / Bmb$n_a
  n_all <- 2:n_max
  nb_all <- pmin(NB, pmax(2, round(ratio * n_all)))
  ok <- Tn(n_all) + COST_B * nb_all <= budget
  if (any(ok)) {
    Bmb$n_a <- max(n_all[ok])
    Bmb$n_b <- nb_all[n_all == Bmb$n_a]
  }
  b_rows <- bind_rows(
    A = evaluate(Ab$n_a, Ab$n_b, Ab$theta) |> mutate(cost_a_used = cost_a_naive, claimed_cost = Ab$cost),
    B = evaluate(Bb$n_a, Bb$n_b, Bb$theta) |> mutate(cost_a_used = Bb$cost_a, claimed_cost = Bb$cost, rounds = nrow(Bb$history), converged = Bb$converged),
    `B'` = evaluate(Bmb$n_a, Bmb$n_b, Bmb$theta) |> mutate(cost_a_used = Bmb$c1, claimed_cost = Bmb$cost, rounds = Bmb$rounds, converged = Bmb$converged),
    C = Cb |> mutate(cost_a_used = Tn(Cb$n_a) / Cb$n_a, claimed_cost = Cb$cost),
    .id = "procedure") |> mutate(constraint = "budget", target = budget)
  res <- bind_rows(v_rows, b_rows) |>
    mutate(frame = frame, selection = selection, limit = limit, N = N, .before = 1)
  saveRDS(res, file)
  res
}
message("stage 3: ", nrow(cells), " dual-frame scenarios")
dual <- parallel::mclapply(seq_len(nrow(cells)), run_dual, mc.cores = cores) |> list_rbind()
saveRDS(list(curves = curves, twostage = twostage, dual = dual, frame_area = frame_area, settings = list(
  R_REP = R_REP, ITER = ITER, SPEED = SPEED, PER_TRAVEL = PER_TRAVEL, PER_UNIT = PER_UNIT,
  PER_INTERVIEW = PER_INTERVIEW, PER_ROUTE_DAY = PER_ROUTE_DAY, DAY = DAY, M_SECONDARY = M_SECONDARY,
  S1 = S1, S2_RATIOS = S2_RATIOS, COST_B = COST_B, TARGET_CV_DUAL = TARGET_CV_DUAL),
  limits = sapply(names(frames), \(f) limit_of(f, "daily"))),
  file.path(out_dir, "e2_results.rds"))
cat(paste("end", format(Sys.time()), "elapsed", round(difftime(Sys.time(), t0, units = "mins"), 1), "min"),
    file = file.path(out_dir, "session.txt"), append = TRUE, sep = "\n")
message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
