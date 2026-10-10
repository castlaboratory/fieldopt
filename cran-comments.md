# fieldopt 0.1.0

First submission.

## Test environments

* local: macOS 26 (Apple Silicon), R 4.6, `R CMD check --as-cran`
* win-builder (R devel)
* CI (GitHub Actions): macOS-latest (R release), windows-latest (R release),
  ubuntu-latest (R devel, release, oldrel-1)

## R CMD check results

0 errors | 0 warnings | 1 note

* "New submission" (CRAN incoming feasibility). This is the first release.
  The words flagged as possibly misspelled are proper nouns and the package
  name (Hartley's, Horvitz, fieldopt).

## Notes for the reviewers

* The package has a Rust component, following the CRAN policy "Using Rust in
  CRAN packages": `SystemRequirements` names Cargo and rustc (>= 1.70), the
  versions of both are reported at configure time, the Rust sources of all
  crates are vendored in `src/rust/vendor.tar.xz` (0.6 MB) and compiled
  offline with `cargo build --offline -j 2`; nothing is downloaded during the
  installation. The crates and their authors and licences are listed in
  `inst/AUTHORS` and acknowledged in `Authors@R`. The computational crate
  `fieldopt-core` (0.6.0) is written by the package authors and published on
  crates.io. The R wrappers of the Rust functions are shipped in the package
  (`R/extendr-wrappers.R`); the installation runs a single `cargo build`.
* Examples run in under two seconds each; the only `\dontrun{}` example
  queries a public routing server (the `osrm` package, in Suggests). The test
  that queries that server is skipped on CRAN; the connector is otherwise
  tested with a mocked `osrm::osrmTable()`.
* The four vignettes build in about 15 seconds together.
