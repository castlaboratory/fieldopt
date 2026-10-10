# Formulation: survey design under routed fieldwork cost

Working note of the `fieldopt` plan (deliverable of `PLANO.md` §1, phase 1; gate G0).
Version 2026-10-10. This note fixes the objects, the cost model, the design problems,
the decision rules and the operational choices of the package. Anything the package
implements must trace back to a paragraph here; anything changed here must be logged
in `memory/NOTES.md`. Experiment E2 (`experiments/e2_allocation_cost.md`) tests §5
and §6; experiment E1 tests §4.

## 1. Objects

**Frame and travel.** A finite population `U = {1, …, N}` of units (cells of an area
frame, enumeration areas, holdings) with coordinates, and a set of bases
`D = {d_1, …, d_K}` (offices, depots). A travel matrix `t(i, j) ≥ 0` over `U ∪ D` gives
the travel time (or distance) between any two places; it is symmetric unless it comes
from a road network. The package builds it by haversine or euclidean distance with a
detour factor and a speed, or from OSRM.

**Design and estimator.** A sampling design `p(s)` over subsets `s ⊂ U` with inclusion
probabilities `π_i > 0`. A study variable `y_i` and its Horvitz–Thompson total
`Ŷ = Σ_{i ∈ s} y_i / π_i`, with design variance `V_p(Ŷ)`. The designs in scope are
simple random sampling (srs), stratified srs, systematic sampling along a space-filling
curve, the local pivotal method (lpm) and the cube method, all with or without
stratification and with or without interpenetrating replicates.

**Field work.** Visiting the sample means: leaving a base, travelling between units,
spending a service time `τ_i` at each unit (`m` interviews of duration `τ` each), and
returning to a base, subject to a daily limit `L` on route duration, a limit on stops
and a vehicle capacity. The set of routes that visits `s` is a vehicle routing problem
with several depots; its minimum total travel is

    T(s) = min { Σ_r travel(r) : routes r partition s, each from and to a base, each within L }.

`T(s)` is a set function of `s`. It is not additive over units: the travel attributable
to unit `i` depends on which other units were drawn and how far they are from each other
and from the bases.

## 2. Cost model

The cost of a sample `s` with `n = |s|` units and `m` interviews per unit is

    C(s, m) = c_0 + c_route · R(s) + c_travel · T(s) + c_unit · n + c_int · n · m,   (2.1)

where `R(s)` is the number of routes (days) the solution uses, `c_route` the fixed cost
of a route (a vehicle-day), `c_travel` the cost per minute (or km) of travel, `c_unit`
the fixed cost of a visit and `c_int` the cost of one interview. In the package this is
`field_cost_model()` and `C(s, m)` is `cost(routes, model)`.

**Expected cost of a design.** Because `s` is random, the cost of a design `p` at size
`n` is the expectation `E_p[C(s, m)]`, estimated by Monte Carlo over `R` samples with
the routing solved for each (`cost_variance_frontier()`, `routed_unit_cost()`). Two
sources of noise enter: sampling (`s` varies) and the solver (a heuristic with a gap of
at most about one percent on the benchmarks). The first dominates; `R` between ten and
twenty samples gives the mean cost within a few percent.

**Average and marginal cost per unit.** Write the primary-unit part of (2.1) as

    G_p(n) = E_p[ c_route · R(s) + c_travel · T(s) ] + c_unit · n,   |s| = n.

The *average* cost per unit is `c̄_1(n) = G_p(n) / n` and the *marginal* cost is
`G_p'(n)`. The classical allocation theory assumes `G(n) = c_1 n`, so that the two
coincide. Under routing they do not (§3), and the difference is the object of this
note.

## 3. Shape of the routed cost

**One tour (no daily limit).** If `s` is `n` points drawn uniformly at random in a
region of area `A`, the Beardwood–Halton–Hammersley law gives the length of the optimal
tour, `T(s) ≈ β √(nA)` with `β ≈ 0.7124`, for large `n`. With the fixed cost per unit
the primary cost is

    G(n) ≈ c_travel · β √(nA) + c_unit · n,   c̄_1(n) = c_travel β √(A/n) + c_unit,   G'(n) = ½ c_travel β √(A/n) + c_unit.   (3.1)

