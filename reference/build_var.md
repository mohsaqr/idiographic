# Build an ordinary least-squares VAR network

Fits a transparent VAR(1) baseline from intensive longitudinal data
using ordinary least squares. The lag construction, scaling,
within-person centering, and day-boundary behavior match
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md),
but no regularization or EBIC model selection is applied.

## Usage

``` r
build_var(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  lags = 1L,
  scale = TRUE,
  center_within = TRUE,
  delete_missings = TRUE,
  min_obs = NULL,
  subject = NULL
)
```

## Arguments

- data:

  A `data.frame` or matrix with columns for variables and optional
  id/day/beep columns.

- vars:

  Character vector of variable names.

- id:

  Character. Name of the person-ID column, or `NULL`.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- lags:

  Integer. Only `1` is supported.

- scale:

  Logical. Whether to standardize variables before lagging.

- center_within:

  Logical. Whether to center within person when more than one id is
  present.

- delete_missings:

  Logical. Drop incomplete current/lagged rows.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the subject(s) to analyse.

## Value

A `var_result` object with temporal OLS coefficients, residual
covariance, residual precision, contemporaneous partial correlations,
and tidy accessors.

## See also

[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md),
[`build_usem()`](https://mohsaqr.github.io/idiographic/reference/build_usem.md)
