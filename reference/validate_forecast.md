# Validate one-step forecasts from idiographic VAR models (experimental)

**Experimental.** The rolling-origin design follows standard time-series
cross-validation practice, but unlike the estimators in this package it
has no external reference implementation to validate against, and its
interface, defaults, and reported metrics may change in a future
release.

Performs rolling-origin one-step prediction from
[`build_var()`](https://mohsaqr.github.io/idiographic/reference/build_var.md)
or
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md).
Each split fits the estimator on earlier blocks and predicts current
variables in the next block from their lag-1 values. Scaling and
within-person centering parameters are learned from the training split
only, then applied to the assessment split before prediction.

## Usage

``` r
validate_forecast(
  data,
  vars,
  estimator = c("var", "graphical_var"),
  id = NULL,
  day = NULL,
  beep = NULL,
  initial = NULL,
  assess = 1L,
  step = 1L,
  n_splits = NULL,
  block_size = NULL,
  scale = TRUE,
  center_within = TRUE,
  delete_missings = TRUE,
  keep_fits = FALSE,
  ...
)
```

## Arguments

- data:

  A `data.frame` or matrix with columns for variables and optional
  id/day/beep columns.

- vars:

  Character vector of variable names.

- estimator:

  `"var"` for
  [`build_var()`](https://mohsaqr.github.io/idiographic/reference/build_var.md)
  or `"graphical_var"` for
  [`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md).

- id:

  Character. Name of the person-ID column, or `NULL`.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- initial:

  Integer number of ordered blocks in the first training split.

- assess:

  Integer number of blocks to assess per split.

- step:

  Integer number of blocks to advance between splits.

- n_splits:

  Optional maximum number of rolling splits.

- block_size:

  Integer or `NULL`. Consecutive block length used only when neither
  `id` nor `day` is supplied.

- scale:

  Logical. Whether to standardize using training-split means and SDs.

- center_within:

  Logical. Whether to center within person using training-split person
  means when more than one id is present.

- delete_missings:

  Logical. Drop incomplete current/lagged assessment rows.

- keep_fits:

  Logical. Store fitted split models?

- ...:

  Further arguments passed to the estimator.

## Value

A `forecast_result` with `$predictions`, `$metrics`, `$splits`,
`$failures`, and optionally `$fits`.

## See also

[`build_var()`](https://mohsaqr.github.io/idiographic/reference/build_var.md),
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md),
[`estimate_stability()`](https://mohsaqr.github.io/idiographic/reference/estimate_stability.md)

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = rep(1:5, each = 12),
                beep = rep(1:12, 5),
                A = rnorm(60), B = rnorm(60), C = rnorm(60))
fc <- validate_forecast(d, vars = c("A", "B", "C"), id = "id",
                        day = "day", beep = "beep",
                        initial = 3, n_splits = 2, scale = FALSE)
fc$metrics
#>   variable  n       mae      rmse       bias
#> 1        A 22 0.6627637 0.7916495  0.2286442
#> 2        B 22 0.7710222 0.8981746 -0.1662394
#> 3        C 22 1.0826584 1.3570916  0.8713974
#> 4 .overall 66 0.8388148 1.0448483  0.3112674
```
