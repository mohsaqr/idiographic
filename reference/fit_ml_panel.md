# Fit machine learning with the consolidated scoped result contract

`fit_ml_panel()` is the unambiguous positional entry point for code
migrated from `idiostats`. It always returns the consolidated scoped
result used by
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md),
[`tuning()`](https://pak.dynasite.org/idiographic/reference/tuning.md),
and the result-view functions. Named
`fit_ml(data, y = ..., x = ..., id = ...)` calls are equivalent.

## Usage

``` r
fit_ml_panel(data, y, x, id, ...)
```

## Arguments

- data:

  A data frame or matrix.

- y:

  Outcome column name.

- x:

  Predictor selector.

- id:

  Person identifier column.

- ...:

  Consolidated ML controls; see
  [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md).

## Value

An `idiographic_fit` retaining the `idiostats_fit` compatibility class.

## Examples

``` r
fit <- fit_ml_panel(srl, "effort", "efficacy:monitoring", "name",
                    time = "day", scope = "pooled", model = "ridge")
metrics(fit, overall = TRUE)
#>    scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1 pooled ridge    native .overall     .all 1150 20.18719 16.28609 0.7323493
#>   r_squared
#> 1  0.435318
```
