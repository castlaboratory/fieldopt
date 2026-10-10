# The average-cost fixed-point loops of fieldopt before 2026-10-10 (git e292350^:R/design.R),
# kept here so that procedure B of E2 stays reproducible after the package switched to the
# marginal routed cost. Identical code, renamed; they call the exported package functions.
average_two_stage_design <- 
function (frame, depot, cost_model, m_secondary, s2_between, 
    s2_within, target_variance = NULL, target_cv = NULL, budget = NULL, 
    mean = NULL, c1_start = NULL, max_iter = 6, size = NULL, 
    strata = NULL, selection = c("lpm", "systematic", "srs"), 
    matrix = NULL, method = c("haversine", "euclidean", "osrm"), 
    max_length = Inf, max_stops = Inf, n_rep = 5, iterations = 100, 
    seed = 1) 
{
    if (!inherits(cost_model, "field_cost_model")) 
        cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
    frame <- tibble::as_tibble(frame)
    if (!"unit" %in% names(frame) || !depot %in% frame$unit) 
        cli::cli_abort("{.arg frame} needs a column {.field unit} that contains {.val {depot}}.")
    n_primary <- nrow(frame) - 1L
    c2 <- cost_model$per_interview
    if (is.null(c1_start)) {
        method <- rlang::arg_match(method)
        if (is.null(matrix)) 
            matrix <- travel_matrix(frame, method = method)
        m <- unclass(matrix)
        d <- which(rownames(m) == depot)
        c1_start <- cost_model$per_unit + cost_model$per_travel * 
            stats::median(m[d, -d])
    }
    history <- list()
    c1 <- c1_start
    n_prev <- NA_integer_
    alloc <- NULL
    converged <- FALSE
    for (it in seq_len(max_iter)) {
        alloc <- two_stage_allocation(n_primary, m_secondary, 
            s2_between, s2_within, c1 = c1, c2 = c2, target_variance = target_variance, 
            target_cv = target_cv, budget = budget, mean = mean)
        history[[it]] <- tibble::tibble(round = it, c1 = c1, 
            n = alloc$n, m = alloc$m, cost = alloc$cost, variance_total = alloc$variance_total)
        if (identical(alloc$n, n_prev)) {
            converged <- TRUE
            break
        }
        n_prev <- alloc$n
        cm <- field_cost_model(per_travel = cost_model$per_travel, 
            per_unit = cost_model$per_unit, per_route = cost_model$per_route, 
            per_interview = 0, interviews_per_unit = 1, currency = cost_model$currency)
        ru <- routed_unit_cost(frame, depot, cm, n = alloc$n, 
            size = size, strata = strata, selection = selection, 
            matrix = matrix, method = method, max_length = max_length, 
            max_stops = max_stops, n_rep = n_rep, iterations = iterations, 
            seed = seed + it)
        c1 <- ru$cost_per_unit
    }
    alloc$c1 <- c1
    alloc$history <- do.call(rbind, history)
    alloc$converged <- converged
    alloc
}

average_dual_frame_design <- 
function (frame, depot, cost_model, domains, cost_b, deff_a = 1, 
    deff_b = 1, theta = NULL, target_variance = NULL, target_cv = NULL, 
    budget = NULL, interviews_per_unit = NULL, cost_a_start = NULL, 
    max_iter = 6, size = NULL, strata = NULL, selection = c("lpm", 
        "systematic", "srs"), matrix = NULL, method = c("haversine", 
        "euclidean", "osrm"), max_length = Inf, max_stops = Inf, 
    n_rep = 5, iterations = 100, seed = 1) 
{
    if (!inherits(cost_model, "field_cost_model")) 
        cli::cli_abort("{.arg cost_model} must come from {.fn field_cost_model}.")
    frame <- tibble::as_tibble(frame)
    if (!"unit" %in% names(frame) || !depot %in% frame$unit) 
        cli::cli_abort("{.arg frame} needs a column {.field unit} that contains {.val {depot}}.")
    if (!is.null(interviews_per_unit)) 
        cost_model$interviews_per_unit <- interviews_per_unit
    if (is.null(cost_a_start)) {
        method <- rlang::arg_match(method)
        if (is.null(matrix)) 
            matrix <- travel_matrix(frame, method = method)
        m <- unclass(matrix)
        d <- which(rownames(m) == depot)
        ipu <- if (is.function(cost_model$interviews_per_unit)) 
            1
        else mean(cost_model$interviews_per_unit)
        cost_a_start <- cost_model$per_unit + cost_model$per_interview * 
            ipu + cost_model$per_travel * stats::median(m[d, 
            -d])
    }
    history <- list()
    cost_a <- cost_a_start
    n_prev <- NA_integer_
    alloc <- NULL
    converged <- FALSE
    for (it in seq_len(max_iter)) {
        alloc <- dual_frame_allocation(domains, cost_a = cost_a, 
            cost_b = cost_b, deff_a = deff_a, deff_b = deff_b, 
            theta = theta, target_variance = target_variance, 
            target_cv = target_cv, budget = budget)
        history[[it]] <- tibble::tibble(round = it, cost_a = cost_a, 
            n_a = alloc$n_a, n_b = alloc$n_b, theta = alloc$theta, 
            cost = alloc$cost, variance = alloc$variance)
        if (identical(alloc$n_a, n_prev)) {
            converged <- TRUE
            break
        }
        n_prev <- alloc$n_a
        n_units <- min(alloc$n_a, nrow(frame) - 1L)
        ru <- routed_unit_cost(frame, depot, cost_model, n = n_units, 
            size = size, strata = strata, selection = selection, 
            matrix = matrix, method = method, max_length = max_length, 
            max_stops = max_stops, n_rep = n_rep, iterations = iterations, 
            seed = seed + it)
        cost_a <- ru$cost_per_unit
    }
    alloc$history <- do.call(rbind, history)
    alloc$converged <- converged
    alloc
}