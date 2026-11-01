# Tidy model metrics

Tidy model metrics

## Usage

``` r
metrics(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = NULL,
  overall = FALSE,
  sort_by = NULL,
  decreasing = FALSE,
  by = c("person", "fold"),
  ...
)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n:

  Optional number of rows to return.

- overall:

  Logical. If `TRUE`, return only overall rows.

- sort_by:

  Optional metric/column to sort by.

- decreasing:

  Sort order when `sort_by` is supplied.

- by:

  Summarise by person (default) or separately within each rolling fold.

- ...:

  Ignored.

## Value

A `data.frame` with one row per scope, model, estimator and person
(columns `scope`, `model`, `estimator`, `subject`, `subgroup`, `n`),
plus one `.overall` row per model that pools all held-out occasions.
Regression fits report `rmse`, `mae`, `bias` and `r_squared`;
classification fits report `accuracy`, `brier` and `log_loss`. With
`by = "fold"`, rolling fits add a `fold` column and report each fold
separately.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
metrics(fit, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    native .overall     .all 1150 22.15170 18.16606 0.5861259
#> 2 individual    lm    native .overall     .all 1150 19.22193 14.95209 0.4451146
#>   r_squared
#> 1 0.3200665
#> 2 0.4880281

# The five learners the person-specific model predicts worst.
metrics(fit, scope = "individual", sort_by = "rmse", decreasing = TRUE,
        n = 5)
#>        scope model estimator subject subgroup  n     rmse      mae       bias
#> 1 individual    lm    native    Erik    .none 32 29.73167 26.93958  0.8066997
#> 2 individual    lm    native   Frank    .none 32 28.54220 25.28387  0.8046534
#> 3 individual    lm    native     Eve    .none 32 27.67821 23.65575 -5.5625396
#> 4 individual    lm    native    Yuki    .none 32 24.56427 21.67633  0.6466954
#> 5 individual    lm    native   Layla    .none 30 24.49670 17.99006  3.7420751
#>    r_squared
#> 1 0.35044875
#> 2 0.01234187
#> 3 0.34040623
#> 4 0.09619659
#> 5 0.07071314
```
