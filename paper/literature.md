# Literature review: survey design under routed fieldwork cost

Deliverable of `PLANO.md` §1 (phase 1), companion of `paper/formulacao.md` §11.
Version 2026-10-10. Web searches (general engines, publisher pages, arXiv,
Statistics Canada, institutional repositories); no Scopus or Web of Science
access. Each entry says how it was checked: **read** (full text read for the
point cited), **abstract** (abstract or publisher record only), **cited**
(known only through another paper that was read). An entry must reach **read**
before the manuscript leans on it.

## 1. Verdict on novelty

| Claim in `formulacao.md` / E1 / E2 | Status after the review |
|---|---|
| Travel to `n` scattered units grows like `√(nA)` (BHH), so the primary-unit cost is `a n + b √n` | **Classical, and older than BHH.** Hansen, Hurwitz and Madow (1953, Vol. II, ch. 6 §11, read) already put a between-cluster travel term proportional to `√n` in the two-stage cost model; Cochran (1977, §5.5) cites Beardwood et al. for a `t_h √n_h` travel term in stratified sampling and then sets it aside. |
| Cochran's `m*` holds with the **marginal** cost `G'(n)` in place of `c1`, and must be solved iteratively (§5.1) | **Classical, confirmed in the source.** HHM Vol. II eq. 11.9 has `(C_0/2√m) + C_1` where the linear model has `C_1`, and the optimum is found by iteration with a convergence proof (Tepping and Skalak). Writing it as "Cochran with the marginal cost" is our presentation. Credit HHM. |
| Stratified allocation with a `√n_h` travel term | **Published**, first by HHM (Vol. II, ch. 7 §7b, travel varying by stratum), later as mathematical programming: Ghufran, Khowaja and Ahsan (2012) and companions; Varshney et al. (2012). Travel parameters are taken as given constants. |
| Non-linear cost in two-stage allocation | **Published** in general form: Koh (1999), cost `c1 n^p + c2 n^p m^q`. |
| Travel models with positioning trips (stems to a home base) change the optimum | **Published** with a stylised geometry: Kalsbeek, Mendoza and Budescu (1983), interviewers at the centre of square subareas with clusters on concentric circles; the optimum takes 2–60 % fewer clusters than the linear model. |
| `G(n)` **measured by routing** the sampled units (multi-depot, daily limits, fleet, per-route cost) on real frames, and the BHH form checked on it, including daily routes (E2) | **Not found.** All cost models found are closed forms on idealised geometry, or per-location cost surfaces (Brus et al. 2019), or paradata regressions (Wagner and Olson 2018). |
| Size of the error of a guessed constant `c1` against the routed cost (E2, "level error") | **Not found** as such. Kalsbeek et al. (1983) compare cost models with each other, not with routed costs. |
| Travel penalty of **spatially balanced** samples (lpm, systematic) against srs, and the comparison **at equal routed budget** (E1) | **Not found.** Spatially balanced designs are compared at equal sample size (Grafström et al. 2012; Räty et al. 2020; Heikkinen et al. 2025, who assume cost proportional to the number of clusters). Cost-aware spatial designs either cluster on purpose (Heikkinen et al. 2025), penalise distance during sequential selection (Jauslin et al. 2022) or optimise a model-based design under logistics with an integer program (Okasaki et al. 2023); none measures the routed price of spreading a probability sample. |
| Dual-frame (Hartley) allocation with a routed area-frame cost | **Not found.** |

**Consequence for the article.** The theoretical core of §5.1 is HHM's, and
the manuscript must say so in the first paragraph that states it. What is new
is operational and empirical: (i) the routed cost curve as the input of the
classical allocation, estimated by solving the actual routing problem with
depots, daily limits and fleets, with its BHH form verified on real frames;
(ii) the measurement of how far guessed unit costs miss it; (iii) the routed
price of spatial balance and the equal-budget rule (E1); (iv) the same
machinery for dual-frame allocation; (v) open software that makes the HHM
model usable. This fits Survey Methodology or JOS as an applied-methods paper
("HHM revisited with routing"), or JSSAM; it is not a theory paper. The
equal-budget result of E1 is the strongest single claim and should lead.

## 2. Matrix

### 2.1 Travel cost in sample design (the HHM line)

| Reference | Check | What it does | Relation to fieldopt |
|---|---|---|---|
| Hansen, Hurwitz and Madow (1953). *Sample Survey Methods and Theory*, Vol. I: Methods and Applications, ch. 6 §10–19 (pp. 271–293), ch. 9. Wiley. | read (OCR of the scan, 2026-10-10) | §11–12 derive the travel between psu's from `m` points on a regular grid in area `A`: spacing `√(A/m)`, total route `≈ √(mA)` (constant 1, the lattice); call-backs add `√(0.5mA) + √(0.25mA) + …` ("8.3√m" in the example). §13: travel from home or office to the psu's (our stems) enters as a proportional uplift on the daily interviewer cost. §14: parking and waiting go into `C_1`, not `C_0`. §15: worked example `3500 = 13.4√m + 2.7m + 1.2mn̄`. §18: the iterative optimum ("for proof, due to B. J. Tepping and Blanche Skalak, see Vol. II"). Ch. 9: with large psu's, travel between psu's "amounts to nearly half the total cost". The authors call the travel model "a very rough approximation": psu's "will not be uniformly distributed over an area, rates of travel will vary with roads … and the travel in practice will not be done by visiting all sample segments successively"; work that ends each day removes trips between psu's. They also note that "moderate departures from the optimum survey design usually increase only slightly the rel-variance". | **The motivation of the article in the authors' own words**: the √m model is an idealisation of exactly what routing computes (non-uniform frames, roads, daily returns to base). Their lattice constant 1 matches our lpm `β̂` of 0.88–0.97 (E2), and random points give BHH's 0.71: a spread sample sits on HHM's assumption, a random one below it. Their remark on flat optima agrees with E2: the shape error (B against C) is small, the level error (a wrong `C_0`, `C_1`) is what costs. **Gap they model and we do not**: call-backs (repeat visits to a fraction of the units), which add `√` terms; candidate extension (route the revisit subsets). |
| Mahalanobis (1940, 1946); Marks (1948), A lower bound for the expected travel among m random points, *Ann. Math. Stat.* 19, 419–422; Ghosh (1949), Expected travel among random points in a region, *Calcutta Stat. Assn. Bull.* 6, 83–87; McCreary (1950), Cost functions for sample surveys, thesis, Iowa State. | cited (HHM ch. 6 references) | Early results on the expected travel among random points and survey cost functions, the source of HHM's `√m` term. | Cite as the origin of the travel term, with BHH for the constant. Ghosh and Marks to be read. |
| Beardwood, Halton and Hammersley (1959). The shortest path through many points. *Proc. Cambridge Phil. Soc.* 55, 299–327. | cited | Tour length through `n` uniform points in area `A` is `≈ β√(nA)`. | The law behind `G(n)`; E2 estimates `β` and the exponent on real frames. |
| Hansen, Hurwitz and Madow (1953). *Sample Survey Methods and Theory*, Vol. II: Theory, ch. 6 §10–11 (pp. 172–175), ch. 7 §7, ch. 9. Wiley. | read (OCR of the scan, 2026-10-10) | Ch. 6 §11: simple two-stage design with cost `C = C_0 √m + C_1 m + C_2 m n̄` (m primary units, n̄ expected cluster size). The Lagrange conditions give the optimum n̄ with `(C_0 / 2√m) + C_1` in place of `C_1` (eq. 11.9), i.e. the marginal cost; the fixed-cost solution is found by iterating between n̄ and `a = √m` (eq. 11.1–11.3, the cost equation is a quadratic in `√m`), and the same for a fixed precision (eq. 11.4); convergence proved by Tepping and Skalak (footnote). Ch. 7 §7a: stratified two-stage with an added travel term `C_0 √m`; §7b: travel varying by stratum, `C = Σ C_0h √m_h + Σ C_1h m_h + Σ C_2h m_h n̄_h` (eq. 7.16). Ch. 9 (large psu's): travel within psu's as a separate cost term. The `√m` travel term rests on Mahalanobis (1940, 1946), Marks (1948) and Ghosh (1949), before Beardwood et al. (1959). | **Prior art for §5.1, confirmed.** Our `G(n) = c_0 + a n + b √n` is HHM's cost with `b = C_0` and `a = C_1`, and our marginal-cost loop is their iteration. What fieldopt adds is the *estimate* of `C_0` and `C_1` by routing the actual sample (depots, daily limits, fleets) instead of the uniform-random-points assumption, and the dual-frame and spatial-balance extensions. Present the method as "estimating HHM's travel constant by routing". |
| Cochran (1977). *Sampling Techniques*, 3rd ed., §5.5. Wiley. | read (OCR of the section) | "If travel costs between units are substantial … better represented by the expression Σ t_h √n_h … (Beardwood et al., 1959). Only the linear cost function (5.17) is considered here." | The travel term is acknowledged and set aside in the standard text; motivates making it operational. |
| Kalsbeek, Mendoza and Budescu (1983). Cost models for optimum allocation in multi-stage sampling. *Survey Methodology* 9(2), 156–?. | read | Adds positioning travel (home base to first cluster and back) and follow-up visits to HHM, on a stylised geometry (square subareas, concentric circles); optimum `n` 2.4–60 % lower and `m` 7.6–198 % higher than the linear model. | Closest prior work in the target journal. Our routed `G(n)` replaces their geometry; their stems are our depots and daily routes. Note the opposite direction of the error against our naive `c1` (theirs under-counts travel, ours over-counts it): the sign depends on how `c1` was guessed, which is the point of measuring it. |
| Ghufran, Khowaja and Ahsan (2012). Optimum multivariate stratified sampling designs with travel cost: a multiobjective integer nonlinear programming approach. *Comm. Stat. Sim. Comp.* 41(5), 598–610. doi:10.1080/03610918.2011.598995 | abstract | Stratified allocation with Cochran's `c_h n_h + t_h √n_h`, solved by integer NLP. | Same cost form, travel constants assumed; no routing. |
| Ghufran, Khowaja, Najmussehar and Ahsan (2011/2012). A multiple response stratified sampling design with travel cost. *South Pacific J. Nat. Appl. Sci.* 29(1), 31–39. | abstract | As above, multiple responses. | Same. |
| Varshney, Najmussehar and Ahsan (2012). Estimation of more than one parameters in stratified sampling with fixed budget. *Math. Methods Oper. Res.* 75(2), 185–197. | abstract | Fixed-budget allocation with travel cost. | Same family. |
| Koh (1999). Optimal allocations in two-stage cluster sampling. *Korean Communications in Statistics* (KoreaScience JAKO199911920520535). | abstract | Two-stage cost `c1 n^p + c2 n^p m^q`; uniqueness and monotonicity in `p`. | General non-linear two-stage cost; `p = ½` for travel is a special case of ours only for the travel part. |
| Brus, Yang and Zhu (2019). Accounting for differences in costs among sampling locations in optimal stratification. *Eur. J. Soil Sci.* 70. doi:10.1111/ejss.12731 | abstract | Per-location cost surface in optimal stratification (simulated annealing); variance 8–29 % lower than cum √f. | Costs vary by location but are additive; ours are not additive (route). |
| Wagner and Olson (2018). An analysis of interviewer travel and field outcomes in two field surveys. *JOS* 34(1). doi:10.1515/jos-2018-0010 | abstract | Paradata of NSFG and HRS: segments visited per interviewer-day strongly associated with outcomes; miles travelled not. | Supports per-route and per-visit costs as first-order terms in `G(n)` (our `per_route`, `per_unit`); a caution against travel-only cost models. Cites Kalsbeek et al. (1983) and Biemer and Stokes (1985). |
| Olson, Wagner and Anderson (2021). Survey costs: where are we and what is the way forward? *JSSAM* 9(5), 921–942. | abstract | Review of survey cost modelling; interviewer travel within PSUs is a key input. | Positioning reference for the introduction. To read. |

### 2.2 Spatially balanced sampling

| Reference | Check | What it does | Relation to fieldopt |
|---|---|---|---|
| Stevens and Olsen (2004). Spatially balanced sampling of natural resources. *JASA* 99, 262–278. | cited | GRTS. | Alternative balanced design; not in E1. |
| Grafström, Lundström and Schelin (2012). Spatially balanced sampling through the pivotal method. *Biometrics* 68, 514–520. | cited | LPM. | Design used in E1. |
| Grafström and Lundström (2013). Why well spread probability samples are balanced. *Open J. Stat.* 3, 36–41. | abstract | Well-spread samples are approximately balanced; HT good for Lipschitz targets. | Theory for the E1 variance gain. |
| Grafström and Tillé (2013). Doubly balanced spatial sampling with spreading and restitution of auxiliary totals. *Environmetrics* 24, 120–131. | cited | Cube + spread. | `select_units(method = "cube")` relative. |
| Grafström and Schelin (2014). How to select representative samples. *Scand. J. Stat.* 41, 277–290. | cited | Local-mean variance estimator. | `design_variance()` under lpm. |
| Dickson and Tillé (2016). Ordered spatial sampling by means of the traveling salesman problem. *Comput. Stat.* 31(4), 1359–1372. doi:10.1007/s00180-015-0635-1 | abstract | Orders units along a TSP tour, then systematic sampling: spatial spread through a tour. | Uses the TSP for **selection**, not for cost; our systematic design uses a Hilbert curve. A TSP-ordered systematic sample may also have short routes: candidate for E1b. |
| Räty, Kuronen, Myllymäki, Kangas, Mäkisara and Heikkinen (2020). Comparison of the local pivotal method and systematic sampling for national forest inventories. *For. Ecosyst.* 7, 54. doi:10.1186/s40663-020-00266-9 | abstract | LPM vs systematic at equal n: neither uniformly better; Grafström–Schelin estimator usable. | Consistent with E1 (lpm and systematic interchangeable). |
| Jauslin, Panahbehagh and Tillé (2022). Sequential spatially balanced sampling. *Environmetrics* 33(8), e2776. doi:10.1002/env.2776 | abstract | Sequential selection, equal or unequal probabilities, spatial balance. | A web summary mentions a cost penalising distance to the current unit; not confirmed in the abstract. To read. |
| Heikkinen, Henttonen, Katila and Tuominen (2025). Stratified, spatially balanced cluster sampling for cost-efficient environmental surveys. *Environmetrics* 36(5), e70019. doi:10.1002/env.70019 | read | Finnish NFI: clusters of plots for one day's work; stratified LPM, GRTS, SYS; "we assumed that measurement costs are directly proportional to the number of clusters"; designs compared at equal sample size. | **Closest recent work.** Cost per cluster constant, so the travel price of spreading the clusters is not counted; E1 is the missing piece. Also argues clustering vs balance as opposite levers. |
| Benedetti, Piersimoni and Postiglione (2015). *Sampling Spatial Units for Agricultural Surveys*. Springer. | abstract (table of contents) | Reference book for spatial and area-frame designs; chapters on spatial designs and on sample size and allocation. | No cost or travel chapter visible; check the allocation chapter before citing. |

### 2.3 Optimisation with logistics, routing and field work

| Reference | Check | What it does | Relation to fieldopt |
|---|---|---|---|
| Okasaki, Tóth and Berdahl (2023). Optimal sampling design under logistical constraints with mixed integer programming. arXiv:2302.05553. | read (sections on designs and logistics) | MILP that chooses sites under budget and logistics (helicopter bases, fuel per distance) for a Bayesian regression model; states that SRS, GRTS and BAS "take no account of logistical or budgetary constraints". | Model-based and purposive; ours keeps probability designs and puts logistics in the cost. Good foil for the introduction. Not found in a journal. |
| Daganzo (1984). The distance traveled to visit N points with a maximum of C stops per vehicle. *Transp. Sci.* 18(4), 331–350. doi:10.1287/trsc.18.4.331 | abstract | Analytic approximation of fleet travel: stems to the depot plus local travel; checked against near-optimal tours. | Basis of §3 (daily routes restore a linear term). Formula to be read from the paper. |
| Vidal (2022). Hybrid genetic search for the CVRP: open-source implementation and SWAP* neighborhood. *Comput. Oper. Res.* 140, 105643. | cited | HGS. | Solver reference. |
| Prins (2004). A simple and effective evolutionary algorithm for the VRP. *Comput. Oper. Res.* 31, 1985–2002. | cited | Split. | Solver reference. |
| Castillo-Salazar, Landa-Silva and Qu (2012/2016). Workforce scheduling and routing problems: literature survey. *Ann. Oper. Res.* 239. | abstract | WSRP survey (home care, technicians). | Interviewer scheduling is a WSRP; time windows are out of scope (§9). |
| Lister et al. (2022); Westfall et al. (2016); Scott (1991); Henttonen and Kangas (2015) | abstract | Forest-inventory cluster plot design with walking and driving time, overnight thresholds. | Same trade-off at the plot-cluster scale; cite one as the forestry analogue. |

## 3. To read before writing (in order)

1. ~~Hansen, Hurwitz and Madow (1953), Vols. I and II~~ read on 2026-10-10 (Vol. I ch. 6 §10–19 and ch. 9; Vol. II ch. 6 §10–11 and ch. 7 §7). Still to read: Ghosh (1949) and Marks (1948).
2. Kalsbeek et al. (1983): full derivation (have the PDF; OCR in the session scratchpad).
3. Daganzo (1984): the formula used in §3.
4. Heikkinen et al. (2025): full text read for the cost assumption; reread the design comparison.
5. Jauslin et al. (2022): whether the sequential method has a travel-cost term.
6. Olson, Wagner and Anderson (2021) and Wagner and Olson (2018): cost modelling context.
7. Benedetti et al. (2015), allocation chapter; Gallego's area-frame guidelines (JRC 2015) for segment-size cost practice.
8. A targeted search in Survey Methodology, JOS and JSSAM indexes (2000–2026) for "travel cost", "interviewer travel", "routing", with library access.

## 4. Changes made to the project after this review

- `formulacao.md` §5.1 and §11: HHM credited for the `√n` model and the iterative optimum; novelty restated as in §1 above.
- `two_stage_design()` documentation: reference to Hansen, Hurwitz and Madow (1953) added.
