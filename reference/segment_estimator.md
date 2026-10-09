# Segment estimators of a total from an area sample of segments

The three classical ways to attribute establishments to the segments of
an area frame (Houseman 1975; Nealon 1984):

## Usage

``` r
segment_estimator(tracts, sample, type = c("closed", "open", "weighted"))
```

## Arguments

- tracts:

  Data frame with one row per (segment, establishment) pair: `unit`
  (segment), `establishment`, and, as needed, `y_tract` (value inside
  the segment, for `"closed"`), `y_total` (value of the whole
  establishment, for `"open"` and `"weighted"`), `headquarters`
  (logical, headquarters inside the segment, for `"open"`) and `share`
  (fraction of the establishment's land inside the segment, for
  `"weighted"`).

- sample:

  The `fieldopt_sample` of segments.

- type:

  `"closed"`, `"open"` or `"weighted"`.

## Value

A one-row tibble as in
[`design_variance()`](https://castlaboratory.github.io/fieldopt/reference/design_variance.md)
with a column `type`.

## Details

- `"closed"`: each segment reports what lies inside it (the tracts);

- `"open"`: each establishment is attributed entirely to the segment
  that holds its headquarters;

- `"weighted"`: each establishment is attributed to every segment it
  touches in proportion to the share of its land inside the segment.

The segment totals are then expanded with the segment design.

## References

Nealon, J. P. (1984). Review of the multiple and area frame estimators.
USDA Statistical Reporting Service, Staff Report 80.