The travel part of the marginal cost is *half* the travel part of the average cost:
each additional unit lengthens the tour by less than the average unit costs, because the
tour was already passing nearby.

**Spatially balanced samples.** For points spread as evenly as possible (a lattice with
spacing `√(A/n)`), the tour visits neighbours in turn and `T ≈ 1.0 · √(nA)`. A balanced
design such as lpm or the cube method with spatial balancing therefore sits between the
two constants: its travel is longer than that of srs at the same `n` by a factor
`ρ ∈ [1, 1/0.7124 ≈ 1.40]`, the price of balance. The reduction in variance from
balance is the spatial design effect `deff_sp = V_lpm / V_srs < 1`, which depends on the
spatial autocorrelation of `y`. Whether balance pays is the comparison of the two
(§5.3).

**Daily routes.** With a duration limit `L` the solution uses `R ≈ ⌈(T(s) + n τ) / L⌉`
routes, each adding a stem from and to its base of about `2 d̄`, where `d̄` is the mean
base-to-unit travel. Daganzo's approximation for capacitated routing,
`T ≈ 2 d̄ R + 0.57 √(nA)`, says the cost regains a linear term in `n` through the number
of routes. Hence: the nonlinearity of (3.1) is strongest when the field work fits in a
few long routes, and weakens as the daily limit tightens. The classical model with the
*right* `c_1` becomes approximately correct again; what it still gets wrong is the
level of `c_1`, which no simple guess (median base-to-unit travel, say) recovers.

**Several bases.** With `K` bases and a joint assignment of units to bases, `d̄` is the
mean travel to the nearest base, which falls with `K`; the fixed cost per base is added
to `c_0`. The number and the location of the bases are design variables (§5.4).

## 4. Spatial balance and travel (object of E1)

For a given frame and `n`, the quantities to measure are the expected travel
`E_p[T(s)]` and the variance `V_p(Ŷ)` for `p ∈ {srs, lpm, cube, systematic}`, giving the
ratio `ρ(n) = E_lpm[T] / E_srs[T]` and `deff_sp(n)`. The fit of `log E_p[T]` on `log n`
estimates the exponent (½ under BHH, for one tour) and the constant `β_p`. E1 reports
`ρ(n)`, `β_p` and `deff_sp(n)` on real frames, with and without daily limits.

## 5. Design problems

### 5.1 Two-stage allocation with routed cost (object of E2)

Cochran's problem: choose `n` primary units and `m` secondary units in each to minimise

    V(n, m) = S_1² / n + S_2² / (n m)

subject to `E C ≤ B` (or minimise `E C` subject to `V ≤ V_0`), with the expected cost

    E C(n, m) = c_0 + G_p(n) + c_int · n · m.

