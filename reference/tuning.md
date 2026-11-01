# Tuning results

Tuning results

## Usage

``` r
tuning(x, model = NULL, scope = NULL, subject = NULL, n = NULL, ...)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n:

  Optional number of rows.

- ...:

  Ignored.

## Value

A `data.frame` with one row per scope, model, person and candidate
setting: `scope`, `model`, `estimator`, `subject`, `subgroup`,
`parameter`, `value`, `n` (validation rows), the validation metrics
`rmse`, `mae`, `accuracy` and `brier`, and `rank` (1 = selected). It has
no rows when the fit was not tuned.

## Examples

``` r
fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day", scope = "pooled", model = "knn", tune = TRUE)
tuning(fit)
#>    scope model estimator  subject subgroup parameter value   n     rmse
#> 1 pooled   knn    native .overall     .all         k     1 899 13.58116
#> 2 pooled   knn    native .overall     .all         k     3 899 16.51403
#> 3 pooled   knn    native .overall     .all         k     5 899 18.83511
#> 4 pooled   knn    native .overall     .all         k     7 899 19.82245
#> 5 pooled   knn    native .overall     .all         k    15 899 20.26371
#> 6 pooled   knn    native .overall     .all         k     9 899 20.26697
#>         mae accuracy brier rank
#> 1  5.140692       NA    NA    1
#> 2 10.832807       NA    NA    2
#> 3 14.141548       NA    NA    3
#> 4 15.301335       NA    NA    4
#> 5 15.803694       NA    NA    5
#> 6 15.785908       NA    NA    6
```
