# Tidy tables of a rolling network result

Tidy tables of a rolling network result

## Usage

``` r
# S3 method for class 'rolling_var_result'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("estimates", "windows"),
  ...
)
```

## Arguments

- x:

  A `rolling_var_result` from
  [`fit_rolling_var()`](https://pak.dynasite.org/idiographic/reference/fit_rolling_var.md).

- row.names, optional:

  Ignored; part of the
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  generic.

- what:

  `"estimates"` (default) for one row per window and edge, or
  `"windows"` for one row per window with its subject, start and end.

- ...:

  Ignored.

## Value

A base `data.frame`. The failures of individual windows are returned by
[`failures()`](https://pak.dynasite.org/idiographic/reference/failures.md).
