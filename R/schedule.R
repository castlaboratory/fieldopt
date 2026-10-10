# Teams, bases and the field calendar ----------------------------------------

#' Schedule the field work of several teams from several bases
#'
#' Assigns the units to visit to bases (depots), routes the units of each
#' base under the daily limits with [route_fieldwork()] (one route is one
#' team-day), and distributes the routes over the teams of the base and the
#' days available, longest routes first, so that the teams finish as evenly
#' as possible. The result is a calendar: which team visits which units on
#' which day, and whether the work fits in the days available.
#'
#' Units go to their nearest base by default. With `assign = "balanced"`,
#' units are moved from bases whose expected number of routes exceeds the
#' team-days available to the base with spare capacity that costs them the
#' least extra travel; the final routing decides the actual number of routes,
#' so the calendar still reports when a base is short of days.
#'
#' @param matrix A [travel_matrix()] holding the units and the bases.
#' @param units Names of the units to visit.
#' @param teams Named vector: number of teams per base (names are units of
#'   the matrix that act as bases). A single unnamed number with one base is
#'   accepted when `bases` is given.
#' @param days Number of working days available.
#' @param bases Optional names of the bases when `teams` is unnamed.
#' @param max_length,max_stops,service_time Daily limits of a route, as in
#'   [route_fieldwork()].
#' @param assign `"nearest"` or `"balanced"` (see Details).
#' @param cost_model Optional [field_cost_model()]; its `per_route` cost is
#'   charged once per team-day.
#' @param iterations,time_limit,alpha,seed,engine Solver settings of
#'   [route_fieldwork()]. With `engine = "vrpr"` the assignment of units to
#'   bases and the routes are optimised jointly (a multi-depot problem with
#'   `teams * days` routes available per base and the `per_route` cost of the
#'   cost model in the objective), and `assign` is ignored.
#' @return An object of class `fieldopt_schedule`: `calendar` (a tibble with
#'   one row per route: `base`, `team`, `day`, `route`, `stops`, `travel`,
#'   `duration`, and `units` as a list column), `assignment` (unit, base),
#'   `routes` (the [route_fieldwork()] solution of each base), `summary`
#'   (per base: units, teams, routes, days needed, days available, whether
#'   it fits), `fits` and `cost`.
#' @export
#' @examples
#' set.seed(5)
#' pts <- data.frame(unit = c("base1", "base2", paste0("s", 1:30)),
#'                   x = c(2, 8, runif(30, 0, 10)), y = c(2, 8, runif(30, 0, 10)))
#' m <- travel_matrix(pts, method = "euclidean")
#' sch <- schedule_fieldwork(m, units = paste0("s", 1:30), teams = c(base1 = 2, base2 = 1),
#'                           days = 4, max_stops = 4, iterations = 30)
#' sch
#' sch$calendar
schedule_fieldwork <- function(matrix, units, teams, days, bases = NULL, max_length = Inf, max_stops = Inf,
                               service_time = 0, assign = c("nearest", "balanced"), cost_model = NULL,
                               iterations = 100, time_limit = NULL, alpha = 0.3, seed = 1, engine = c("fieldopt", "vrpr")) {
  assign <- rlang::arg_match(assign)
  engine <- rlang::arg_match(engine)
  if (!inherits(matrix, "fieldopt_matrix")) cli::cli_abort("{.arg matrix} must come from {.fn travel_matrix}.")
  nm <- rownames(matrix); m <- unclass(matrix)
  if (is.null(names(teams))) {
    if (is.null(bases) || length(bases) != length(teams)) cli::cli_abort("{.arg teams} must be named by base, or {.arg bases} must name one base per entry.")
    names(teams) <- bases
  }
  if (!is.numeric(teams) || any(teams < 1) || any(teams != round(teams))) cli::cli_abort("{.arg teams} must be whole numbers of at least 1.")
  if (!is.numeric(days) || length(days) != 1L || days < 1 || days != round(days)) cli::cli_abort("{.arg days} must be a whole number of at least 1.")
  bases <- names(teams)
  bad <- setdiff(c(bases, units), nm); if (length(bad)) cli::cli_abort("Unknown unit{?s} {.val {bad}}.")
  if (any(units %in% bases)) cli::cli_abort("A base cannot be among the units to visit.")
  if (anyDuplicated(units) || anyDuplicated(bases)) cli::cli_abort("{.arg units} and the bases must be distinct.")
  check_seed(seed)
  # assignment of units to bases
  dist_to <- m[units, bases, drop = FALSE] + t(m[bases, units, drop = FALSE])  # out and back
  base_of <- bases[apply(dist_to, 1, which.min)]
  joint <- NULL
  if (engine == "vrpr") {
    service <- service_vector(service_time, nm)
    joint <- route_with_vrpr(matrix, units = units, bases = bases, vehicles = teams * days, max_length = max_length, max_stops = max_stops,
                             service = service, demand = rep(0, length(nm)), capacity = Inf,
                             per_route = if (is.null(cost_model)) 0 else cost_model$per_route, per_travel = if (is.null(cost_model)) 1 else cost_model$per_travel,
                             time_limit = if (is.null(time_limit)) 5 else time_limit, seed = seed)
    for (k in seq_along(joint$routes)) base_of[match(joint$routes[[k]], units)] <- joint$base[k]
  } else if (assign == "balanced" && length(bases) > 1) {
    service <- service_vector(service_time, nm)
    # expected routes per base from a crude capacity: stops per route and length per route
    expected_routes <- function(b, us) {
      if (!length(us)) return(0)
      by_stops <- if (is.finite(max_stops)) ceiling(length(us) / max_stops) else 1
      by_length <- if (is.finite(max_length)) {
        # a nearest-neighbour chain is a cheap proxy of the tour length
        tour <- us[order(m[b, us])]; len <- m[b, tour[1]] + sum(m[cbind(tour[-length(tour)], tour[-1])]) + m[tour[length(tour)], b]
        ceiling((len + sum(service[match(us, nm)])) / max_length)
      } else 1
      max(by_stops, by_length)
    }
    capacity <- teams * days
    for (it in seq_len(length(units))) {
      load <- vapply(bases, function(b) expected_routes(b, units[base_of == b]), numeric(1))
      over <- bases[load > capacity]
      if (!length(over)) break
      best <- NULL
      for (i in which(base_of %in% over)) {
        for (b in setdiff(bases, base_of[i])) {
          if (expected_routes(b, c(units[base_of == b], units[i])) <= capacity[b]) {
            extra <- dist_to[i, b] - dist_to[i, base_of[i]]
            if (is.null(best) || extra < best$extra) best <- list(i = i, b = b, extra = extra)
          }
        }
      }
      if (is.null(best)) break
      base_of[best$i] <- best$b
    }
  }
  assignment <- tibble::tibble(unit = units, base = base_of)
  # routing per base and distribution over teams and days
  routes <- list(); cal <- list(); summ <- list(); cost <- 0
  for (b in bases) {
    us <- units[base_of == b]
    if (!length(us)) {
      summ[[b]] <- tibble::tibble(base = b, units = 0L, teams = unname(teams[b]), routes = 0L, days_needed = 0L, days_available = days, fits = TRUE)
      next
    }
    r <- route_fieldwork(matrix, units = us, depot = b, max_length = max_length, max_stops = max_stops,
                         service_time = service_time, iterations = iterations, time_limit = time_limit, alpha = alpha, seed = seed,
                         cost_model = cost_model, engine = engine)
    routes[[b]] <- r
    if (!is.null(r$cost)) cost <- cost + r$cost[["total"]]
    # longest-processing-time first over the teams of the base
    ord <- order(r$durations, decreasing = TRUE)
    team_days <- rep(0L, teams[b]); team_time <- rep(0, teams[b])
    rows <- lapply(ord, function(k) {
      t <- which.min(team_time)
      team_days[t] <<- team_days[t] + 1L; team_time[t] <<- team_time[t] + r$durations[k]
      tibble::tibble(base = b, team = paste0(b, "-", t), day = team_days[t], route = k, stops = length(r$routes$unit[r$routes$route == k]),
                     travel = r$lengths[k], duration = r$durations[k], units = list(r$routes$unit[r$routes$route == k]))
    })
    cal[[b]] <- do.call(rbind, rows)
    needed <- max(team_days)
    summ[[b]] <- tibble::tibble(base = b, units = length(us), teams = unname(teams[b]), routes = r$n_routes,
                                days_needed = needed, days_available = days, fits = needed <= days)
  }
  calendar <- if (length(cal)) do.call(rbind, cal) else tibble::tibble()
  if (nrow(calendar)) calendar <- calendar[order(calendar$base, calendar$team, calendar$day), ]
  summary <- do.call(rbind, summ[bases])
  structure(list(calendar = calendar, assignment = assignment, routes = routes, summary = summary,
                 fits = all(summary$fits), days = days, teams = teams, cost = if (is.null(cost_model)) NULL else cost, engine = engine,
                 cost_model = cost_model, travel_unit = attr(matrix, "unit"), coords = attr(matrix, "coords"),
                 method = attr(matrix, "method")), class = "fieldopt_schedule")
}

