//! R bindings of `fieldopt-core`. Every function takes plain vectors, uses
//! 0-based indices, validates nothing beyond what the core validates, and
//! returns plain vectors or lists; the R side owns the data frames and the
//! classes.

use extendr_api::prelude::*;
use fieldopt_core::{
    allocate_for_budget, allocate_for_variance, allocate_multivariate, cube, dual_frame_allocation, euclidean_matrix,
    haversine_matrix, hilbert_order, ht_total, inclusion_probabilities, local_mean_variance,
    local_pivotal, spatial_balance, srs_variance, systematic_replicates, two_stage_for_budget, two_stage_for_variance,
    Domain, DualFrame, GraspOptions, Matrix, RouteLimits, Stratum, Target, TwoStage,
};
use fieldopt_core::routing::{solve_fleet, Fleet};

fn err<T>(r: std::result::Result<T, String>) -> extendr_api::Result<T> {
    r.map_err(Error::Other)
}

fn to_bools(l: &Logicals) -> Vec<bool> {
    l.iter().map(|b| b.is_true()).collect()
}

/// Travel matrix from coordinates: `method` is "haversine" (lat, lon in
/// degrees, kilometres) or "euclidean". Returns the row-major n x n vector.
/// @noRd
#[extendr]
fn travel_matrix_rs(a: &[f64], b: &[f64], method: &str) -> extendr_api::Result<Vec<f64>> {
    let m = match method {
        "haversine" => err(haversine_matrix(a, b))?,
        "euclidean" => err(euclidean_matrix(a, b))?,
        other => return Err(Error::Other(format!("unknown method {other}"))),
    };
    Ok(m.as_slice().to_vec())
}

/// Routing. `matrix` is the row-major n x n travel matrix; `depots` and
/// `units` are 0-based indices; `routes_available` has one entry per depot (negative for no
/// limit); `fixed_cost` is the cost of a route in travel units; `service` and `demand` have
/// one entry per node (or none).
/// @noRd
#[extendr]
fn route_rs(matrix: &[f64], n: i32, depots: &[i32], routes_available: &[f64], fixed_cost: f64, units: &[i32], service: &[f64],
            demand: &[f64], max_length: f64, max_stops: f64, capacity: f64, iterations: i32, time_limit: f64, certify_time: f64,
            alpha: f64, seed: f64) -> extendr_api::Result<List> {
    let m = err(Matrix::from_vec(n as usize, matrix.to_vec()))?;
    let units: Vec<usize> = units.iter().map(|&u| u as usize).collect();
    let fleet = Fleet {
        depots: depots.iter().map(|&d| d as usize).collect(),
        routes_available: routes_available.iter().map(|&k| if k.is_finite() && k >= 0.0 { k as usize } else { usize::MAX }).collect(),
        fixed_cost,
    };
    let limits = RouteLimits {
        max_length: if max_length.is_finite() { max_length } else { f64::INFINITY },
        max_stops: if max_stops.is_finite() { max_stops as usize } else { usize::MAX },
        capacity: if capacity.is_finite() { capacity } else { f64::INFINITY },
    };
    let options = GraspOptions { iterations: iterations as usize, time_limit: if time_limit.is_finite() { time_limit } else { f64::INFINITY },
                                 certify_time: if certify_time.is_finite() && certify_time > 0.0 { certify_time } else { 0.0 }, alpha, seed: seed as u64 };
    let sol = err(solve_fleet(&m, &fleet, &units, service, demand, limits, options))?;
    let routes: Vec<Robj> = sol.routes.iter().map(|r| r.iter().map(|&u| u as i32).collect::<Vec<i32>>().into()).collect();
    Ok(list!(
        routes = List::from_values(routes),
        route_depots = sol.route_depots.iter().map(|&d| d as i32).collect::<Vec<i32>>(),
        lengths = sol.lengths,
        durations = sol.durations,
        loads = sol.loads,
        total = sol.total,
        lower_bound = sol.lower_bound,
        optimal = sol.optimal,
        best_iteration = sol.best_iteration as i32
    ))
}