With `G(n) = c_1 n` the solution is Cochran's `m* = √(c_1 S_2² / (c_2 S_1²))`,
`c_2 = c_int`. With a general `G`, the Lagrange conditions give

    m*(n) = √( G_p'(n) · S_2² / (c_2 · S_1²) ),   (5.1)

the classical formula with the *marginal* primary cost in place of `c_1`, and `n` from
the budget `G_p(n) + c_2 n m*(n) = B` (or from the variance target). Under (3.1),
`G'(n)` falls with `n`, so `m*` is smaller and `n` larger than the classical solution
evaluated at the average routed cost.

Three procedures are therefore distinct: (A) the classical allocation with a guessed
constant `c_1`; (B) the fixed-point loop that re-estimates `c̄_1(n)` by routing and
re-allocates, the current `two_stage_design()`; (B') the same loop with `G'(n)`; and
(C) the optimum on the full routed curve `G_p(n)`. E2 measures A, B and B' against C.
The conjecture is that A errs in level (wrong `c_1`), B in shape (average for
marginal), and B' is within the Monte Carlo noise of C.

### 5.2 Dual-frame allocation with routed cost (object of E2)

Hartley's problem for an area frame A (sampled by `p`, cost `G_p(n_a)`) and a list
frame B (cost `c_b n_b`) with overlap domain `ab` and mixing parameter `θ`: minimise the
variance of the dual-frame estimator subject to `G_p(n_a) + c_b n_b ≤ B`, over
`(n_a, n_b, θ)`. The classical solution with constant `c_a` is in
`dual_frame_allocation()`; the same substitution of `G_p'(n_a)` for `c_a` applies in
the first-order conditions, and the same three procedures A, B, B' are compared to C.
The screening variant (`θ = 0`, overlap units counted only from the list) changes the
variance, not the cost structure.

### 5.3 Choice of design at fixed budget

For a budget `B`, each design `p` reaches a size `n_p(B)` by solving `E C_p(n) = B`, and
a variance `V_p(n_p(B))`. Balance is preferred when

    deff_sp(n_lpm) · n_srs / n_lpm < 1,   with n_lpm < n_srs because ρ > 1.

The frontier `F_p = {(E C_p(n), V_p(n)) : n}` is the decision object
(`cost_variance_frontier()`, `autoplot()`); it is a Monte Carlo estimate, and its
sampling error is the subject of a later note (link with `paretoinfer`).

### 5.4 Teams, days and bases

Given `n` and the units, the schedule problem assigns units to bases and days under the
limits `L`, with `K_k` teams at base `k` and `D` days; `schedule_fieldwork()` solves it
as one multi-depot problem with a fleet cap and reports a shortfall when the fleet is
too small. Choosing `K` and the bases is a design decision that moves `d̄` and `c_0`;
it enters the frontier as an outer loop over fleet configurations, not as part of the
allocation formulas.

## 6. Decision rules (gates)

**G1 (is there a methodological paper).** Passes if, on at least one real frame and
one realistic cost model, procedure A misses the oracle C by 10 % or more in realised
cost at a fixed variance target, or in realised variance at a fixed budget, and the
error is not removed by any constant `c_1` (that is, it is a shape error, not a level
error). Passes with a weaker claim if only the level error is large: then the
contribution is the loop B' and the measurement of `c_1`, a note rather than an
article. Fails if A and C agree within 5 % across the factorial of E2: then the
classical allocation with a routed `c_1` is enough and the package is the contribution.

**G2 (is balance worth its travel).** Decided by E1: report the region of
`(deff_sp, ρ)` where lpm wins at equal budget, on real frames.

*Outcome of E1 (2026-10-10, `experiments/e1_spatial_balance.md`).* The travel
ratio ρ is 1.07–1.15 at small n and 1.01–1.09 at large n, so at equal budget a
balanced design affords 90–97 % of the srs sample size; it wins whenever
`deff_sp` is below that ratio. With spatial correlation over more than a few
cells (`deff_sp` 0.4–0.8) it wins in 98–100 % of the cases and cuts the variance
by a third to a half; without correlation it loses 1–9 % (worst 18 %). G2
passes: balance is worth its travel for spatially structured variables.

## 7. Estimation and inference

- Variance under lpm and cube: the local-mean estimator (Grafström–Schelin); under
  systematic sampling with `r` interpenetrating replicates: the between-replicate
  estimator with `r − 1` degrees of freedom; under stratified srs: the usual one. All in
  `design_variance()` and exported to `survey` through `as_svydesign()`.
- Dual-frame totals: Hartley, screening and Fuller–Burmeister, with covariances from
  the replicate or linearised variances of each frame (`dual_frame_estimator()`).
- Point sampling in cells with multiplicity: expected hits and the point estimator
  (`expected_hits()`, `point_estimator()`), with a Monte Carlo design effect
  (`point_design_effect()`).
- Cost: Monte Carlo mean over `R` routed samples, with its standard error; the solver
  reports a lower bound and, for one tour, a certificate of optimality within a time
  limit.

## 8. Operational choices of the package (what is implemented)

| Paragraph | Function | Note |
|---|---|---|
| §1 travel | `travel_matrix()` | haversine, euclidean, OSRM; bases; detour and speed |
| §1 designs | `select_units()`, `select_points()` | srs, stratified, systematic (Hilbert), lpm, cube; replicates |
| §2 cost | `field_cost_model()`, `cost()` | per route, travel, unit, interview |
| §2 routing | `route_fieldwork()`, `schedule_fieldwork()`, `schedule_calendar()` | HGS with penalties, exact to 13 units, certificate; multi-depot; ILP calendar |
| §2 expected cost | `cost_variance_frontier()`, `routed_unit_cost()` | Monte Carlo over `R` samples |
| §5.1 | `two_stage_allocation()`, `two_stage_design()` | classical; loop with the marginal cost of the fitted curve `c0 + a n + b √n` (since 2026-10-10, after E2) |
| §5.2 | `dual_frame_allocation()`, `dual_frame_design()` | Hartley with optimal or screening θ; loop with the marginal cost |
| §5.3 | `cost_variance_frontier()`, `autoplot()` | frontier by design |
| §7 | `design_variance()`, `dual_frame_estimator()`, `ratio_estimator()`, `as_svydesign()` | |

## 9. Assumptions and limits

1. Planning values `S_1²`, `S_2²`, domain means and variances are known or taken from a
   pilot; the note does not treat their uncertainty.
2. Travel times are deterministic and symmetric; no time windows; service time is the
   same at every unit, or given per unit.
3. The routing solver is heuristic: costs are upper bounds on the optimum, within about
   one percent on the benchmarks, and the same solver is used for every procedure, so
   comparisons are fair even if levels are slightly high.
4. `m` is the same in every primary unit; unequal `m_i` and size measures enter only
   through the selection probabilities.
5. The dual-frame cost of the list frame is linear; routed cost applies to the area
   frame only.
6. Nothing here treats panel rotation, nonresponse or measurement error.

## 10. What E1 and E2 must answer

- E2: the relative errors of A, B, B' against C in `n`, `m`, realised cost (target CV)
  and realised variance (budget), by frame, selection, daily limit and `S_2²/S_1²`; the
  fitted exponent and `β̂` of the travel curve; the level error `c̄_1(n_C)/c_1^{naive}`.
- E1: `ρ(n)`, `deff_sp(n)` and the region where balance wins, on real frames.
- Both: whether the daily limit restores linearity (§3), which decides how much of the
  paper is about shape and how much about level.

## 11. Literature to position against (to verify before writing)

Each entry must be read and its claim checked before it is cited; the list is a plan,
not a bibliography.

- Beardwood, Halton and Hammersley (1959), the tour-length law; Steele (1997) for the
  modern statement and constants.
- Daganzo (1984), distance travelled to visit `N` points with at most `C` per vehicle:
  the stem-plus-local approximation used in §3.
- Cochran (1977), chapter 10, two-stage allocation with linear cost; Hansen, Hurwitz
  and Madow (1953) for the same with field costs.
- Hartley (1962, 1974), Lohr and Rao (2000, 2006), Fuller and Burmeister (1972):
  dual-frame estimation and allocation.
- Grafström, Lundström and Schelin (2012), the local pivotal method; Deville and Tillé
  (2004), the cube method; Grafström and Schelin (2014), the local-mean variance
  estimator; Stevens and Olsen (2004), GRTS.
- Dickson and Tillé (2016), ordered spatial sampling by the travelling salesman
  problem: the closest existing link between routing and selection, in the opposite
  direction (route first, then sample along it).
- Benedetti, Piersimoni and Postiglione (2015), *Sampling Spatial Units for
  Agricultural Surveys*: the reference book for area frames and spatial designs in
  agriculture; check whether travel cost is treated and how.
- Vidal (2022), hybrid genetic search for the CVRP; Prins (2004), the split
  procedure; Held and Karp (1970), the 1-tree bound. Solver references only.
- Survey cost modelling with travel: search Survey Methodology, JOS and JSSAM for
  "travel cost", "interviewer travel", "cluster sampling travel" (2000–2026) before
  claiming novelty for §5.1.
