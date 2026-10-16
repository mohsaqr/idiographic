# Tidy tables from a within/between correlation comparison

Tidy tables from a within/between correlation comparison

## Usage

``` r
# S3 method for class 'idiographic_level_correlations'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("correlations", "summary"),
  ...
)
```

## Arguments

- x:

  A
  [`correlate_levels()`](https://pak.dynasite.org/idiographic/reference/correlate_levels.md)
  result.

- row.names, optional:

  Ignored.

- what:

  `"correlations"` (one row per correlation) or `"summary"` (one row per
  pair of variables, as
  [`summary()`](https://rdrr.io/r/base/summary.html)).

- ...:

  Ignored.

## Value

A `data.frame`.