/// Size-proportional inclusion probabilities summing to `n`.
/// @noRd
#[extendr]
fn inclusion_probabilities_rs(size: &[f64], n: i32) -> extendr_api::Result<Vec<f64>> {
    err(inclusion_probabilities(size, n as usize))
}

/// Local pivotal method 2 on an n x d row-major coordinate matrix.
/// @noRd
#[extendr]
fn local_pivotal_rs(coords: &[f64], d: i32, pi: &[f64], seed: f64) -> extendr_api::Result<Vec<bool>> {
    err(local_pivotal(coords, d as usize, pi, seed as u64))
}

/// Horvitz-Thompson total.
/// @noRd
#[extendr]
fn ht_total_rs(y: &[f64], pi: &[f64], sampled: Logicals) -> extendr_api::Result<f64> {
    let s = to_bools(&sampled);
    err(ht_total(y, pi, &s))
}

/// Local-mean variance estimator of the Horvitz-Thompson total.
/// @noRd
#[extendr]
fn local_mean_variance_rs(coords: &[f64], d: i32, y: &[f64], pi: &[f64], sampled: Logicals, k: i32) -> extendr_api::Result<f64> {
    let s = to_bools(&sampled);
    err(local_mean_variance(coords, d as usize, y, pi, &s, k.max(1) as usize))
}

/// Simple-random-sampling variance of the total.
/// @noRd
#[extendr]
fn srs_variance_rs(y: &[f64], sampled: Logicals, big_n: i32) -> extendr_api::Result<f64> {
    let s = to_bools(&sampled);
    err(srs_variance(y, &s, big_n as usize))
}

/// Cost-aware allocation: `mode` is "variance" (target variance) or "budget".
/// @noRd
#[extendr]
fn allocate_rs(size: &[i32], sd: &[f64], cost: &[f64], target: f64, mode: &str) -> extendr_api::Result<List> {
    if size.len() != sd.len() || size.len() != cost.len() {
        return Err(Error::Other("size, sd and cost must have the same length".into()));
    }
    let strata: Vec<Stratum> = (0..size.len()).map(|h| Stratum { size: size[h].max(0) as usize, sd: sd[h], cost: cost[h] }).collect();
    let a = match mode {
        "variance" => err(allocate_for_variance(&strata, target))?,
        "budget" => err(allocate_for_budget(&strata, target))?,
        other => return Err(Error::Other(format!("unknown mode {other}"))),
    };
    Ok(list!(
        n = a.n.iter().map(|&v| v as i32).collect::<Vec<i32>>(),
        cost = a.cost,
        variance = a.variance,
        bounded = a.bounded
    ))
}

/// Order of the units (0-based) along a Hilbert curve; `coords` is n x 2 row-major.
/// @noRd
#[extendr]
fn hilbert_order_rs(coords: &[f64], bits: i32) -> extendr_api::Result<Vec<i32>> {
    let o = err(hilbert_order(coords, bits as u32))?;
    Ok(o.into_iter().map(|v| v as i32).collect())
}

/// Systematic PPS sampling along `order` (0-based) as independent replicates;
/// returns the n x r indicator matrix, row-major.
/// @noRd
#[extendr]
fn systematic_replicates_rs(order: &[i32], pi: &[f64], replicates: i32, seed: f64) -> extendr_api::Result<Vec<bool>> {
    let o: Vec<usize> = order.iter().map(|&v| v as usize).collect();
    err(systematic_replicates(&o, pi, replicates as usize, seed as u64))
}

