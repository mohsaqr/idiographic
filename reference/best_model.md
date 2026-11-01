# Best overall model row

Best overall model row

## Usage

``` r
best_model(x, scope = NULL, ...)
```

## Arguments

- x:

  An idiographic fit.

- scope:

  Optional scope filter.

- ...:

  Ignored.

## Value

A one-row `data.frame` with the columns of
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md):
the `.overall` row with the lowest `rmse` (regression) or the highest
`accuracy` (classification).

## Examples

``` r
fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day", model = c("mean", "ridge"))
best_model(fit)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 4 individual ridge    native .overall     .all 1150 17.22461 12.86903 0.7960435
#>   r_squared
#> 4 0.5888967
best_model(fit, scope = "pooled")
#>    scope model estimator  subject subgroup    n     rmse      mae      bias
#> 2 pooled ridge    native .overall     .all 1150 20.18719 16.28609 0.7323493
#>   r_squared
#> 2  0.435318
```
