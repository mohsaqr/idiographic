# Summary method for preprocessing results

Compact per-variable roll-up of the diagnostics: one row per variable
with its mean spread and the number of subject-series that tripped each
stationarity flag. `as.data.frame(x)` returns the full per-subject
table.

## Usage

``` r
# S3 method for class 'preprocess_result'
summary(object, ...)
```

## Arguments

- object:

  A `preprocess_result` object.

- ...:

  Ignored.

## Value

A `data.frame` with one row per variable: `variable`, `n_series`
(subject-series), `mean_sd`, and the counts `n_trend`, `n_high_ar`,
`n_unit_root` and `n_flagged` (series with any stationarity risk).