/// Hartley dual-frame allocation. `theta` < 0 means optimise.
/// @noRd
#[extendr]
#[allow(clippy::too_many_arguments)]
fn dual_frame_rs(size: &[i32], mean: &[f64], sd: &[f64], cost_a: f64, cost_b: f64, deff_a: f64, deff_b: f64,
                 theta: f64, target: f64, mode: &str) -> extendr_api::Result<List> {
    if size.len() != 3 || mean.len() != 3 || sd.len() != 3 {
        return Err(Error::Other("size, mean and sd must describe the three domains a, ab, b".into()));
    }
    let dom = |h: usize| Domain { size: size[h].max(0) as usize, mean: mean[h], sd: sd[h] };
    let f = DualFrame { a: dom(0), ab: dom(1), b: dom(2), cost_a, cost_b, deff_a, deff_b };
    let t = match mode {
        "variance" => Target::Variance(target),
        "budget" => Target::Budget(target),
        other => return Err(Error::Other(format!("unknown mode {other}"))),
    };
    let th = if theta < 0.0 { None } else { Some(theta) };
    let a = err(dual_frame_allocation(&f, th, t))?;
    Ok(list!(
        n_a = a.n_a as i32, n_b = a.n_b as i32, theta = a.theta, cost = a.cost, variance = a.variance,
        variance_a = a.variance_a, variance_b = a.variance_b, overlap_a = a.overlap_a, overlap_b = a.overlap_b,
        bounded = a.bounded
    ))
}

/// Two-stage allocation; `target` is a variance of the mean ("variance") or a budget.
/// @noRd
#[extendr]
fn two_stage_rs(n_primary: i32, m_secondary: f64, s2_between: f64, s2_within: f64, c1: f64, c2: f64,
                target: f64, mode: &str) -> extendr_api::Result<List> {
    let t = TwoStage { n_primary: n_primary.max(0) as usize, m_secondary, s2_between, s2_within, c1, c2 };
    let a = match mode {
        "variance" => err(two_stage_for_variance(&t, target))?,
        "budget" => err(two_stage_for_budget(&t, target))?,
        other => return Err(Error::Other(format!("unknown mode {other}"))),
    };
    Ok(list!(n = a.n as i32, m = a.m as i32, m_optimal = a.m_optimal, cost = a.cost,
             variance_mean = a.variance_mean, variance_total = a.variance_total, bounded = a.bounded))
}

/// Voronoi measure of spatial balance on an n x d row-major coordinate matrix.
/// @noRd
#[extendr]
fn spatial_balance_rs(coords: &[f64], d: i32, pi: &[f64], sampled: Logicals) -> extendr_api::Result<f64> {
    err(spatial_balance(coords, d as usize, pi, &to_bools(&sampled)))
}

/// Cube sampling balanced on the n x p row-major matrix `x`.
/// @noRd
#[extendr]
fn cube_rs(x: &[f64], p: i32, pi: &[f64], seed: f64) -> extendr_api::Result<Vec<bool>> {
    err(cube(x, p as usize, pi, seed as u64))
}

/// Multivariate allocation: `sd` is H x J row-major, `targets` one variance per variable.
/// @noRd
#[extendr]
fn allocate_multi_rs(size: &[i32], cost: &[f64], sd: &[f64], targets: &[f64]) -> extendr_api::Result<List> {
    let sizes: Vec<usize> = size.iter().map(|&v| v.max(0) as usize).collect();
    let a = err(allocate_multivariate(&sizes, cost, sd, targets))?;
    Ok(list!(
        n = a.n.iter().map(|&v| v as i32).collect::<Vec<i32>>(),
        cost = a.cost,
        attained = a.attained,
        bounded = a.bounded,
        multipliers = a.multipliers
    ))
}

/// Version of the engine crate.
/// @noRd
#[extendr]
fn core_version_rs() -> &'static str {
    fieldopt_core::VERSION
}

extendr_module! {
    mod fieldopt;
    fn travel_matrix_rs;
    fn route_rs;
    fn inclusion_probabilities_rs;
    fn local_pivotal_rs;
    fn ht_total_rs;
    fn local_mean_variance_rs;
    fn srs_variance_rs;
    fn allocate_rs;
    fn hilbert_order_rs;
    fn systematic_replicates_rs;
    fn dual_frame_rs;
    fn two_stage_rs;
    fn spatial_balance_rs;
    fn cube_rs;
    fn allocate_multi_rs;
    fn core_version_rs;
}
