# Fit person-specific machine-learning models

`fit_ml()` supports both historical `idiographic` calls using
`outcome`/`predictors` and the consolidated panel-model API using
`y`/`x`. Calls that name `y` or `x`, or that pass a consolidated control
such as `time`, `scope`, `subgroup` or `tune`, use the consolidated
result contract; existing positional and `outcome`/`predictors` calls
retain their original behaviour.

## Usage

``` r
fit_idiographic_ml(
  data,
  outcome,
  predictors,
  id,
  day = NULL,
  beep = NULL,
  task = c("auto", "regression", "classification"),
  model = NULL,
  estimator = NULL,
  compare = c("both", "individual", "pooled"),
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  lambda = 1,
  alpha = 0.5,
  k = 5L,
  n_components = NULL,
  max_iter = 100L,
  tol = 1e-06,
  standardize = TRUE,
  keep_fits = FALSE,
  ...
)

fit_individualized_ml(
  data,
  outcome,
  predictors,
  id,
  day = NULL,
  beep = NULL,
  task = c("auto", "regression", "classification"),
  model = NULL,
  estimator = NULL,
  compare = c("both", "individual", "pooled"),
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  lambda = 1,
  alpha = 0.5,
  k = 5L,
  n_components = NULL,
  max_iter = 100L,
  tol = 1e-06,
  standardize = TRUE,
  keep_fits = FALSE,
  ...
)

fit_ml(
  data,
  outcome,
  predictors,
  id,
  day = NULL,
  beep = NULL,
  task = c("auto", "regression", "classification"),
  model = NULL,
  estimator = NULL,
  compare = c("both", "individual", "pooled"),
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  lambda = 1,
  alpha = 0.5,
  k = 5L,
  n_components = NULL,
  max_iter = 100L,
  tol = 1e-06,
  standardize = TRUE,
  keep_fits = FALSE,
  ...,
  y,
  x
)
```

## Arguments

- data:

  A data frame or matrix.

- outcome, predictors:

  Historical `idiographic` outcome and predictor arguments.

- id:

  Person identifier column.

- day, beep:

  Optional historical ordering columns.

- task:

  Outcome task: `"auto"`, `"regression"`, or `"classification"`.

- model:

  One or more model names.

- estimator:

  Optional implementation backend.

- compare:

  Historical scope selector: `"both"`, `"individual"`, or `"pooled"`.

- test_prop:

  Proportion of each person's ordered rows used for testing.

- min_train, min_test:

  Minimum training and test rows.

- lambda, alpha:

  Penalized-model controls.

- k:

  Number of neighbours for nearest-neighbour models.

- n_components:

  Number of principal components for the historical API.

- max_iter, tol:

  Iteration limit and convergence tolerance.

- standardize:

  Use training-only predictor standardization?

- keep_fits:

  Retain fitted backend objects?

- ...:

  Arguments passed to the selected implementation; in the consolidated
  interface, the controls listed in Details.

- y, x:

  Consolidated outcome and predictor selectors. Supply both.

## Value

For consolidated calls, an `idiographic_fit` (also of class
`idiostats_fit`). Its tables are read with accessors:
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md)
(one row per scope, model, estimator and person, plus `.overall` rows,
with `rmse`, `mae`, `bias` and `r_squared` for regression),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
(one row per held-out occasion and model),
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md),
[`importance()`](https://pak.dynasite.org/idiographic/reference/importance.md),
[`tuning()`](https://pak.dynasite.org/idiographic/reference/tuning.md)
and
[`failures()`](https://pak.dynasite.org/idiographic/reference/failures.md).

For historical calls, an `idioml_result`.
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
its held-out predictions,
[`summary()`](https://rdrr.io/r/base/summary.html) its metrics (one row
per `model_scope`, model, estimator and person),
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md) its
coefficients (one row per `model_scope`, model, person and term) and
[`predict()`](https://rdrr.io/r/stats/predict.html) predictions for new
rows.

## Details

Both interfaces evaluate prediction on an ordered hold-out: the last
`ceiling(test_prop * n)` rows of each person are the test set and are
never used for estimation. In the consolidated interface, `tune = TRUE`
carves a further validation block (`valid_prop`) from the tail of the
training rows, scores the candidate settings on it, and refits the
winning setting on the training and validation rows before predicting
the test rows.

Consolidated controls passed through `...` are `time` (ordering column),
`scope` (`"pooled"`, `"subgroup"`, `"individual"`, `"both"` or `"all"`),
`subgroup` (as in
[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)),
`valid_prop`, `ncomp` (`pcr`), `mtry` and `num_trees` (`forest`), `cost`
(`svm`), `tune` and `grid` (a named list of tuning grids, e.g.
`list(knn = list(k = c(3, 5)))`).
[`models()`](https://pak.dynasite.org/idiographic/reference/models.md)
lists every model name with its estimator, package and tuned parameter.
Native models need only base R. When an optional backend package is
missing, an interactive session offers to install it after confirmation;
otherwise the call stops with an error that names the package.

## Examples

``` r
# Consolidated interface: pooled and person-specific models, tidy results.
fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day", scope = "both", model = c("mean", "ridge"))
metrics(fit, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled  mean    native .overall     .all 1150 26.88010 22.50530 0.9244965
#> 2 individual  mean    native .overall     .all 1150 22.62189 17.84407 0.9032171
#> 3     pooled ridge    native .overall     .all 1150 20.18719 16.28609 0.7323493
#> 4 individual ridge    native .overall     .all 1150 17.22461 12.86903 0.7960435
#>      r_squared
#> 1 -0.001184303
#> 2  0.290895607
#> 3  0.435318032
#> 4  0.588896681
best_model(fit)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 4 individual ridge    native .overall     .all 1150 17.22461 12.86903 0.7960435
#>   r_squared
#> 4 0.5888967

# Tune the number of neighbours on a validation block before testing.
tuned <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
                time = "day", scope = "pooled", model = "knn", tune = TRUE)
tuning(tuned)
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

# Historical interface (outcome, predictors, id).
legacy <- fit_ml(srl, "effort", c("efficacy", "planning"), "name",
                 model = "ridge")
legacy
#> Idiographic Machine-Learning Result
#>   Task:          regression
#>   Algorithms:    1 (ridge)
#>   Outcome:       effort
#>   Predictors:    2 (efficacy, planning)
#>   Subjects:      36
#>   Predictions:   2300
#>   individual/ridge[native] RMSE:   17.8653
#>   pooled/ridge[native] RMSE:   20.8727
#>   Tables:        as.data.frame(x) | summary(x) | coefs(x)
```
