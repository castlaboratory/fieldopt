# The calendar as an integer programme ----------------------------------------

#' Redistribute the routes of a schedule over teams and days with constraints
#'
#' [schedule_fieldwork()] hands the routes of each base to its teams with a
#' simple rule (longest route first, one route per team-day). This function
#' solves that distribution exactly as a small integer programme, through
#' the `highs` package (in Suggests), which allows the constraints of real
#' field work: teams unavailable on some days, routes fixed to a team or a
#' day, routes that must precede others, a daily limit per team that lets
#' two short routes share one team-day. The objective finishes as early as
#' possible: it minimises the last working day of the schedule and, among
#' schedules with the same end, the sum of the days on which routes are
#' done.
#'
#' @param schedule A `fieldopt_schedule` from [schedule_fieldwork()].
#' @param availability Optional data frame with columns `team`, `day` and
#'   `available` (logical): the team-days that are not listed are available.
#'   Team names are those of the calendar (`"base-1"`, `"base-2"`, ...).
#' @param fixed Optional data frame with columns `base`, `route` and `team`
#'   and/or `day`: routes that must go to that team and/or that day.
#' @param before Optional data frame with columns `base`, `route`, `base_after`
#'   and `route_after`: the first route must be done on an earlier day than
#'   the second.
#' @param daily_limit Maximum duration of a team-day (in the unit of the
#'   travel matrix); the routes already respect the `max_length` of the
#'   schedule, so this is only useful to let several short routes share a
#'   day. `NULL` keeps one route per team-day.
#' @param time_limit Seconds allowed to the solver.
#' @return The schedule with its `calendar`, `summary` and `fits` recomputed,
#'   plus `solver` (`"highs"`), `objective` and `status`. An error when no
#'   calendar satisfies the constraints within `days`.
#' @export
#' @examples
#' set.seed(5)
#' pts <- data.frame(unit = c("base1", "base2", paste0("s", 1:30)),
#'                   x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10)))
#' m <- travel_matrix(pts, method = "euclidean")
#' sch <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 1),
#'                           days = 5, max_stops = 4, iterations = 30)
#' if (requireNamespace("highs", quietly = TRUE)) {
#'   off <- data.frame(team = "base1-1", day = 1, available = FALSE)
#'   schedule_calendar(sch, availability = off)
#' }
schedule_calendar <- function(schedule, availability = NULL, fixed = NULL, before = NULL, daily_limit = NULL,
                              time_limit = 10) {
  rlang::check_installed("highs", reason = "to solve the calendar as an integer programme.")
  if (!inherits(schedule, "fieldopt_schedule")) cli::cli_abort("{.arg schedule} must come from {.fn schedule_fieldwork}.")
  days <- schedule$days; teams <- schedule$teams; bases <- names(teams)
  # the routes: one row per route with its base, duration and units
  rows <- do.call(rbind, lapply(bases, function(b) {
    r <- schedule$routes[[b]]
    if (is.null(r)) return(NULL)
    tibble::tibble(base = b, route = seq_len(r$n_routes), duration = r$durations, travel = r$lengths,
                   stops = as.integer(table(factor(r$routes$route, levels = seq_len(r$n_routes)))),
                   units = lapply(seq_len(r$n_routes), function(k) r$routes$unit[r$routes$route == k]))
  }))
  if (is.null(rows) || !nrow(rows)) cli::cli_abort("The schedule has no routes.")
  R <- nrow(rows)
  team_tbl <- do.call(rbind, lapply(bases, function(b) tibble::tibble(base = b, team = paste0(b, "-", seq_len(teams[b])))))
  Tn <- nrow(team_tbl)
  # availability matrix teams x days
  avail <- matrix(TRUE, Tn, days, dimnames = list(team_tbl$team, NULL))
  if (!is.null(availability)) {
    for (col in c("team", "day", "available")) if (!col %in% names(availability)) cli::cli_abort("{.arg availability} needs columns {.field team}, {.field day} and {.field available}.")
    bad <- setdiff(availability$team, team_tbl$team); if (length(bad)) cli::cli_abort("Unknown team{?s} {.val {bad}}.")
    for (i in seq_len(nrow(availability))) {
      d <- availability$day[i]
      if (d >= 1 && d <= days) avail[availability$team[i], d] <- isTRUE(availability$available[i])
    }
  }
  limit <- if (is.null(daily_limit)) NULL else { if (!is.numeric(daily_limit) || daily_limit <= 0) cli::cli_abort("{.arg daily_limit} must be positive."); daily_limit }
  # variables: x[r, t, d] for teams of the route's base and available team-days; then the makespan M
  var <- do.call(rbind, lapply(seq_len(R), function(r) {
    ts <- which(team_tbl$base == rows$base[r])
    do.call(rbind, lapply(ts, function(t) { ds <- which(avail[t, ]); if (!length(ds)) NULL else data.frame(r = r, t = t, d = ds) }))
  }))
  if (is.null(var) || !nrow(var)) cli::cli_abort("No available team-day for the routes.")
  # fixed assignments: drop variables that contradict them
  if (!is.null(fixed)) {
    for (col in c("base", "route")) if (!col %in% names(fixed)) cli::cli_abort("{.arg fixed} needs columns {.field base} and {.field route}.")
    for (i in seq_len(nrow(fixed))) {
      r <- which(rows$base == fixed$base[i] & rows$route == fixed$route[i])
      if (!length(r)) cli::cli_abort("Route {fixed$route[i]} of base {.val {fixed$base[i]}} not found.")
      if ("team" %in% names(fixed) && !is.na(fixed$team[i])) { t <- match(fixed$team[i], team_tbl$team); if (is.na(t)) cli::cli_abort("Unknown team {.val {fixed$team[i]}}."); var <- var[!(var$r == r & var$t != t), ] }
      if ("day" %in% names(fixed) && !is.na(fixed$day[i])) var <- var[!(var$r == r & var$d != fixed$day[i]), ]
    }
  }
  nx <- nrow(var); nvar <- nx + 1L  # last variable: makespan
  obj <- c(var$d, R * days)  # days are the secondary objective; the makespan dominates
  cons <- list(); lhs <- c(); rhs <- c()
  add <- function(idx, val, lo, hi) { cons[[length(cons) + 1]] <<- cbind(idx, val); lhs <<- c(lhs, lo); rhs <<- c(rhs, hi) }
  for (r in seq_len(R)) { idx <- which(var$r == r); if (!length(idx)) cli::cli_abort("Route {rows$route[r]} of base {.val {rows$base[r]}} has no admissible team-day."); add(idx, rep(1, length(idx)), 1, 1) }
  for (t in seq_len(Tn)) for (d in seq_len(days)) {
    idx <- which(var$t == t & var$d == d)
    if (!length(idx)) next
    if (is.null(limit)) add(idx, rep(1, length(idx)), -Inf, 1) else add(idx, rows$duration[var$r[idx]], -Inf, limit)
  }
  for (r in seq_len(R)) { idx <- which(var$r == r); add(c(idx, nvar), c(var$d[idx], -1), -Inf, 0) }  # day(r) <= M
  if (!is.null(before)) {
    for (col in c("base", "route", "base_after", "route_after")) if (!col %in% names(before)) cli::cli_abort("{.arg before} needs columns {.field base}, {.field route}, {.field base_after}, {.field route_after}.")
    for (i in seq_len(nrow(before))) {
      a <- which(rows$base == before$base[i] & rows$route == before$route[i]); b <- which(rows$base == before$base_after[i] & rows$route == before$route_after[i])
      if (!length(a) || !length(b)) cli::cli_abort("Routes of {.arg before} not found.")
      ia <- which(var$r == a); ib <- which(var$r == b)
      add(c(ia, ib), c(var$d[ia], -var$d[ib]), -Inf, -1)  # day(a) - day(b) <= -1
    }
  }
  nr <- length(cons)
  ii <- unlist(lapply(seq_len(nr), function(k) rep(k, nrow(cons[[k]])))); jj <- unlist(lapply(cons, function(c) c[, 1])); vv <- unlist(lapply(cons, function(c) c[, 2]))
  A <- Matrix::sparseMatrix(i = ii, j = jj, x = vv, dims = c(nr, nvar))
  sol <- highs::highs_solve(L = obj, lower = c(rep(0, nx), 1), upper = c(rep(1, nx), days), A = A, lhs = lhs, rhs = rhs,
                            types = c(rep("I", nx), "C"), control = list(time_limit = time_limit, log_to_console = FALSE))
  status <- sol$status_message
  if (is.null(sol$primal_solution) || !length(sol$primal_solution) || !grepl("Optimal|Feasible|Time limit", status)) {
    cli::cli_abort(c("No calendar satisfies the constraints within {days} day{?s}.", i = "Solver status: {status}. Add days or teams, or relax the constraints."))
  }
  x <- round(sol$primal_solution[seq_len(nx)])
  if (abs(sum(x) - R) > 0.5) cli::cli_abort(c("The solver did not place every route.", i = "Solver status: {status}."))
  chosen <- var[x > 0.5, ]
  cal <- do.call(rbind, lapply(seq_len(nrow(chosen)), function(k) {
    r <- chosen$r[k]
    tibble::tibble(base = rows$base[r], team = team_tbl$team[chosen$t[k]], day = chosen$d[k], route = rows$route[r], stops = rows$stops[r],
                   travel = rows$travel[r], duration = rows$duration[r], units = rows$units[r])
  }))
  cal <- cal[order(cal$base, cal$team, cal$day, cal$route), ]
  summary <- do.call(rbind, lapply(bases, function(b) {
    cb <- cal[cal$base == b, ]
    tibble::tibble(base = b, units = length(unlist(cb$units)), teams = unname(teams[b]), routes = nrow(cb),
                   days_needed = if (nrow(cb)) max(cb$day) else 0L, days_available = days, fits = TRUE)
  }))
  schedule$calendar <- cal; schedule$summary <- summary; schedule$fits <- TRUE
  schedule$solver <- "highs"; schedule$objective <- sol$objective_value; schedule$status <- status
  schedule
}
