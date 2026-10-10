# E3 — do the variance estimators of the package hold under these designs?
#
# Usage:  Rscript experiments/run/e3_variance_estimators.R [cores] [pilot]
#
# E1 measured the true design variance of the HT total. A survey only has the
# estimate, so the comparison of designs is only usable if the estimator that
# design_variance() reports is close to the truth. For each frame of E1/E2,
# design (srs, lpm, systematic in one replicate, systematic in four
# interpenetrating replicates) and n, R samples are drawn, the study variables
# are the Gaussian fields of E1 (four spatial ranges, a few fields each), and
# for each sample and field the estimated total and estimated variance are
# recorded. Relative bias of the variance estimator = mean(estimate) / empirical
# variance of the totals - 1; coverage of the normal 95% interval.
# Every (frame, design, n) is one rds in experiments/out/e3/; the script resumes.
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
out_dir <- if (pilot) "experiments/out/e3_pilot" else "experiments/out/e3"
e1_dir <- "experiments/out/e1"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(capture.output(sessionInfo()), paste("start", format(Sys.time()))),
           file.path(out_dir, "session.txt"))
t0 <- Sys.time()

R_SAMPLES <- if (pilot) 50L else 1000L
N_VAR <- c(20, 80)
DESIGNS <- tribble(
  ~design,          ~method,      ~replicates,
  "srs",            "srs",        1L,
  "lpm",            "lpm",        1L,
  "systematic",     "systematic", 1L,
  "systematic_r4",  "systematic", 4L
)
FIELDS_PER_RANGE <- if (pilot) 2L else 5L

# frames: the same as E1 and E2 (only coordinates are needed here)
f1 <- read_areaframe("~/Github/areaframe/cells.parquet") |> select(unit, lat, lon)
i <- which.min((f1$lon + 60.67)^2 + (f1$lat - 2.82)^2)
f1 <- f1[-i, ]
set.seed(2)
g <- expand.grid(x = seq(5, 295, by = 10), y = seq(5, 295, by = 10))
f2 <- tibble(unit = paste0("g", seq_len(nrow(g))), x = g$x, y = g$y)
centres <- tibble(cx = c(60, 220, 240, 90), cy = c(70, 60, 230, 240), n = c(300, 200, 250, 150))
cl <- pmap(centres, \(cx, cy, n) tibble(x = cx + rnorm(n, sd = 25), y = cy + rnorm(n, sd = 25))) |>
  list_rbind() |>
  mutate(across(c(x, y), \(v) pmin(pmax(v, 0), 300)))
f3 <- tibble(unit = paste0("k", seq_len(nrow(cl))), x = cl$x, y = cl$y)
frames <- list(F1 = list(units = f1, coords = c("lat", "lon")),
               F2 = list(units = f2, coords = c("x", "y")),
               F3 = list(units = f3, coords = c("x", "y")))

# study variables: the first fields of E1 at each range
ranges <- c("iid", "short", "medium", "long")
with_fields <- function(frame) {
  u <- frames[[frame]]$units
  for (rg in ranges) {
    y <- readRDS(file.path(e1_dir, sprintf("fields_%s_%s.rds", frame, rg)))
    for (j in seq_len(FIELDS_PER_RANGE)) u[[sprintf("y_%s_%d", rg, j)]] <- y[, j]
  }
  u
}
units <- map(set_names(names(frames)), with_fields)
ycols <- grep("^y_", names(units$F1), value = TRUE)

cells <- expand_grid(frame = names(frames), design = DESIGNS$design, n = N_VAR)
run_cell <- function(frame, design, n) {
  file <- file.path(out_dir, sprintf("est_%s_%s_%d.rds", frame, design, n))
  if (file.exists(file)) return(readRDS(file))
  d <- DESIGNS[DESIGNS$design == design, ]
  u <- units[[frame]]
  res <- map(seq_len(R_SAMPLES), \(r) {
    s <- select_units(u, n = n, coords = frames[[frame]]$coords, method = d$method,
                      replicates = d$replicates, seed = 300000 + r)
    map(ycols, \(yc) {
      dv <- design_variance(s, yc)
      tibble(r = r, y = yc, total = dv$total, variance = dv$variance, method = dv$variance_method, df = dv$df)
    }) |> list_rbind()
  }) |> list_rbind() |>
    mutate(frame = frame, design = design, n = n, .before = 1)
  saveRDS(res, file)
  res
}
message(nrow(cells), " cells of ", R_SAMPLES, " samples x ", length(ycols), " variables")
est <- parallel::mclapply(seq_len(nrow(cells)), \(k) run_cell(cells$frame[k], cells$design[k], cells$n[k]),
                          mc.cores = cores) |> list_rbind()
truth <- imap(units, \(u, frame) tibble(frame = frame, y = ycols, true_total = map_dbl(ycols, \(yc) sum(u[[yc]])))) |>
  list_rbind()
saveRDS(list(est = est, truth = truth, settings = list(R_SAMPLES = R_SAMPLES, N_VAR = N_VAR,
  DESIGNS = DESIGNS, FIELDS_PER_RANGE = FIELDS_PER_RANGE)), file.path(out_dir, "e3_results.rds"))
cat(paste("end", format(Sys.time()), "elapsed", round(difftime(Sys.time(), t0, units = "mins"), 1), "min"),
    file = file.path(out_dir, "session.txt"), append = TRUE, sep = "\n")
message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
