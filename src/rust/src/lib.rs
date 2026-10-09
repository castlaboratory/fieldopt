//! R bindings of `fieldopt-core`. Every function takes plain vectors, uses
//! 0-based indices, validates nothing beyond what the core validates, and
//! returns plain vectors or lists; the R side owns the data frames and the
//! classes.

use extendr_api::prelude::*;
use fieldopt_core::{
    allocate_for_budget, allocate_for_variance, euclidean_matrix, grasp_routes, haversine_matrix, ht_total,
    inclusion_probabilities, local_mean_variance, local_pivotal, srs_variance, GraspOptions, Matrix, RouteLimits,
    Stratum,
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
    fn core_version_rs;
}
