# Summary method for preprocessing results

Compact per-variable roll-up of the diagnostics: one row per variable
with its mean spread and the number of subject-series that tripped each
stationarity flag. Use `x$diagnostics` for the full per-subject table.

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

A tidy per-variable `data.frame`.
