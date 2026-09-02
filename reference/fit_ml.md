# Fit person-specific machine-learning models

`fit_ml()` supports both historical `idiographic` calls using
`outcome`/`predictors` and the consolidated panel-model API using
`y`/`x`. Calls that name `y` or `x` use the consolidated result
contract; existing positional and `outcome`/`predictors` calls retain
their original behavior.

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

  Arguments passed to the selected implementation.

- y, x:

  Consolidated outcome and predictor selectors. Supply both.

## Value

An `idioml_result` for historical calls or an `idiographic_fit` for
consolidated `y`/`x` calls.
