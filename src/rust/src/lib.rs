//! R bindings of `fieldopt-core`. Every function takes plain vectors, uses
//! 0-based indices, validates nothing beyond what the core validates, and
//! returns plain vectors or lists; the R side owns the data frames and the
//! classes.

use extendr_api::prelude::*;
use fieldopt_core::{
    allocate_for_budget, allocate_for_variance, dual_frame_allocation, euclidean_matrix, grasp_routes,
    haversine_matrix, hilbert_order, ht_total, inclusion_probabilities, local_mean_variance, local_pivotal,
    srs_variance, systematic_replicates, two_stage_for_budget, two_stage_for_variance, Domain, DualFrame,
    GraspOptions, Matrix, RouteLimits, Stratum, Target, TwoStage,
};

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

/// GRASP routing. `matrix` is the row-major n x n travel matrix; `depot` and
/// `units` are 0-based indices.
/// @noRd
#[extendr]
fn route_rs(matrix: &[f64], n: i32, depot: i32, units: &[i32], max_length: f64, max_stops: f64, iterations: i32, alpha: f64, seed: f64) -> extendr_api::Result<List> {
    let m = err(Matrix::from_vec(n as usize, matrix.to_vec()))?;
    let units: Vec<usize> = units.iter().map(|&u| u as usize).collect();
    let limits = RouteLimits {
        max_length: if max_length.is_finite() { max_length } else { f64::INFINITY },
        max_stops: if max_stops.is_finite() { max_stops as usize } else { usize::MAX },
    };
    let options = GraspOptions { iterations: iterations as usize, alpha, seed: seed as u64 };
    let sol = err(grasp_routes(&m, depot as usize, &units, limits, options))?;
    let routes: Vec<Robj> = sol.routes.iter().map(|r| r.iter().map(|&u| u as i32).collect::<Vec<i32>>().into()).collect();
    Ok(list!(
        routes = List::from_values(routes),
        lengths = sol.lengths,
        total = sol.total,
        lower_bound = sol.lower_bound,
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
fn local_mean_variance_rs(coords: &[f64], d: i32, y: &[f64], pi: &[f64], sampled: Logicals) -> extendr_api::Result<f64> {
    let s = to_bools(&sampled);
    err(local_mean_variance(coords, d as usize, y, pi, &s))
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
fn two_stage_rs(n_primary: i32, m_secondary: i32, s2_between: f64, s2_within: f64, c1: f64, c2: f64,
                target: f64, mode: &str) -> extendr_api::Result<List> {
    let t = TwoStage { n_primary: n_primary.max(0) as usize, m_secondary: m_secondary.max(0) as usize,
                       s2_between, s2_within, c1, c2 };
    let a = match mode {
        "variance" => err(two_stage_for_variance(&t, target))?,
        "budget" => err(two_stage_for_budget(&t, target))?,
        other => return Err(Error::Other(format!("unknown mode {other}"))),
    };
    Ok(list!(n = a.n as i32, m = a.m as i32, m_optimal = a.m_optimal, cost = a.cost,
             variance_mean = a.variance_mean, variance_total = a.variance_total, bounded = a.bounded))
}

/// Version of the engine crate.
/// @noRd
#[extendr]
fn core_version_rs() -> &'static str {
    env!("CARGO_PKG_VERSION")
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
    fn core_version_rs;
}
