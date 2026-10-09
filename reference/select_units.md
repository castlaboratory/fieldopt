# Select units with a spatially balanced or systematic probability sample

Draws a probability sample of the units of a frame (segments, grid
cells, establishments) with equal or size-proportional inclusion
probabilities, within strata when given, by one of three methods:

## Usage

``` r
select_units(
  frame,
  n,
  size = NULL,
  coords = NULL,
  strata = NULL,
  method = c("lpm", "systematic", "srs", "cube"),
  replicates = 1,
  seed = 1,
  balance = NULL
)
```

## Arguments

- frame:

  Data frame with one row per unit: coordinate columns (`lat`, `lon` or
  `x`, `y`, or those named in `coords`), an optional `size` column, an
  optional `unit` column with names and an optional stratum column.

- n:

  Sample size: a single number (allocated to strata in proportion to the
  sum of `size`, or to the number of units when `size` is `NULL`), or a
  vector named by stratum.

- size:

  Column of the size measure for probability-proportional-to-size
  selection, or `NULL` for equal probabilities within stratum.

- coords:

  Names of the coordinate columns used for spatial balance (any number
  of columns for `"lpm"`; exactly two for `"systematic"`).

- strata:

  Column with the stratum of each unit, or `NULL`.

- method:

  `"lpm"`, `"systematic"`, `"srs"` or `"cube"` (balanced sampling by the
  cube method of Deville and Tillé 2004, with the fast flight phase and
  landing by suppression of variables).

- replicates:

  Number of independent interpenetrating replicates for `"systematic"`
  (each a systematic sample of about `n / replicates` units; replicates
  may share units). Ignored by the other methods.

- seed:

  Seed.

- balance:

  For `"cube"`: names of the columns to balance on (the inclusion
  probabilities are always included, so the sample size is fixed). The
  Horvitz-Thompson estimates of these columns match their population
  totals as closely as the landing allows.

## Value

The frame as a tibble with columns `pi` (inclusion probability in the
union of the replicates) and `sampled`, of class `fieldopt_sample`, with
attributes `n`, `coords`, `strata`, `method`, `seed` and, for replicated
systematic samples, `replicates` (a logical matrix, one column per
replicate) and `pi_replicate` (inclusion probability within one
replicate).

## Details

- `"lpm"`: the local pivotal method (Grafström, Lundström and Schelin,
  2012), which spreads the sample over the coordinate space so that
  nearby units are rarely selected together;

- `"systematic"`: systematic sampling with probabilities proportional to
  size along a Hilbert curve through the coordinates (a spatially
  ordered systematic sample), drawn as `replicates` independent
  interpenetrating systematic samples so that a design-based variance
  can be estimated;

- `"srs"`: simple random sampling without replacement.

Spatial balance reduces the variance of totals of spatially structured
variables and, at the same time, spreads the field work; the cost model
and the routing make that tension explicit.

## References

Grafström, A., Lundström, N. L. P. and Schelin, L. (2012). Spatially
balanced sampling through the pivotal method. *Biometrics*, 68(2),
514–520.

## Examples

``` r
set.seed(1)
cells <- expand.grid(x = 1:20, y = 1:20)
cells$unit <- paste0("c", seq_len(nrow(cells)))
cells$intensity <- cut(cells$x + rnorm(400, sd = 3), c(-Inf, 7, 14, Inf),
                       c("low", "mid", "high"))
cells$size <- c(low = 1, mid = 2, high = 4)[cells$intensity]
s <- select_units(cells, n = c(low = 10, mid = 15, high = 25), size = "size",
                  strata = "intensity")
table(s$intensity, s$sampled)
#>       
#>        FALSE TRUE
#>   low    116   10
#>   mid    129   15
#>   high   105   25
r <- select_units(cells, n = 40, method = "systematic", replicates = 4)
dim(attr(r, "replicates"))
#> [1] 400   4
```
