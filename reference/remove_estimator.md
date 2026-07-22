# Remove a registered estimator

Remove a registered estimator

## Usage

``` r
remove_estimator(method, missing_ok = FALSE)
```

## Arguments

- method:

  A registered method name or alias. Names are case-insensitive; spaces,
  hyphens, and periods are normalized to underscores.

- missing_ok:

  Logical. If `TRUE`, silently do nothing when `method` is not
  registered.

## Value

Invisibly returns the removed registration, or `NULL` when
`missing_ok = TRUE` and no registration exists.

## Examples

``` r
temp_fitter <- function(data, ...) data
register_estimator("temporary", temp_fitter)
remove_estimator("temporary")
remove_estimator("temporary", missing_ok = TRUE)
```