#' @export
print.fieldopt_schedule <- function(x, ...) {
  cli::cli_h1("Field schedule")
  cli::cli_text("{nrow(x$assignment)} unit{?s}, {length(x$teams)} base{?s}, {sum(x$teams)} team{?s}, {x$days} day{?s} available: {if (x$fits) 'the work fits' else 'the work does not fit'}.")
  for (i in seq_len(nrow(x$summary))) {
    s <- x$summary[i, ]
    cli::cli_text("{.val {s$base}}: {s$units} unit{?s}, {s$teams} team{?s}, {s$routes} route{?s}, {s$days_needed} of {s$days_available} day{?s}{if (!s$fits) ' (short of days)' else ''}.")
  }
  if (!is.null(x$cost)) cli::cli_text("Cost ({x$cost_model$currency}): {signif(x$cost, 4)}.")
  invisible(x)
}

#' @rdname routes-methods
#' @method tidy fieldopt_schedule
#' @export
tidy.fieldopt_schedule <- function(x, ...) {
  d <- x$calendar
  if (!nrow(d)) return(tibble::tibble(base = character(), team = character(), day = integer(), route = integer(), stop = integer(), unit = character()))
  do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    u <- d$units[[i]]
    tibble::tibble(base = d$base[i], team = d$team[i], day = d$day[i], route = d$route[i], stop = seq_along(u), unit = u)
  }))
}

