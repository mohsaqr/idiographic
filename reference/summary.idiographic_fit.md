# Summarise a consolidated fit

Summarise a consolidated fit

## Usage

``` r
# S3 method for class 'idiographic_fit'
summary(object, ...)

# S3 method for class 'idiostats_fit'
summary(object, ...)
```

## Arguments

- object:

  A consolidated `idiographic_fit`.

- ...:

  Filters passed to
  [`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md).

## Value

The `data.frame` of
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md):
one row per scope, model, estimator and person, plus `.overall` rows.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
summary(fit, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    native .overall     .all 1150 22.15170 18.16606 0.5861259
#> 2 individual    lm    native .overall     .all 1150 19.22193 14.95209 0.4451146
#>   r_squared
#> 1 0.3200665
#> 2 0.4880281
```