#' @rdname routes-methods
#' @method glance fieldopt_schedule
#' @export
glance.fieldopt_schedule <- function(x, ...) {
  out <- tibble::tibble(units = nrow(x$assignment), bases = length(x$teams), teams = sum(x$teams), routes = nrow(x$calendar),
                        days_available = x$days, days_needed = if (nrow(x$summary)) max(x$summary$days_needed) else 0L,
                        fits = x$fits, travel = sum(x$calendar$travel), duration = sum(x$calendar$duration),
                        utilisation = if (nrow(x$calendar)) nrow(x$calendar) / (sum(x$teams) * x$days) else 0)
  if (!is.null(x$cost)) out$cost <- x$cost
  out
}

#' Plot a field schedule
#'
#' @param object A `fieldopt_schedule`.
#' @param ... Unused.
#' @return A ggplot of the routes of every base, coloured by team, with the
#'   bases marked.
#' @exportS3Method ggplot2::autoplot fieldopt_schedule
autoplot.fieldopt_schedule <- function(object, ...) {
  co <- object$coords
  pos <- function(u) co[match(u, co$unit), c("a", "b")]
  d <- object$calendar
  segs <- do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    r <- c(d$base[i], d$units[[i]], d$base[i]); p <- pos(r)
    data.frame(team = d$team[i], x = p$a[-nrow(p)], y = p$b[-nrow(p)], xend = p$a[-1], yend = p$b[-1])
  }))
  pts <- co[co$unit %in% object$assignment$unit, ]
  dep <- co[co$unit %in% names(object$teams), ]
  geo <- identical(object$method, "haversine")
  if (geo) {
    segs <- data.frame(team = segs$team, x = segs$y, y = segs$x, xend = segs$yend, yend = segs$xend)
    pts <- data.frame(a = pts$b, b = pts$a); dep <- data.frame(a = dep$b, b = dep$a, unit = dep$unit)
  }
  ggplot2::ggplot() +
    ggplot2::geom_segment(data = segs, ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend, colour = .data$team), linewidth = 0.6) +
    ggplot2::geom_point(data = pts, ggplot2::aes(x = .data$a, y = .data$b), size = 1.8) +
    ggplot2::geom_point(data = dep, ggplot2::aes(x = .data$a, y = .data$b), shape = 17, size = 3.5, colour = "#B4432B") +
    ggplot2::geom_text(data = dep, ggplot2::aes(x = .data$a, y = .data$b, label = .data$unit), vjust = -1, size = 3) +
    ggplot2::labs(x = if (geo) "longitude" else "x", y = if (geo) "latitude" else "y", colour = "team") +
    (if (geo) ggplot2::coord_quickmap() else ggplot2::coord_equal()) +
    ggplot2::theme_minimal() + ggplot2::theme(legend.position = "bottom")
}
